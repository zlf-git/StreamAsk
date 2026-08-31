-- ============================================================
-- DWS 层：用户日活/购买行为汇总表
-- 目标：按日期聚合用户购买行为（UV、人均单数、人均金额）
-- 主键：stat_date
-- ============================================================

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
-- streaming 模式持续聚合，避免 batch 模式下 Adaptive Parallelism 与 Paimon sink 的兼容问题

USE CATALOG paimon_catalog1;
USE mall_dw;

CREATE TABLE IF NOT EXISTS dws_user_daily_activity (
    stat_date            STRING,
    buyer_uv             BIGINT,
    new_buyer_uv         BIGINT,
    order_cnt            BIGINT,
    gmv                  DECIMAL(16,2),
    avg_orders_per_user  DECIMAL(10,2),
    avg_gmv_per_user     DECIMAL(16,2),
    PRIMARY KEY (stat_date) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    'bucket' = '1',
    'sink.parallelism' = '1'
);

INSERT INTO dws_user_daily_activity
SELECT
    order_date                                           AS stat_date,
    COUNT(DISTINCT buyer_uid)                            AS buyer_uv,
    COUNT(DISTINCT buyer_uid)                            AS new_buyer_uv,  -- 当前 demo 无历史用户态，暂用 buyer_uv 占位
    COUNT(DISTINCT order_id)                             AS order_cnt,
    SUM(total_pay_amount)                                AS gmv,
    CAST(COUNT(DISTINCT order_id) AS DECIMAL(10,2))
        / CAST(COUNT(DISTINCT buyer_uid) AS DECIMAL(10,2)) AS avg_orders_per_user,
    SUM(total_pay_amount)
        / CAST(COUNT(DISTINCT buyer_uid) AS DECIMAL(16,2)) AS avg_gmv_per_user
FROM dwd_douyin_order
WHERE pay_status = '已支付'
GROUP BY order_date;
