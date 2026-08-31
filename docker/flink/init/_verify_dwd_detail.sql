SET sql-client.execution.result-mode=TABLEAU;
USE CATALOG paimon_catalog1;
USE mall_dw;
SET execution.runtime-mode=batch;
SELECT COUNT(*) AS total_detail_rows FROM dwd_douyin_order_detail;
SELECT order_id, outer_id, sku_name, quantity, item_pay_amount FROM dwd_douyin_order_detail LIMIT 5;
