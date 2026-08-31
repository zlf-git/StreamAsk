-- Paimon + Hive Metastore + OSS 端到端验证
-- 关键：必须显式指定 fs.oss.impl，否则 Hadoop 找不到 oss 文件系统实现
--       （paimon-oss jar 不含 AliyunOSSFileSystem，需靠该配置类触发加载）
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

CREATE CATALOG paimon_hive_oss WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  'metastore' = 'hive',
  'uri' = 'thrift://hive-metastore:9083',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
  'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>',
  'fs.oss.impl' = 'org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem'
);

USE CATALOG paimon_hive_oss;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE IF NOT EXISTS test_hive_oss (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO test_hive_oss VALUES (1, 'alice'), (2, 'bob'), (3, 'carol');
