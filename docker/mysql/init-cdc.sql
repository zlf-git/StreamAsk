-- CDC 数据源初始化
-- 给 Flink CDC 提供 MySQL binlog 数据
-- 数据库: cdc_source, 表: orders

CREATE DATABASE IF NOT EXISTS cdc_source
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE cdc_source;

CREATE TABLE IF NOT EXISTS orders (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id        VARCHAR(64) NOT NULL COMMENT '平台订单号',
    platform_code   VARCHAR(32) DEFAULT 'DOUYIN' COMMENT '平台编码',
    shop_id         VARCHAR(32) DEFAULT 'insta360_official' COMMENT '店铺 ID',
    buyer_uid       VARCHAR(64) DEFAULT '' COMMENT '买家 ID',
    total_amount    DECIMAL(16,2) DEFAULT 0 COMMENT '订单总金额',
    pay_status      VARCHAR(32) DEFAULT 'PAID' COMMENT '支付状态',
    create_time     DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '订单创建时间',
    INDEX idx_order_id (order_id),
    INDEX idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 插入 100 条模拟抖音订单，作为 CDC 初始快照数据
INSERT INTO orders (order_id, platform_code, shop_id, buyer_uid, total_amount, pay_status, create_time)
SELECT
    CONCAT('DY20260820', LPAD(seq, 8, '0')) AS order_id,
    'DOUYIN' AS platform_code,
    'insta360_official' AS shop_id,
    CONCAT('buyer_', LPAD(seq, 6, '0')) AS buyer_uid,
    ROUND(2999 + RAND() * 5000, 2) AS total_amount,
    CASE WHEN seq % 10 = 0 THEN 'UNPAID' ELSE 'PAID' END AS pay_status,
    DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 7) DAY) AS create_time
FROM (
    SELECT @row := @row + 1 AS seq
    FROM (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) t1,
         (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) t2,
         (SELECT 0 UNION ALL SELECT 2 UNION ALL SELECT 3) t3,
         (SELECT @row := 0) t4
) nums
WHERE seq <= 100;
