-- ============================================================
-- 可选：注册「Paimon + Hive Metastore」catalog（表元数据进 HMS）
-- 用法（在已建好 paimon_catalog1 的基础上，单独执行本文件）：
--   bash flink_sql.sh -i /flink-init/catalogs_hive.sql
-- 依赖：hive-metastore 容器在运行（端口 9083 可达）。
-- 说明：本文件单独跑，不要并入 catalogs.sql，否则 HMS 宕机时会拖垮日常会话。
-- ============================================================

CREATE CATALOG paimon_hive_file WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse',
  'metastore' = 'hive',
  'uri' = 'thrift://hive-metastore:9083'
);
