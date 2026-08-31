-- 用「file:// 仓库 + Hive Metastore」证明 Paimon 表元数据能注册进 HMS
-- （绕开 OSS 文件系统 jar 缺失问题；数据落本地卷，元数据落 HMS）
CREATE CATALOG paimon_hive_file WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse',
  'metastore' = 'hive',
  'uri' = 'thrift://hive-metastore:9083'
);

USE CATALOG paimon_hive_file;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE IF NOT EXISTS test_hive_file (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');
