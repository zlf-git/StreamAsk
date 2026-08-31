-- 干净版 Paimon 0.8 OSS 验证：不写 fs.oss.impl，让 Paimon 自带 OSSLoader 通过 SPI 自动接管
-- 仅给 oss 的 endpoint / ak / sk 三项即可
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

DROP CATALOG IF EXISTS paimon_oss_clean;
CREATE CATALOG paimon_oss_clean WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
  'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>'
);

USE CATALOG paimon_oss_clean;
CREATE DATABASE IF NOT EXISTS oss_demo;
USE oss_demo;

DROP TABLE IF EXISTS t_clean;
CREATE TABLE t_clean (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO t_clean VALUES (1, 'alice'), (2, 'bob'), (3, 'carol');

-- 回读验证：若 Flink 能读回自己写的数据，说明 OSS 写入真实落盘
SELECT * FROM t_clean ORDER BY id;
