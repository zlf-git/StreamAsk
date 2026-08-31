-- ============================================================
-- ADS 层：每日店铺销售排名
-- 目标：按日期输出 GMV TOP N 店铺
-- 主键：stat_date + rank_no
-- ============================================================

SET 'execution.runtime-mode' = 'batch';
SET 'parallelism.default' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'table.optimizer.adaptive-parallelism.enabled' = 'false';
SET 'execution.batch.adaptive.parallelism.enabled' = 'false';
-- batch 模式读取 DWS 全量快照，避免 upsert changelog 与 OVER 聚合不兼容

USE CATALOG paimon_catalog1;
USE mall_dw;

CREATE TABLE IF NOT EXISTS ads_shop_rank_daily (
    stat_date            STRING,
    rank_no              INT,
    shop_id              STRING,
    shop_name            STRING,
    gmv                  DECIMAL(16,2),
    order_cnt            BIGINT,
    buyer_uv             BIGINT,
    avg_order_amount     DECIMAL(16,2),
    PRIMARY KEY (stat_date, rank_no) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2',
    'sink.parallelism' = '1'
);

INSERT INTO ads_shop_rank_daily
SELECT
    stat_date,
    CAST(ROW_NUMBER() OVER (PARTITION BY stat_date ORDER BY gmv DESC) AS INT) AS rank_no,
    shop_id,
    shop_name,
    gmv,
    order_cnt,
    buyer_uv,
    avg_order_amount
FROM dws_shop_daily_gmv;
