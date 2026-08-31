-- OSS 连通性冒烟测试（filesystem 类型 catalog + OSS warehouse + checkpoint 提交）
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';

DROP CATALOG IF EXISTS paimon_oss_test;
CREATE CATALOG paimon_oss_test WITH (
    'type' = 'paimon',
    'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
    'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
    'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
    'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>',
    'fs.oss.impl' = 'org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem'
);

USE CATALOG paimon_oss_test;
CREATE DATABASE IF NOT EXISTS mall_dw;
USE mall_dw;

DROP TABLE IF EXISTS test_oss;
CREATE TABLE test_oss (
    id  STRING,
    v   INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');

INSERT INTO test_oss VALUES ('a', 1), ('b', 2), ('c', 3);
