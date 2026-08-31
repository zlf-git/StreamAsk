-- ============================================================
-- StarRocks 初始化脚本
-- 双路径：
--   A) 外部 Catalog paimon_catalog1 -> 直查 Flink 写出的 Paimon 湖仓（生产一致）
--   B) 本地 mall_dw -> 把 ADS 表物化到 StarRocks 内部，作为 serving 快照 + 物化视图示例
-- 两者表结构一致，dt 统一为 STRING 类型 yyyyMMdd（与项目 Dify prompt 一致）
-- ============================================================

-- --------------------------------------------------
-- A. 外部 Catalog 对接 Paimon（直查湖仓）
--    allin1 3.2.11 已内置 paimon 读取库，无需额外插件
--    paimon_warehouse 是 docker 共享卷，挂载在容器 /paimon_warehouse
-- --------------------------------------------------
CREATE EXTERNAL CATALOG paimon_catalog1
PROPERTIES (
    "type" = "paimon",
    "paimon.catalog.type" = "filesystem",
    "paimon.catalog.warehouse" = "/paimon_warehouse"
);

-- --------------------------------------------------
-- B. 本地 mall_dw（重新初始化，dt 改为 STRING yyyyMMdd）
-- --------------------------------------------------
DROP DATABASE IF EXISTS mall_dw;
CREATE DATABASE mall_dw;
USE mall_dw;

-- 经营总览（日增量）
CREATE TABLE IF NOT EXISTS ads_trade_overview_di (
    dt STRING,
    total_order_cnt BIGINT,
    paid_order_cnt BIGINT,
    total_gmv DECIMAL(16,2),
    paid_user_cnt BIGINT
) DUPLICATE KEY(dt)
DISTRIBUTED BY HASH(dt) BUCKETS 1
PROPERTIES ("replication_num" = "1");

-- 渠道转化（日增量）
CREATE TABLE IF NOT EXISTS ads_channel_conversion_di (
    dt STRING,
    channel VARCHAR(64),
    visit_uv BIGINT,
    order_cnt BIGINT,
    paid_order_cnt BIGINT,
    gmv DECIMAL(16,2),
    order_conversion_rate DECIMAL(16,4),
    pay_conversion_rate DECIMAL(16,4)
) DUPLICATE KEY(dt, channel)
DISTRIBUTED BY HASH(dt) BUCKETS 1
PROPERTIES ("replication_num" = "1");

-- 地区 GMV（日增量）
CREATE TABLE IF NOT EXISTS ads_region_gmv_di (
    dt STRING,
    province VARCHAR(64),
    order_cnt BIGINT,
    paid_order_cnt BIGINT,
    paid_user_cnt BIGINT,
    gmv DECIMAL(16,2)
) DUPLICATE KEY(dt, province)
DISTRIBUTED BY HASH(dt) BUCKETS 1
PROPERTIES ("replication_num" = "1");

-- 商品排行（日增量）
CREATE TABLE IF NOT EXISTS ads_product_sales_rank_di (
    dt STRING,
    product_id BIGINT,
    product_name VARCHAR(256),
    category_name VARCHAR(128),
    sale_cnt BIGINT,
    sale_amount DECIMAL(16,2)
) DUPLICATE KEY(dt, product_id)
DISTRIBUTED BY HASH(dt) BUCKETS 1
PROPERTIES ("replication_num" = "1");

-- 用户增长（日增量）
CREATE TABLE IF NOT EXISTS ads_user_growth_di (
    dt STRING,
    register_channel VARCHAR(64),
    new_user_cnt BIGINT
) DUPLICATE KEY(dt, register_channel)
DISTRIBUTED BY HASH(dt) BUCKETS 1
PROPERTIES ("replication_num" = "1");

-- --------------------------------------------------
-- 物化视图示例（StarRocks 3.2+ 支持）
-- 场景：业务频繁查询"最近 7 天整体 GMV 趋势"，物化视图预聚合加速
-- --------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_trade_overview_7d
AS
SELECT
    dt,
    SUM(total_gmv) AS sum_gmv,
    SUM(total_order_cnt) AS sum_order_cnt,
    SUM(paid_order_cnt) AS sum_paid_order_cnt
FROM mall_dw.ads_trade_overview_di
GROUP BY dt;

-- --------------------------------------------------
-- 本地验证版测试数据（dt 用 yyyyMMdd 字符串）
-- 真实场景由 Flink ETL 写入 Paimon，StarRocks 通过 paimon_catalog1 直查
-- --------------------------------------------------
INSERT INTO mall_dw.ads_trade_overview_di
VALUES
    ('20260714', 1200, 980, 125000.00, 850),
    ('20260715', 1350, 1100, 138000.00, 920),
    ('20260716', 1100, 900, 112000.00, 780),
    ('20260717', 1500, 1250, 165000.00,1050),
    ('20260718', 1600, 1320, 172000.00,1100),
    ('20260719', 1450, 1200, 148000.00, 980),
    ('20260720', 1700, 1450, 185000.00,1250);

INSERT INTO mall_dw.ads_channel_conversion_di
VALUES
    ('20260720', 'app', 5000, 600, 480, 62000.00, 0.1200, 0.0960),
    ('20260720', 'web', 3000, 280, 220, 28000.00, 0.0933, 0.0733),
    ('20260720', 'miniapp', 2000, 220, 180, 22000.00, 0.1100, 0.0900);
