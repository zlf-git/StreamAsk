-- ============================================================
-- DWS 层：店铺日 GMV 汇总表
-- 目标：按店铺 + 日期聚合订单级指标，供 ADS 实时大屏/BI 使用
-- 主键：shop_id + stat_date
-- ============================================================

-- 0. 开启 checkpoint（实时流式写入依赖 checkpoint 触发 Paimon snapshot）
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
-- 使用 streaming 模式跑 DWS 持续聚合，避免 Flink 1.17 batch 模式下
-- GROUP BY 触发的 Adaptive Parallelism 与 Paimon 0.8.1 sink 的兼容问题。
-- 如需一次性补历史数据，可把 dwd_douyin_order 的 scan.mode 设为 latest-full 后改为 batch 模式。

-- 1. 使用已有的 Paimon catalog
USE CATALOG paimon_catalog1;
USE mall_dw;

-- 2. 创建 DWS 店铺日 GMV 表
CREATE TABLE IF NOT EXISTS dws_shop_daily_gmv (
    shop_id             STRING,
    shop_name           STRING,
    stat_date           STRING,
    order_cnt           BIGINT,
    buyer_uv            BIGINT,
    gmv                 DECIMAL(16,2),
    discount_amt        DECIMAL(16,2),
    freight_amt         DECIMAL(16,2),
    net_pay_amt         DECIMAL(16,2),
    avg_order_amount    DECIMAL(16,2),
    total_quantity      BIGINT,
    PRIMARY KEY (shop_id, stat_date) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2'
);

-- 3. 从 DWD 订单表汇总写入 DWS
INSERT INTO dws_shop_daily_gmv
SELECT
    shop_id,
    MAX(shop_name)                                                   AS shop_name,
    order_date                                                       AS stat_date,
    COUNT(DISTINCT order_id)                                         AS order_cnt,
    COUNT(DISTINCT buyer_uid)                                        AS buyer_uv,
    SUM(total_pay_amount)                                            AS gmv,
    SUM(total_discount_amount)                                       AS discount_amt,
    SUM(freight_amount)                                              AS freight_amt,
    SUM(total_pay_amount - freight_amount)                           AS net_pay_amt,
    SUM(total_pay_amount) / COUNT(DISTINCT order_id)                 AS avg_order_amount,
    SUM(total_quantity)                                              AS total_quantity
FROM dwd_douyin_order
WHERE pay_status = '已支付'
GROUP BY shop_id, order_date;
