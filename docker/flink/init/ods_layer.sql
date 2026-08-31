-- ============================================================
-- ODS 层：Kafka Source 表定义
-- 说明：
--   1. ODS 层直接对接 Kafka 实时事件流，保留原始 JSON 字段
--   2. 表名统一以 ods_xxx_kafka 结尾，方便识别来源
--   3. 所有表都带 proc_time（处理时间），方便后续 Lookup Join 和窗口计算
-- ============================================================

-- ---------- 1. 抖音电商订单事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_douyin_order_kafka (
    shop_order_id STRING,
    create_time STRING,
    pay_time STRING,
    order_status INT,
    order_status_desc STRING,
    order_amount BIGINT,
    pay_amount BIGINT,
    post_amount BIGINT,
    buyer_uid STRING,
    user_nick_name STRING,
    receiver_name STRING,
    receiver_mobile STRING,
    province STRING,
    city STRING,
    sku_order_list ARRAY<ROW<
        sku_id STRING,
        product_id STRING,
        product_name STRING,
        out_sku_id STRING,
        item_num INT,
        goods_price BIGINT,
        pay_amount BIGINT,
        promotion_amount BIGINT,
        room_id STRING,
        video_id STRING,
        author_id STRING,
        author_name STRING,
        content_id STRING,
        first_cid STRING,
        second_cid STRING
    >>,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_douyin_order_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-douyin-order',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);

-- ---------- 2. 淘宝订单事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_taobao_order_kafka (
    tid STRING,
    oid STRING,
    status STRING,
    type STRING,
    payment STRING,
    total_fee STRING,
    discount_fee STRING,
    created STRING,
    pay_time STRING,
    buyer_open_uid STRING,
    buyer_nick STRING,
    receiver_state STRING,
    receiver_city STRING,
    receiver_district STRING,
    receiver_address STRING,
    receiver_mobile STRING,
    orders ARRAY<ROW<
        oid STRING,
        num_iid STRING,
        title STRING,
        price STRING,
        num INT,
        payment STRING,
        sku_id STRING,
        outer_sku_id STRING,
        refund_status STRING
    >>,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_taobao_order_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-taobao-order',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);

-- ---------- 3. 自有商城订单事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_mall_order_kafka (
    order_id STRING,
    user_id STRING,
    platform_id STRING,
    source_type STRING,
    scene STRING,
    sku_id STRING,
    outer_sku_id STRING,
    sku_name STRING,
    quantity INT,
    order_amount DECIMAL(18,2),
    discount_amount DECIMAL(18,2),
    pay_amount DECIMAL(18,2),
    coupon_id STRING,
    order_status STRING,
    create_time STRING,
    pay_time STRING,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_mall_order_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-mall-order',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);

-- ---------- 4. 小程序行为事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_mp_behavior_kafka (
    event_id STRING,
    user_id STRING,
    session_id STRING,
    event_type STRING,
    page_path STRING,
    sku_id STRING,
    keyword STRING,
    scene STRING,
    referrer_info STRING,
    create_time STRING,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_mp_behavior_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-mp-behavior',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);

-- ---------- 5. 广告花费事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_ad_cost_kafka (
    ad_id STRING,
    platform_id STRING,
    ad_type STRING,
    cost_amount DECIMAL(18,2),
    exposure_cnt BIGINT,
    click_cnt BIGINT,
    hour STRING,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_ad_cost_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-ad-cost',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);

-- ---------- 6. 库存变动事件（ODS） ----------
CREATE TABLE IF NOT EXISTS ods_inventory_change_kafka (
    log_id BIGINT,
    sku_id STRING,
    warehouse_id STRING,
    change_qty BIGINT,
    change_type STRING,
    biz_type STRING,
    biz_id STRING,
    create_time STRING,
    proc_time AS PROCTIME(),
    event_time TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods_inventory_change_event',
    'properties.bootstrap.servers' = 'kafka-ai-analysis:9092',
    'properties.group.id' = 'flink-ods-inventory-change',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset',
    'json.ignore-parse-errors' = 'true'
);
