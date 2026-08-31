"""
初始化 MySQL 业务维表
运行前请确保 MySQL 容器已启动
"""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mock"))

from common.mysql_utils import execute_sql


DDL_SQL = """
-- ============================================================
-- CRM 客户表
-- ============================================================
CREATE TABLE IF NOT EXISTS crm_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(100),
    phone_mask VARCHAR(20),
    gender TINYINT,
    age_range VARCHAR(20),
    province VARCHAR(50),
    city VARCHAR(50),
    source_channel VARCHAR(50),
    member_level VARCHAR(20),
    first_order_time DATETIME,
    last_order_time DATETIME,
    total_order_cnt INT DEFAULT 0,
    total_gmv DECIMAL(18,2) DEFAULT 0,
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crm_customer_tag (
    customer_id VARCHAR(50),
    tag_name VARCHAR(50),
    tag_category VARCHAR(50),
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, tag_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 营销表
-- ============================================================
CREATE TABLE IF NOT EXISTS mkt_coupon_info (
    coupon_id VARCHAR(50) PRIMARY KEY,
    coupon_name VARCHAR(100),
    coupon_type VARCHAR(20),
    min_amount DECIMAL(18,2),
    discount_amount DECIMAL(18,2),
    start_time DATETIME,
    end_time DATETIME,
    total_count INT,
    status TINYINT DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mkt_activity_info (
    activity_id VARCHAR(50) PRIMARY KEY,
    activity_name VARCHAR(100),
    activity_type VARCHAR(20),
    start_time DATETIME,
    end_time DATETIME,
    platform_id VARCHAR(50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- ERP 商品域表
-- ============================================================
CREATE TABLE IF NOT EXISTS erp_spu_info (
    spu_id VARCHAR(50) PRIMARY KEY,
    spu_name VARCHAR(200),
    category_id VARCHAR(50),
    category_name VARCHAR(100),
    brand_id VARCHAR(50),
    brand_name VARCHAR(100),
    status TINYINT DEFAULT 1,
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_sku_info (
    sku_id VARCHAR(50) PRIMARY KEY,
    sku_name VARCHAR(200),
    spu_id VARCHAR(50),
    spec_info VARCHAR(200),
    unit VARCHAR(20),
    cost_price DECIMAL(18,2),
    sale_price DECIMAL(18,2),
    status TINYINT DEFAULT 1,
    taobao_outer_id VARCHAR(100),
    taobao_sku_id VARCHAR(100),
    douyin_outer_id VARCHAR(100),
    douyin_sku_id VARCHAR(100),
    mall_outer_id VARCHAR(100),
    mall_sku_id VARCHAR(100),
    is_bundle TINYINT DEFAULT 0,
    bundle_id VARCHAR(50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_bundle_info (
    bundle_id VARCHAR(50) PRIMARY KEY,
    bundle_name VARCHAR(200),
    spu_id VARCHAR(50),
    sale_mode VARCHAR(20),
    sale_price DECIMAL(18,2),
    status TINYINT DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_bundle_detail (
    bundle_id VARCHAR(50),
    sku_id VARCHAR(50),
    sku_type VARCHAR(20),
    quantity INT,
    PRIMARY KEY (bundle_id, sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_inventory (
    sku_id VARCHAR(50),
    warehouse_id VARCHAR(50),
    warehouse_name VARCHAR(100),
    stock_qty BIGINT DEFAULT 0,
    available_qty BIGINT DEFAULT 0,
    reserved_qty BIGINT DEFAULT 0,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (sku_id, warehouse_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS erp_inventory_log (
    log_id BIGINT PRIMARY KEY,
    sku_id VARCHAR(50),
    warehouse_id VARCHAR(50),
    change_qty BIGINT,
    change_type VARCHAR(20),
    biz_type VARCHAR(50),
    biz_id VARCHAR(100),
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"""


def init_tables():
    """执行所有建表语句"""
    for statement in DDL_SQL.strip().split(";"):
        sql = statement.strip()
        if sql:
            execute_sql(sql)
    print("[MySQL] 所有维表初始化完成")


if __name__ == "__main__":
    init_tables()
