-- ============================================================
-- Flink + Paimon 湖仓一体 ETL 演示（ODS -> DWD -> DWS -> ADS）
-- 运行方式（容器启动后）：
--   docker exec -i flink-jobmanager ./bin/sql-client.sh -f /flink-init/paimon_demo.sql
-- 说明：
--   * warehouse 用本地文件系统 file:///paimon_warehouse（生产用 oss:///mall-dw/）
--   * 该路径是 docker 共享卷，StarRocks 容器也挂载在同一路径，可直查
--   * dt 统一为 STRING 类型，格式 yyyyMMdd（与项目 Dify prompt 一致）
-- ============================================================

SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';

-- 1) 创建 Paimon Catalog（本地文件系统版）
CREATE CATALOG paimon_catalog1 WITH (
    'type' = 'paimon',
    'warehouse' = 'file:///paimon_warehouse'
);

USE CATALOG paimon_catalog1;
CREATE DATABASE IF NOT EXISTS mall_dw;
USE mall_dw;

-- 2) ODS 层（贴源，主键表，支持 CDC Upsert）
CREATE TABLE IF NOT EXISTS ods_user_info (
    user_id        STRING,
    user_name      STRING,
    register_channel STRING,
    register_date  STRING,
    PRIMARY KEY (user_id) NOT ENFORCED
) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ods_product_info (
    product_id     STRING,
    product_name   STRING,
    category_name  STRING,
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ods_order_info (
    order_id       STRING,
    user_id        STRING,
    product_id     STRING,
    order_amount   DECIMAL(16,2),
    order_status   STRING,
    province       STRING,
    channel        STRING,
    create_time    TIMESTAMP(3),
    dt             STRING,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH ('bucket' = '1');

-- 3) DWD 层（清洗 / 标准化 / 维度关联）
CREATE TABLE IF NOT EXISTS dwd_user_info (
    user_id        STRING,
    user_name      STRING,
    register_channel STRING,
    register_date  STRING,
    PRIMARY KEY (user_id) NOT ENFORCED
) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS dwd_product_info (
    product_id     STRING,
    product_name   STRING,
    category_name  STRING,
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS dwd_order_info (
    order_id       STRING,
    user_id        STRING,
    product_id     STRING,
    order_amount   DECIMAL(16,2),
    order_status   STRING,
    is_refunded    INT,
    province       STRING,
    channel        STRING,
    create_time    TIMESTAMP(3),
    dt             STRING,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH ('bucket' = '1');

-- 4) DWS 层（按主题汇总，追加表，按 dt 分区）
CREATE TABLE IF NOT EXISTS dws_channel_order_day (
    dt             STRING,
    channel        STRING,
    uv             BIGINT,
    order_cnt      BIGINT,
    paid_order_cnt BIGINT,
    gmv            DECIMAL(16,2),
    refund_cnt     BIGINT,
    PRIMARY KEY (dt, channel) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS dws_province_order_day (
    dt             STRING,
    province       STRING,
    order_cnt      BIGINT,
    paid_order_cnt BIGINT,
    paid_user_cnt  BIGINT,
    gmv            DECIMAL(16,2),
    PRIMARY KEY (dt, province) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS dws_product_sales_day (
    dt             STRING,
    product_id     STRING,
    product_name   STRING,
    category_name  STRING,
    sale_cnt       BIGINT,
    sale_amount    DECIMAL(16,2),
    PRIMARY KEY (dt, product_id) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS dws_user_growth_day (
    dt             STRING,
    register_channel STRING,
    new_user_cnt   BIGINT,
    PRIMARY KEY (dt, register_channel) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

-- 5) ADS 层（应用数据层，5 张日增量表，与项目完全一致）
CREATE TABLE IF NOT EXISTS ads_trade_overview_di (
    dt             STRING,
    total_order_cnt BIGINT,
    paid_order_cnt  BIGINT,
    total_gmv      DECIMAL(16,2),
    paid_user_cnt  BIGINT,
    PRIMARY KEY (dt) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ads_channel_conversion_di (
    dt             STRING,
    channel        STRING,
    visit_uv       BIGINT,
    order_cnt      BIGINT,
    paid_order_cnt BIGINT,
    gmv            DECIMAL(16,2),
    order_conversion_rate DECIMAL(16,4),
    pay_conversion_rate   DECIMAL(16,4),
    PRIMARY KEY (dt, channel) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ads_region_gmv_di (
    dt             STRING,
    province       STRING,
    order_cnt      BIGINT,
    paid_order_cnt BIGINT,
    paid_user_cnt  BIGINT,
    gmv            DECIMAL(16,2),
    PRIMARY KEY (dt, province) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ads_product_sales_rank_di (
    dt             STRING,
    product_id     BIGINT,
    product_name   STRING,
    category_name  STRING,
    sale_cnt       BIGINT,
    sale_amount    DECIMAL(16,2),
    PRIMARY KEY (dt, product_id) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

CREATE TABLE IF NOT EXISTS ads_user_growth_di (
    dt             STRING,
    register_channel STRING,
    new_user_cnt   BIGINT,
    PRIMARY KEY (dt, register_channel) NOT ENFORCED
) PARTITIONED BY (dt) WITH ('bucket' = '1');

-- 6) 写入测试数据（两天：20260720 / 20260721）
INSERT INTO ods_user_info VALUES
    ('u1','张三','app','20260720'),
    ('u2','李四','web','20260720'),
    ('u3','王五','miniapp','20260720'),
    ('u4','赵六','app','20260721'),
    ('u5','钱七','web','20260721');

INSERT INTO ods_product_info VALUES
    ('p1','机械键盘','电脑外设'),
    ('p2','4K显示器','电脑外设'),
    ('p3','人体工学椅','办公家具');

INSERT INTO ods_order_info VALUES
    ('o1','u1','p1',500.00,'paid','广东','app',TIMESTAMP '2026-07-20 10:00:00','20260720'),
    ('o2','u2','p2',1500.00,'paid','北京','web',TIMESTAMP '2026-07-20 11:00:00','20260720'),
    ('o3','u3','p3',800.00,'paid','上海','miniapp',TIMESTAMP '2026-07-20 12:00:00','20260720'),
    ('o4','u1','p2',1500.00,'refunded','广东','app',TIMESTAMP '2026-07-20 13:00:00','20260720'),
    ('o5','u4','p1',500.00,'paid','广东','app',TIMESTAMP '2026-07-20 14:00:00','20260720'),
    ('o6','u2','p3',800.00,'paid','北京','web',TIMESTAMP '2026-07-21 10:00:00','20260721'),
    ('o7','u5','p1',500.00,'paid','上海','web',TIMESTAMP '2026-07-21 11:00:00','20260721'),
    ('o8','u3','p2',1500.00,'paid','上海','miniapp',TIMESTAMP '2026-07-21 12:00:00','20260721'),
    ('o9','u4','p3',800.00,'refunded','广东','app',TIMESTAMP '2026-07-21 13:00:00','20260721'),
    ('o10','u1','p1',500.00,'paid','广东','app',TIMESTAMP '2026-07-21 14:00:00','20260721');

-- 7) ETL：ODS -> DWD
INSERT INTO dwd_user_info SELECT user_id, user_name, register_channel, register_date FROM ods_user_info;
INSERT INTO dwd_product_info SELECT product_id, product_name, category_name FROM ods_product_info;
INSERT INTO dwd_order_info
SELECT
    order_id, user_id, product_id, order_amount, order_status,
    CASE WHEN order_status = 'refunded' THEN 1 ELSE 0 END AS is_refunded,
    province, channel, create_time, dt
FROM ods_order_info
WHERE order_amount IS NOT NULL AND order_amount > 0;

-- 8) ETL：DWD -> DWS
INSERT OVERWRITE dws_channel_order_day
SELECT
    dt, channel,
    COUNT(DISTINCT user_id) AS uv,
    COUNT(*) AS order_cnt,
    SUM(CASE WHEN order_status='paid' THEN 1 ELSE 0 END) AS paid_order_cnt,
    SUM(CASE WHEN order_status='paid' THEN order_amount ELSE 0 END) AS gmv,
    SUM(CASE WHEN order_status='refunded' THEN 1 ELSE 0 END) AS refund_cnt
FROM dwd_order_info
GROUP BY dt, channel;

INSERT OVERWRITE dws_province_order_day
SELECT
    dt, province,
    COUNT(*) AS order_cnt,
    SUM(CASE WHEN order_status='paid' THEN 1 ELSE 0 END) AS paid_order_cnt,
    COUNT(DISTINCT CASE WHEN order_status='paid' THEN user_id END) AS paid_user_cnt,
    SUM(CASE WHEN order_status='paid' THEN order_amount ELSE 0 END) AS gmv
FROM dwd_order_info
GROUP BY dt, province;

INSERT OVERWRITE dws_product_sales_day
SELECT
    o.dt, o.product_id, p.product_name, p.category_name,
    COUNT(*) AS sale_cnt,
    SUM(o.order_amount) AS sale_amount
FROM dwd_order_info o
LEFT JOIN dwd_product_info p ON o.product_id = p.product_id
GROUP BY o.dt, o.product_id, p.product_name, p.category_name;

INSERT OVERWRITE dws_user_growth_day
SELECT
    register_date AS dt, register_channel,
    COUNT(*) AS new_user_cnt
FROM dwd_user_info
GROUP BY register_date, register_channel;

-- 9) ETL：DWS -> ADS（5 张应用表）
INSERT OVERWRITE ads_trade_overview_di
SELECT
    dt,
    COUNT(*) AS total_order_cnt,
    SUM(CASE WHEN order_status='paid' THEN 1 ELSE 0 END) AS paid_order_cnt,
    SUM(CASE WHEN order_status='paid' THEN order_amount ELSE 0 END) AS total_gmv,
    COUNT(DISTINCT CASE WHEN order_status='paid' THEN user_id END) AS paid_user_cnt
FROM dwd_order_info
GROUP BY dt;

INSERT OVERWRITE ads_channel_conversion_di
SELECT
    c.dt, c.channel,
    c.uv * 10 AS visit_uv,
    c.order_cnt,
    c.paid_order_cnt,
    c.gmv,
    CAST(c.order_cnt AS DECIMAL(16,4)) / NULLIF(c.uv * 10, 0) AS order_conversion_rate,
    CAST(c.paid_order_cnt AS DECIMAL(16,4)) / NULLIF(c.uv * 10, 0) AS pay_conversion_rate
FROM dws_channel_order_day c;

INSERT OVERWRITE ads_region_gmv_di
SELECT dt, province, order_cnt, paid_order_cnt, paid_user_cnt, gmv
FROM dws_province_order_day;

INSERT OVERWRITE ads_product_sales_rank_di
SELECT
    dt,
    CAST(product_id AS BIGINT) AS product_id,
    product_name, category_name, sale_cnt, sale_amount
FROM dws_product_sales_day;

INSERT OVERWRITE ads_user_growth_di
SELECT dt, register_channel, new_user_cnt
FROM dws_user_growth_day;
