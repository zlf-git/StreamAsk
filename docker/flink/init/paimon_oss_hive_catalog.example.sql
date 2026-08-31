-- ============================================================
-- 生产级 Paimon Catalog（模板，无凭证）
-- 特点：
--   1. 元数据持久化到 Hive Metastore（thrift://hive-metastore:9083）
--      → Flink SQL Client 重启后无需重新 CREATE CATALOG，表定义不丢
--   2. 数据落到阿里云 OSS（分布式存储，非 file:// 单点）
-- 运行：
--   docker exec -e LC_ALL=C.UTF-8 -it flink-jobmanager ./bin/sql-client.sh -f /flink-init/paimon_oss_hive_catalog.sql
-- 注意：
--   - 真实凭证版见 paimon_oss_hive_catalog.sql（已 gitignore）
--   - fs.oss.* 是 Paimon 读 OSS 所需，prefix 直接写 fs.oss（不是 paimon.option.fs.oss）
-- ============================================================

CREATE CATALOG IF NOT EXISTS paimon_oss_hive WITH (
    'type' = 'paimon',
    'metastore' = 'hive',
    'uri' = 'thrift://hive-metastore:9083',
    'warehouse' = 'oss://<your-bucket>/paimon/warehouse',
    'fs.oss.endpoint' = 'oss-cn-xxxx.aliyuncs.com',
    'fs.oss.accessKeyId' = '<your-access-key-id>',
    'fs.oss.accessKeySecret' = '<your-access-key-secret>'
);

USE CATALOG paimon_oss_hive;
CREATE DATABASE IF NOT EXISTS mall_dw;
USE mall_dw;

-- 验证用测试表（主键表）
CREATE TABLE IF NOT EXISTS test_oss_hive (
    id  STRING,
    v   INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO test_oss_hive VALUES ('a', 1), ('b', 2), ('c', 3);

-- 退出 SQL Client 再重新进入，执行下面两句应仍能查到数据
-- （证明 catalog 元数据已持久化到 Hive Metastore）
-- USE CATALOG paimon_oss_hive;
-- SELECT * FROM mall_dw.test_oss_hive;
