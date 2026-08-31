-- ============================================================
-- ODS 表：从 Kafka CDC topic 读取 Debezium JSON，写入 Paimon
-- 链路：MySQL → Flink CDC → Kafka → Flink SQL → Paimon ODS
--
-- 前置条件：
--   1. cdc_mysql_to_kafka 任务已启动，topic ods_douyin_order_cdc 有数据
--   2. paimon_catalog1 已通过 -i /flink-init/catalogs.sql 创建
-- ============================================================

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'sql-session.adaptive-parallelism.enabled' = 'false';
-- Paimon sink 不支持 Flink 默认的 upsert materializer，必须关闭
SET 'table.exec.sink.upsert-materialize' = 'NONE';

USE CATALOG paimon_catalog1;
CREATE DATABASE IF NOT EXISTS mall_dw;
USE mall_dw;

-- 1. Paimon ODS 表，按主键 upsert
CREATE TABLE IF NOT EXISTS ods_douyin_order_cdc (
    id              BIGINT,
    order_id        STRING,
    platform_code   STRING,
    shop_id         STRING,
    buyer_uid       STRING,
    total_amount    DECIMAL(16,2),
    pay_status      STRING,
    create_time     TIMESTAMP(3),
    proc_time       TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2'
);

USE CATALOG default_catalog;

-- 2. Kafka CDC source（Debezium JSON 格式）
-- 默认会解析 op 字段：c/u/d，产生 changelog 流
CREATE TEMPORARY TABLE kafka_cdc_source (
    id              BIGINT,
    order_id        STRING,
    platform_code   STRING,
    shop_id         STRING,
    buyer_uid       STRING,
    total_amount    DECIMAL(16,2),
    pay_status      STRING,
    create_time     TIMESTAMP(3),
    proc_time AS PROCTIME(),
    WATERMARK FOR create_time AS create_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_douyin_order_cdc',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:19092',
    'properties.group.id' = 'flink_ods_douyin_order_cdc',
    'format' = 'debezium-json',
    'scan.startup.mode' = 'earliest-offset',
    'debezium-json.ignore-parse-errors' = 'true',
    -- MySQL DATETIME 经 Flink CDC 序列化后为 'yyyy-MM-dd HH:mm:ss'，需用 SQL 标准解析
    'debezium-json.timestamp-format.standard' = 'SQL'
);

USE CATALOG paimon_catalog1;
USE mall_dw;

-- 3. 写入 Paimon ODS
INSERT INTO ods_douyin_order_cdc
SELECT id, order_id, platform_code, shop_id, buyer_uid, total_amount, pay_status, create_time, proc_time
FROM default_catalog.default_database.kafka_cdc_source;
