-- ============================================================
-- Flink SQL Client 自动初始化文件（每次进会话自动执行）
-- 作用：自动建好常用 catalog，解决「每次进 Flink 都要重跑 CREATE CATALOG」的痛点。
--
-- 为什么用 -i 而不是把 catalog 存进 HMS？
--   Flink 1.17 不支持 catalog-store.kind=hive（该能力在 1.18+ 才有），
--   所以 catalog【定义】无法持久化到 HMS；HMS 只能存 Paimon【表元数据】。
--   -i 初始化文件是 1.17 下最稳、零依赖的解法：进会话即自动建好 catalog。
--
-- 本 catalog 指向 OSS（S3-compatible）主仓库，与 StarRocks 的 paimon_oss_catalog 对齐。
-- 历史 file:///paimon_warehouse（docker 卷）方案已弃用，确保主链路 ODS/DWD 全部落 OSS。
-- 需要 HMS 注册元数据的 catalog 见 catalogs_hive.sql（单独跑，避免 HMS 挂掉连累日常会话）。
-- ============================================================

CREATE CATALOG paimon_catalog1 WITH (
  'type' = 'paimon',
  'warehouse' = 's3://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse',
  's3.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  's3.access-key' = '<YOUR_OSS_ACCESS_KEY>',
  's3.secret-key' = '<YOUR_OSS_SECRET_KEY>'
);
