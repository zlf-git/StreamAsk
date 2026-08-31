-- 纯 OSS（不带 Hive Metastore）端到端验证：Flink 写 → OSS → StarRocks 读
-- 关键点：Paimon 数据由 checkpoint 触发提交，必须开 checkpoint
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

CREATE CATALOG paimon_oss2 WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
  'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>',
  'fs.oss.impl' = 'org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem'
);

USE CATALOG paimon_oss2;
CREATE DATABASE IF NOT EXISTS oss_demo;
USE oss_demo;

DROP TABLE IF EXISTS t1;
CREATE TABLE t1 (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO t1 VALUES (1, 'alice'), (2, 'bob'), (3, 'carol');
