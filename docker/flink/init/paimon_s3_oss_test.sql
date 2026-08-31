-- Paimon S3 loader + 阿里云 OSS S3-compatible endpoint
-- warehouse 用 s3:// 协议，但底层是同一个阿里云 OSS bucket
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

DROP CATALOG IF EXISTS paimon_s3_oss;
CREATE CATALOG paimon_s3_oss WITH (
  'type' = 'paimon',
  'warehouse' = 's3://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  's3.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  's3.access-key' = '<YOUR_OSS_ACCESS_KEY>',
  's3.secret-key' = '<YOUR_OSS_SECRET_KEY>'
);

USE CATALOG paimon_s3_oss;
CREATE DATABASE IF NOT EXISTS s3_demo;
USE s3_demo;

DROP TABLE IF EXISTS t_s3;
CREATE TABLE t_s3 (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO t_s3 VALUES (1, 'alice'), (2, 'bob'), (3, 'carol');
