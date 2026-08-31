-- ============================================================
-- Flink CDC：MySQL orders 表 → Kafka topic: ods_douyin_order_cdc
-- 作用：在数仓链路前增加真实 CDC 数据源入口
--       演示 MySQL binlog 如何被 Flink 捕获并写入 Kafka
--
-- 前置条件：
--   1. mysql-ai-analysis 容器已启动并开启 binlog
--   2. cdc_source.orders 表已存在且有初始数据
--   3. /opt/flink/lib 下已有 flink-sql-connector-mysql-cdc-2.4.2.jar
--   4. Kafka topic: ods_douyin_order_cdc 已存在（不存在会自动创建）
-- ============================================================

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

-- 1. MySQL CDC 源表
-- 注意：mysql-cdc connector 会读取 binlog，同时做一次初始快照（scan.startup.mode 默认 initial）
CREATE TABLE IF NOT EXISTS orders_cdc_source (
    id              BIGINT,
    order_id        STRING,
    platform_code   STRING,
    shop_id         STRING,
    buyer_uid       STRING,
    total_amount    DECIMAL(16,2),
    pay_status      STRING,
    create_time     TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'mysql-ai-analysis',
    'port' = '3306',
    'username' = 'root',
    'password' = '123456',
    'database-name' = 'cdc_source',
    'table-name' = 'orders',
    'server-id' = '5400-5404',
    -- 默认 scan.startup.mode = 'initial'，先读全表快照，再增量读 binlog
    'scan.startup.mode' = 'initial',
    -- 显式要求 Debezium 做初始快照（否则可能因状态恢复跳过）
    'debezium.snapshot.mode' = 'initial'
);

-- 2. Kafka Sink，输出 Debezium JSON 格式
-- 下游可以解析 op 字段：c=insert, u=update, d=delete
CREATE TABLE IF NOT EXISTS kafka_cdc_sink (
    id              BIGINT,
    order_id        STRING,
    platform_code   STRING,
    shop_id         STRING,
    buyer_uid       STRING,
    total_amount    DECIMAL(16,2),
    pay_status      STRING,
    create_time     TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_douyin_order_cdc',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:19092',
    'properties.group.id' = 'flink_cdc_mysql_to_kafka',
    'format' = 'debezium-json',
    'debezium-json.ignore-parse-errors' = 'true',
    'sink.partitioner' = 'fixed'
);

-- 3. 启动 CDC 同步
INSERT INTO kafka_cdc_sink
SELECT id, order_id, platform_code, shop_id, buyer_uid, total_amount, pay_status, create_time
FROM orders_cdc_source;
