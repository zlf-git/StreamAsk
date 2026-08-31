-- ============================================================
-- DWD 层：抖音订单表（订单粒度）
-- 目标：对 ODS 订单表按 order_id 去重，清洗脏数据，补充标准化字段
-- 主键：order_id
-- ============================================================

-- 0. 开启 checkpoint + 批模式初始化
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.runtime-mode' = 'batch';
-- Paimon sink 不支持 Flink 自适应并行度，显式关闭
SET 'pipeline.adaptive-parallelism.enabled' = 'false';

-- 1. 使用已有的 Paimon catalog
USE CATALOG paimon_catalog1;
USE mall_dw;

-- 2. 创建 DWD 订单 sink 表
CREATE TABLE IF NOT EXISTS dwd_douyin_order (
    order_id                STRING,
    platform_code           STRING,
    platform_name           STRING,
    shop_id                 STRING,
    shop_name               STRING,
    buyer_uid               STRING,
    buyer_nick              STRING,
    receiver_name           STRING,
    receiver_phone          STRING,
    receiver_province       STRING,
    receiver_city           STRING,
    receiver_district       STRING,
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

    -- 标准化衍生字段
    order_date              STRING,   -- 订单日期：yyyy-MM-dd

    proc_time               TIMESTAMP(3),

    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2',
    'sink.parallelism' = '1'
);

-- 3. 从 ODS 订单表写入 DWD 订单表
-- 核心逻辑：
--   1. 过滤 order_id / total_pay_amount 为空的脏数据
--   2. 按 order_id 分区，proc_time 降序，取第一条做去重
--   3. 生成 order_date 标准化日期字段
INSERT INTO dwd_douyin_order
SELECT
    order_id,
    platform_code,
    platform_name,
    shop_id,
    shop_name,
    buyer_uid,
    buyer_nick,
    receiver_name,
    receiver_phone,
    receiver_province,
    receiver_city,
    receiver_district,
    receiver_address,
    total_amount,
    total_discount_amount,
    total_pay_amount,
    total_quantity,
    freight_amount,
    order_status,
    pay_status,
    pay_time,
    create_time,
    DATE_FORMAT(create_time, 'yyyy-MM-dd') AS order_date,
    proc_time
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY proc_time DESC) AS rn
    FROM ods_douyin_order
    WHERE order_id IS NOT NULL
      AND total_pay_amount IS NOT NULL
) t
WHERE rn = 1;
