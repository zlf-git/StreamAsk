-- 批模式回读 OSS 表：验证 Flink 是否真的把数据写进了 OSS
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'TABLEAU';

CREATE CATALOG paimon_oss_clean WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
  'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>'
);

USE CATALOG paimon_oss_clean;
USE oss_demo;
SELECT * FROM t_clean;
