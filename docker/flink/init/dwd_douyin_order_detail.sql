-- ============================================================
-- DWD 层：抖音订单明细表
-- 目标：把 ODS 订单表里的 items 数组炸开，变成"一行一个 SKU"的事实表
-- 主键：order_id + order_item_id
-- ============================================================

-- 0. 开启 checkpoint：Paimon 表写入依赖 checkpoint 触发
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

-- 本次从 ODS 初始化 DWD，用批模式一次性处理历史数据
SET 'execution.runtime-mode' = 'batch';
-- Paimon sink 不支持 Flink 自适应并行度，显式关闭
SET 'sql-session.adaptive-parallelism.enabled' = 'false';

-- 1. 使用已有的 Paimon catalog（warehouse 已统一为 OSS）
USE CATALOG paimon_catalog1;
USE mall_dw;

-- 2. 创建 DWD 明细 sink 表
-- 每一行代表一个订单里的一个 SKU 明细
CREATE TABLE IF NOT EXISTS dwd_douyin_order_detail (
    -- 订单级字段（来自 ODS 订单头）
    order_id                STRING,
    platform_code           STRING,
    platform_name           STRING,
    shop_id                 STRING,
    shop_name               STRING,
    buyer_uid               STRING,
    buyer_nick              STRING,
    order_status            STRING,
    pay_status              STRING,
    pay_time                TIMESTAMP(3),
    create_time             TIMESTAMP(3),

    -- SKU 明细级字段（来自 items 数组炸开后的每个元素）
    order_item_id           STRING,
    outer_id                STRING,
    platform_sku_id         STRING,
    sku_name                STRING,
    spu_id                  STRING,
    spu_name                STRING,
    brand                   STRING,
    quantity                INT,
    unit                    STRING,
    unit_price              DECIMAL(16,2),
    item_amount             DECIMAL(16,2),
    discount_amount         DECIMAL(16,2),
    item_pay_amount         DECIMAL(16,2),
    platform_category_id    STRING,
    platform_category_path  STRING,
    platform_category_level INT,
    company_category_id     STRING,
    company_category_path   STRING,

    -- 处理时间，用于后续去重/排序
    proc_time               TIMESTAMP(3),

    -- 联合主键：一个订单 + 一个明细行唯一确定一行
    PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
) WITH (
    'connector' = 'paimon',
    -- 明细表通常按 order_id 分桶，方便后续按订单聚合
    'bucket' = '2'
);

-- 3. 从 ODS 订单表写入 DWD 明细表
-- 核心语法：CROSS JOIN UNNEST(items) 把数组炸成多行
INSERT INTO dwd_douyin_order_detail
SELECT
    o.order_id,
    o.platform_code,
    o.platform_name,
    o.shop_id,
    o.shop_name,
    o.buyer_uid,
    o.buyer_nick,
    o.order_status,
    o.pay_status,
    o.pay_time,
    o.create_time,

    -- items 数组炸开后，每个 item 是一个 ROW，点号取字段
    item.order_item_id,
    item.outer_id,
    item.platform_sku_id,
    item.sku_name,
    item.spu_id,
    item.spu_name,
    item.brand,
    item.quantity,
    item.unit,
    item.unit_price,
    item.item_amount,
    item.discount_amount,
    item.pay_amount          AS item_pay_amount,
    item.platform_category_id,
    item.platform_category_path,
    item.platform_category_level,
    item.company_category_id,
    item.company_category_path,

    o.proc_time
FROM ods_douyin_order o
CROSS JOIN UNNEST(o.items) AS item;
