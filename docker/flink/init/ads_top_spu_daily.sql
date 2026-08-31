-- ============================================================
-- ADS 层：每日 TOP SPU 销售榜
-- 目标：按日期输出销量 TOP N 的 SPU，供运营/推荐使用
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

CREATE TABLE IF NOT EXISTS ads_top_spu_daily (
    stat_date            STRING,
    rank_no              INT,
    spu_id               STRING,
    spu_name             STRING,
    brand                STRING,
    quantity             BIGINT,
    gmv                  DECIMAL(16,2),
    order_cnt            BIGINT,
    buyer_uv             BIGINT,
    PRIMARY KEY (stat_date, rank_no) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '2',
    'sink.parallelism' = '1'
);

INSERT INTO ads_top_spu_daily
SELECT
    stat_date,
    CAST(ROW_NUMBER() OVER (PARTITION BY stat_date ORDER BY gmv DESC) AS INT) AS rank_no,
    spu_id,
    spu_name,
    brand,
    quantity,
    gmv,
    order_cnt,
    buyer_uv
FROM dws_spu_daily_sales;
