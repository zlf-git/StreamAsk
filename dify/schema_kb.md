# 抖音电商实时数仓 Schema 知识库

## 数仓环境
- 查询引擎：StarRocks（MySQL 协议，9030 端口）
- 数据源：Paimon 外部 Catalog
- Catalog 名：`paimon_oss_catalog`
- 库名：`mall_dw`
- 所有查询必须写完整三段式：`paimon_oss_catalog.mall_dw.<表名>`
- 时间字段统一为 `stat_date`，类型 STRING，格式 `yyyy-MM-dd`
- "最近 N 天" 写法：`stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL {N-1} DAY) AS STRING)`
- "指定某天" 写法：`stat_date = '2026-08-26'`
- 只允许 SELECT；禁止 INSERT/UPDATE/DELETE/DROP/TRUNCATE/ALTER/CREATE
- 明细查询 LIMIT ≤ 200；聚合/排行 LIMIT ≤ 100

---

## 表 1：paimon_oss_catalog.mall_dw.ads_realtime_overview
**用途**：平台整体经营总览。GMV、订单数、支付、买家数、客单价趋势。
**主键**：stat_date
**字段**：
- stat_date STRING 统计日期 yyyy-MM-dd
- gmv DECIMAL(16,2) 成交总额
- order_cnt BIGINT 总订单数
- buyer_uv BIGINT 买家数
- paid_order_cnt BIGINT 支付订单数
- paid_gmv DECIMAL(16,2) 支付 GMV
- paid_buyer_uv BIGINT 支付买家数
- discount_amt DECIMAL(16,2) 优惠金额
- freight_amt DECIMAL(16,2) 运费
- avg_order_amount DECIMAL(16,2) 平均客单价
**典型问题**："今天 GMV 多少"、"最近一周整体趋势"、"平均客单价"

---

## 表 2：paimon_oss_catalog.mall_dw.ads_shop_rank_daily
**用途**：店铺日排行。GMV 最高的前 N 个店铺。
**主键**：(stat_date, shop_id)
**字段**：
- stat_date STRING 统计日期 yyyy-MM-dd
- rank_no INT 排名（1 为最高）
- shop_id STRING 店铺 ID
- shop_name STRING 店铺名
- gmv DECIMAL(16,2) GMV
- order_cnt BIGINT 订单数
- buyer_uv BIGINT 买家数
- avg_order_amount DECIMAL(16,2) 客单价
**典型问题**："昨天 GMV 最高的前 10 个店铺"、"本周头部店铺"

---

## 表 3：paimon_oss_catalog.mall_dw.ads_top_spu_daily
**用途**：SPU（商品）日排行。卖得最好的商品。
**主键**：(stat_date, spu_id)
**字段**：
- stat_date STRING 统计日期
- rank_no INT 排名
- spu_id STRING SPU ID
- spu_name STRING SPU 名称
- brand STRING 品牌
- quantity BIGINT 销量
- gmv DECIMAL(16,2) GMV
- order_cnt BIGINT 订单数
- buyer_uv BIGINT 买家数
**典型问题**："本周卖得最好的前 10 个商品"、"哪个品牌卖得最好"

---

## 表 4：paimon_oss_catalog.mall_dw.dws_shop_daily_gmv
**用途**：店铺日维度的明细汇总（不是排行，可看每个店铺每天的数据）。
**主键**：(stat_date, shop_id)
**字段**：
- stat_date STRING
- shop_id STRING
- shop_name STRING
- order_cnt BIGINT
- buyer_uv BIGINT
- gmv DECIMAL(16,2)
- discount_amt DECIMAL(16,2)
- freight_amt DECIMAL(16,2)
- net_pay_amt DECIMAL(16,2) 净支付金额
- avg_order_amount DECIMAL(16,2)
- total_quantity BIGINT
**典型问题**："某店铺最近 7 天的 GMV 趋势"、"所有店铺的净支付金额对比"

---

## 表 5：paimon_oss_catalog.mall_dw.dws_spu_daily_sales
**用途**：SPU 日维度明细汇总。
**主键**：(stat_date, spu_id)
**字段**：
- stat_date STRING
- spu_id STRING
- spu_name STRING
- brand STRING
- order_cnt BIGINT
- sku_sold_cnt BIGINT
- quantity BIGINT
- gmv DECIMAL(16,2)
- discount_amt DECIMAL(16,2)
- buyer_uv BIGINT
**典型问题**："某商品最近 7 天的销量"、"某品牌的销售情况"

---

## 表 6：paimon_oss_catalog.mall_dw.dws_category_daily_sales
**用途**：类目日维度明细汇总。
**主键**：(stat_date, company_category_id)
**字段**：
- stat_date STRING
- company_category_id STRING
- company_category_path STRING 公司 4 层类目路径（用 `>` 分隔，例如 `相机>运动相机>GoPro系列>GoPro12`）
- order_cnt BIGINT
- quantity BIGINT
- gmv DECIMAL(16,2)
- discount_amt DECIMAL(16,2)
- buyer_uv BIGINT
**典型问题**："某类目的 GMV"、"一级类目 GMV 排行"

---

## 表 7：paimon_oss_catalog.mall_dw.dws_user_daily_activity
**用途**：用户日活、人均指标。
**主键**：stat_date
**字段**：
- stat_date STRING
- buyer_uv BIGINT 买家数
- new_buyer_uv BIGINT 新买家数
- order_cnt BIGINT
- gmv DECIMAL(16,2)
- avg_orders_per_user DECIMAL(16,4) 人均单数
- avg_gmv_per_user DECIMAL(16,2) 人均金额
**典型问题**："日活买家数"、"新买家占比"、"人均单数"

---

## 业务术语 → 字段映射
- GMV / 成交额 / 销售额 → gmv
- 订单数 / 单量 → order_cnt
- 支付订单 → paid_order_cnt
- 买家数 / 人数 / UV → buyer_uv
- 客单价 → avg_order_amount
- 销量 / 销售量 → quantity（SPU 表）或 total_quantity（店铺表）
- 优惠 / 折扣 → discount_amt
- 运费 → freight_amt
- 品牌 → brand
- 类目 → company_category_path / company_category_id
- 店铺 → shop_name / shop_id
- 商品 / SPU → spu_name / spu_id
- 人均单数 → avg_orders_per_user
- 人均金额 → avg_gmv_per_user
- 排名 → rank_no（ADS 排行表已算好）

【同义词归一（口语 → 维度）】
- 品 / 商品 / 货 / 宝贝 / 单品 / 款式 / SKU → 统一按 **SPU 粒度**处理（spu_id / spu_name）
  注意：本数仓**没有独立的 SKU 维度表**，SKU 仅作为 sku_sold_cnt（售出 SKU 数）字段存在
- 店铺 / 门店 / 商家 / 卖家 → shop_name / shop_id
- 品牌 / 牌子 / 厂商 → brand
- 类目 / 品类 / 分类 / 品种 → company_category_path / company_category_id
- 客人 / 用户 / 买家 / 消费者 → buyer_uv
- 单 / 单量 / 订单 → order_cnt

【排序口径消歧（重要）】
- 卖得最好 / 最畅销 / 爆款 / 卖得最多 / 最好卖 / 头号 → **ORDER BY gmv DESC**（默认按销售额）
- 销量最高 / 卖得最多件 / 卖得数量最多 → ORDER BY quantity DESC
- 人气最高 / 买的人最多 / 访客最多 → ORDER BY buyer_uv DESC
- 客单价最高 → ORDER BY avg_order_amount DESC
- 头部 / Top / 前几名 → LIMIT N；未说明 N 时默认 LIMIT 10

---

## Few-shot 示例（问题 → SQL）

Q: 最近 7 天整体 GMV 趋势
A: SELECT stat_date, gmv FROM paimon_oss_catalog.mall_dw.ads_realtime_overview
   WHERE stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS STRING)
   ORDER BY stat_date ASC;

Q: 昨天 GMV 最高的前 10 个店铺
A: SELECT shop_name, gmv FROM paimon_oss_catalog.mall_dw.ads_shop_rank_daily
   WHERE stat_date = CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS STRING)
   ORDER BY rank_no ASC LIMIT 10;

Q: 本周卖得最好的前 10 个商品
A: SELECT spu_name, brand, gmv, quantity FROM paimon_oss_catalog.mall_dw.ads_top_spu_daily
   WHERE stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS STRING)
   ORDER BY rank_no ASC LIMIT 10;

---

## 指标口径字典（Semantic Layer）

### 指标 1：GMV（成交总额）
- **业务定义**：已支付订单的金额合计，不扣退款
- **SQL 片段**：`SUM(gmv)` 或直接用 `gmv`（汇总表已聚合好）
- **可用表**：ads_realtime_overview / dws_shop_daily_gmv / dws_spu_daily_sales / dws_category_daily_sales
- **常见问法**：卖了多少钱 / 销售额 / 成交额 / GMV / 营收
- **易混淆**：≠ 销量(quantity) ≠ 净支付金额(net_pay_amt) ≠ 支付GMV(paid_gmv)

### 指标 2：销量（quantity）
- **业务定义**：售出的商品件数
- **SQL 片段**：`SUM(quantity)`；店铺表用 `total_quantity`
- **可用表**：dws_spu_daily_sales / dws_category_daily_sales / ads_top_spu_daily
- **常见问法**：卖了多少件 / 出货量 / 件数
- **易混淆**：≠ sku_sold_cnt（该字段是"售出的 SKU 种类数"，不是件数）

### 指标 3：客单价（avg_order_amount）
- **业务定义**：GMV ÷ 订单数
- **可用表**：ads_realtime_overview / dws_shop_daily_gmv / ads_shop_rank_daily
- **常见问法**：平均每单多少钱 / 单均价 / 客单

### 指标 4：买家数（buyer_uv）
- **业务定义**：下单的去重买家数
- **可用表**：ads_realtime_overview / dws_user_daily_activity / dws_shop_daily_gmv
- **常见问法**：多少人买 / 客群规模 / 用户数

### 指标 5：排名（rank_no）
- **业务定义**：ADS 排行表**已预计算**好的名次，1 为最高
- **可用表**：ads_shop_rank_daily / ads_top_spu_daily
- **用法**：取第一名用 `rank_no = 1`；取前 N 名用 `ORDER BY rank_no ASC LIMIT N`
- **注意**：排行表按日计算，跨时间范围汇总需改用 dws 汇总表自行聚合

### 指标 6：净支付金额（net_pay_amt）
- **业务定义**：GMV − 优惠金额 − 运费后的实付金额
- **可用表**：dws_shop_daily_gmv
- **常见问法**：实付 / 到手金额 / 净收入

### 通用时间口径
- 未指定时间 → 默认最近 7 天
- 昨天 / 今天 / 本周 / 上月 → 换算为具体 stat_date 区间
- 所有日期字段为 STRING 类型，格式 'yyyy-MM-dd'
- 跨天汇总（如"最近7天总GMV"）→ 用 dws 汇总表 + SUM；不要对 ADS 排行表直接 SUM
