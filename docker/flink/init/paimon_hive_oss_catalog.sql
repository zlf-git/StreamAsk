-- ============================================================
-- 在 Flink 中创建「Paimon + Hive Metastore + 阿里云 OSS」catalog
-- 要点（逐条讲清，方便你之后自己改）：
--   1) 'type'='paimon'             —— 用 Paimon 连接器
--   2) 'warehouse'                 —— Paimon 表数据实际落盘的位置（这里是 OSS）
--   3) 'metastore'='hive'          —— 把【表元数据】注册进 Hive Metastore
--                                      (好处：表可被多引擎发现，Flink 重启不丢表定义)
--   4) 'uri'                       —— HMS 的 Thrift 地址（容器名 hive-metastore，端口 9083）
--   5) 'fs.oss.*'                  —— OSS 访问配置（由 paimon-oss jar 提供 oss:// 协议实现）
-- ============================================================
CREATE CATALOG paimon_hive_oss WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  'metastore' = 'hive',
  -- 重要：Docker 网络搜索域含下划线(_)，Java URI 不允许主机名带下划线，
  -- 所以已在两个 Flink 容器的 /etc/hosts 写入 `172.18.0.7 hive-metastore`，
  -- 让反向 DNS 解析到干净主机名（而非带下划线的 FQDN）。这里用服务名即可。
  'uri' = 'thrift://hive-metastore:9083',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = '<YOUR_OSS_ACCESS_KEY>',
  'fs.oss.accessKeySecret' = '<YOUR_OSS_SECRET_KEY>'
);

USE CATALOG paimon_hive_oss;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

-- 一张最小主键表，仅用于验证「建表即注册进 HMS」是否成功
CREATE TABLE IF NOT EXISTS test_hive_oss (
  id   INT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');
