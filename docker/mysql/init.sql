-- MySQL 初始化脚本
-- 兼容原项目 database.py 的表结构

CREATE DATABASE IF NOT EXISTS ai_data_analysis
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ai_data_analysis;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(128) NOT NULL,
    allowed_tables VARCHAR(500) DEFAULT '',
    is_admin TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建管理员账号：admin / 123456
-- 密码为 '123456' 的 SHA256 哈希，与原项目 database.py 一致
INSERT INTO users (username, password, allowed_tables, is_admin)
SELECT 'admin',
       '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
       'ads_trade_overview_di,ads_channel_conversion_di,ads_region_gmv_di,ads_product_sales_rank_di,ads_user_growth_di',
       1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');
