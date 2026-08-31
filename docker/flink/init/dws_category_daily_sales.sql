-- ============================================================
-- DWS 层：公司类目日销售汇总表
-- 目标：按公司类目 + 日期聚合销售指标
-- 主键：company_category_id + stat_date
-- ============================================================

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
-- streaming 模式持续聚合，避免 batch 模式下 Adaptive Parallelism 与 Paimon sink 的兼容问题

USE CATALOG paimon_catalog1;
USE mall_dw;

CREATE TABLE IF NOT EXISTS dws_category_daily_sales (
    company_category_id    STRING,
    company_category_path  STRING,
    stat_date              STRING,
    order_cnt              BIGINT,
    quantity               BIGINT,
    gmv                    DECIMAL(16,2),
    discount_amt           DECIMAL(16,2),
    buyer_uv               BIGINT,
    PRIMARY KEY (company_category_id, stat_date) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2',
    'sink.parallelism' = '1'
);

INSERT INTO dws_category_daily_sales
SELECT
    company_category_id,
    MAX(company_category_path)                            AS company_category_path,
    DATE_FORMAT(create_time, 'yyyy-MM-dd')                AS stat_date,
    COUNT(DISTINCT order_id)                              AS order_cnt,
    SUM(quantity)                                         AS quantity,
    SUM(item_pay_amount)                                  AS gmv,
    SUM(discount_amount)                                  AS discount_amt,
    COUNT(DISTINCT buyer_uid)                             AS buyer_uv
FROM dwd_douyin_order_detail
WHERE pay_status = '已支付'
GROUP BY company_category_id, DATE_FORMAT(create_time, 'yyyy-MM-dd');
