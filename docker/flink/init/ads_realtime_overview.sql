-- ============================================================
-- ADS 层：实时交易总览大屏指标
-- 目标：提供单日期维度的核心交易指标，直接供大屏/BI 展示
-- 主键：stat_date
-- ============================================================

SET 'execution.runtime-mode' = 'batch';
SET 'parallelism.default' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'table.optimizer.adaptive-parallelism.enabled' = 'false';
SET 'execution.batch.adaptive.parallelism.enabled' = 'false';
-- batch 模式读取 DWS 全量快照，避免 streaming 资源长期占用

USE CATALOG paimon_catalog1;
USE mall_dw;

CREATE TABLE IF NOT EXISTS ads_realtime_overview (
    stat_date            STRING,
    gmv                  DECIMAL(16,2),
    order_cnt            BIGINT,
    buyer_uv             BIGINT,
    paid_order_cnt       BIGINT,
    paid_gmv             DECIMAL(16,2),
    paid_buyer_uv        BIGINT,
    discount_amt         DECIMAL(16,2),
    freight_amt          DECIMAL(16,2),
    avg_order_amount     DECIMAL(16,2),
    PRIMARY KEY (stat_date) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '1',
    'sink.parallelism' = '1'
);

INSERT INTO ads_realtime_overview
SELECT
    stat_date,
    SUM(gmv)                                          AS gmv,
    SUM(order_cnt)                                    AS order_cnt,
    SUM(buyer_uv)                                     AS buyer_uv,
    SUM(order_cnt)                                    AS paid_order_cnt,  -- DWS 已过滤 PAID
    SUM(gmv)                                          AS paid_gmv,
    SUM(buyer_uv)                                     AS paid_buyer_uv,
    SUM(discount_amt)                                 AS discount_amt,
    SUM(freight_amt)                                  AS freight_amt,
    SUM(gmv) / NULLIF(SUM(order_cnt), 0)              AS avg_order_amount
FROM dws_shop_daily_gmv
GROUP BY stat_date;
