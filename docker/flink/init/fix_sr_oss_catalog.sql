DROP CATALOG paimon_oss_catalog;

CREATE EXTERNAL CATALOG paimon_oss_catalog
PROPERTIES (
  "type" = "paimon",
  "paimon.catalog.type" = "filesystem",
  "paimon.catalog.warehouse" = "s3://oss-pai-bskr8dkhkct6pb80kn-cn-shanghai/paimon/warehouse",
  "paimon.option.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
  "paimon.option.s3.access-key" = "<YOUR_OSS_ACCESS_KEY>",
  "paimon.option.s3.secret-key" = "<YOUR_OSS_SECRET_KEY>",
  "aws.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
  "aws.s3.access_key" = "<YOUR_OSS_ACCESS_KEY>",
  "aws.s3.secret_key" = "<YOUR_OSS_SECRET_KEY>",
  "aws.s3.enable_ssl" = "true",
  "aws.s3.enable_path_style_access" = "false"
);
