-- ============================================================
-- ODS 层：抖音订单（教学示例）
-- 目标：把 Kafka 里的一条条 JSON 订单写入 Paimon ODS 表
-- 数据：一条消息 = 一条订单（含 items 数组）
-- 运行方式：
--   docker exec -i flink-jobmanager ./bin/sql-client.sh -f /flink-init/ods_douyin_order_example.sql
-- 注意：
--   1. 先启动 Kafka 并把 Producer 跑完，确保 topic 里有数据
--   2. Flink 容器内访问 Kafka 用内部 listener 端口：kafka-ai-analysis:19092
--   3. Paimon warehouse 已统一为 OSS：s3://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse
--   4. Kafka source 表必须放在 default_catalog 下或声明为 TEMPORARY，
--      因为 Paimon catalog 只支持 Paimon 表。
--   5. Paimon sink 依赖 Flink checkpoint 触发写入，必须设置 checkpoint 间隔。
-- ============================================================

-- 0. 开启 checkpoint：Paimon 表的数据写入由 checkpoint 触发提交
--    生产环境一般设 1min~10min；本地测试设 10s 可以快速看到数据。
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

-- 1. 创建/重建 Paimon Catalog
-- 作用：告诉 Flink 数仓存在哪里。
-- warehouse 已统一为 OSS，与 StarRocks 的 paimon_oss_catalog 完全对齐。
-- 这里用 DROP CATALOG IF EXISTS + CREATE，使本文件也能独立用 -f 执行。
DROP CATALOG IF EXISTS paimon_catalog1;
CREATE CATALOG paimon_catalog1 WITH (
    'type' = 'paimon',
    'warehouse' = 's3://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
    's3.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
    's3.access-key' = '<YOUR_OSS_ACCESS_KEY>',
    's3.secret-key' = '<YOUR_OSS_SECRET_KEY>'
);

-- 2. 切换到 Paimon catalog，创建/使用数据库 mall_dw，并创建 ODS sink 表
USE CATALOG paimon_catalog1;
CREATE DATABASE IF NOT EXISTS mall_dw;
USE mall_dw;

-- Paimon Sink 表：ODS 层贴源存储
-- 主键用 order_id：同一订单多次更新会被后面的状态覆盖（Upsert）。
-- 因为当前数据 order_id 唯一，所以用单字段主键即可。
CREATE TABLE IF NOT EXISTS ods_douyin_order (
    order_id                STRING,
    platform_code           STRING,
    platform_name           STRING,
    shop_id                 STRING,
    shop_name               STRING,
    buyer_uid               STRING,
    buyer_nick              STRING,
    receiver_name           STRING,
    receiver_phone          STRING,
    receiver_province         STRING,
    receiver_city             STRING,
    receiver_district         STRING,
    receiver_address        STRING,
    total_amount            DECIMAL(16,2),
    total_discount_amount   DECIMAL(16,2),
    total_pay_amount        DECIMAL(16,2),
    total_quantity          INT,
    freight_amount          DECIMAL(16,2),
    order_status            STRING,
    pay_status              STRING,
    pay_time                TIMESTAMP(3),
    create_time             TIMESTAMP(3),
    items                   ARRAY< ROW< order_item_id       STRING,
                                       outer_id            STRING,
                                       platform_sku_id     STRING,
                                       sku_name            STRING,
                                       spu_id              STRING,
                                       spu_name            STRING,
                                       brand               STRING,
                                       quantity            INT,
                                       unit                STRING,
                                       unit_price          DECIMAL(16,2),
                                       item_amount         DECIMAL(16,2),
                                       discount_amount     DECIMAL(16,2),
                                       pay_amount          DECIMAL(16,2),
                                       platform_category_id     STRING,
                                       platform_category_path   STRING,
                                       platform_category_level  INT,
                                       company_category_id      STRING,
                                       company_category_path    STRING > >,
    proc_time               TIMESTAMP(3) NOT NULL,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    -- bucket 默认 1，适合小数据量；数据量大后按 buyer_uid 或 order_id 分桶
    'bucket' = '1'
);

-- 3. 切换到默认 catalog，创建 Kafka Source 临时表
-- Paimon catalog 不支持非 Paimon 表，所以 Kafka source 必须放在 default_catalog 下。
-- TEMPORARY 表只在当前 sql-client session 有效，因此本文件里创建和 INSERT 要一起执行。
USE CATALOG default_catalog;

CREATE TEMPORARY TABLE IF NOT EXISTS kafka_douyin_order_source (
    order_id                STRING,
    platform_code           STRING,
    platform_name           STRING,
    shop_id                 STRING,
    shop_name               STRING,
    buyer_uid               STRING,
    buyer_nick              STRING,
    receiver_name           STRING,
    receiver_phone          STRING,
    receiver_province         STRING,
    receiver_city             STRING,
    receiver_district         STRING,
    receiver_address        STRING,
    total_amount            DECIMAL(16,2),
    total_discount_amount   DECIMAL(16,2),
    total_pay_amount        DECIMAL(16,2),
    total_quantity          INT,
    freight_amount          DECIMAL(16,2),
    order_status            STRING,
    pay_status              STRING,
    pay_time                TIMESTAMP(3),
    create_time             TIMESTAMP(3),
    -- 订单明细数组：数组里每个元素是一个结构体（ROW）
    items                   ARRAY< ROW< order_item_id       STRING,
                                       outer_id            STRING,
                                       platform_sku_id     STRING,
                                       sku_name            STRING,
                                       spu_id              STRING,
                                       spu_name            STRING,
                                       brand               STRING,
                                       quantity            INT,
                                       unit                STRING,
                                       unit_price          DECIMAL(16,2),
                                       item_amount         DECIMAL(16,2),
                                       discount_amount     DECIMAL(16,2),
                                       pay_amount          DECIMAL(16,2),
                                       platform_category_id     STRING,
                                       platform_category_path   STRING,
                                       platform_category_level  INT,
                                       company_category_id      STRING,
                                       company_category_path    STRING > >,
    -- 处理时间：Flink 自动生成本条数据进入 Flink 的时间
    proc_time AS PROCTIME(),
    -- 水位线：允许业务时间最多乱序 5 秒
    WATERMARK FOR pay_time AS pay_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_douyin_order',
    -- Flink 在 Docker 内部访问 Kafka 内部 listener 端口 19092，不是宿主机端口 9092
    'properties.bootstrap.servers' = 'kafka-ai-analysis:19092',
    'properties.group.id' = 'flink_ods_douyin_order_fix',
    'format' = 'json',
    -- 首次启动从最早 offset 读，适合一次性灌 Mock 数据
    'scan.startup.mode' = 'earliest-offset',
    -- 如果 JSON 字段缺失不报错，设为空
    'json.fail-on-missing-field' = 'false',
    -- 解析失败的行跳过，避免一条脏数据卡住整个作业
    'json.ignore-parse-errors' = 'true',
    -- Mock 数据中的 pay_time/create_time 为 ISO-8601 格式（如 2026-07-22T16:29:07），必须显式声明
    'json.timestamp-format.standard' = 'ISO-8601'
);

-- 4. 回到 Paimon catalog，执行入湖：把 Kafka 数据写入 Paimon ODS 表
USE CATALOG paimon_catalog1;
USE mall_dw;

INSERT INTO ods_douyin_order
SELECT
    order_id, platform_code, platform_name, shop_id, shop_name,
    buyer_uid, buyer_nick, receiver_name, receiver_phone,
    receiver_province, receiver_city, receiver_district, receiver_address,
    total_amount, total_discount_amount, total_pay_amount, total_quantity,
    freight_amount, order_status, pay_status, pay_time, create_time,
    items, proc_time
FROM default_catalog.default_database.kafka_douyin_order_source;
