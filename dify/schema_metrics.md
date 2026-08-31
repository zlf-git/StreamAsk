# 业务术语归一与指标口径字典（Semantic Layer）

> 作用：把业务端的口语表达，规范化映射到数仓的物理字段，实现"业务语言"与"应用层面"的拉齐。
> 数仓环境：StarRocks + Paimon 外部 Catalog，库为 `paimon_oss_catalog.mall_dw`。

---

## 一、同义词归一（口语 → 维度）

- **品 / 商品 / 货 / 宝贝 / 单品 / 款式 / SKU** → 统一按 **SPU 粒度**处理（`spu_id` / `spu_name`）
  - ⚠️ 本数仓**没有独立的 SKU 维度表**。SKU 仅作为 `sku_sold_cnt` 字段存在，其含义是"售出的 SKU 种类数"，**不是件数**，不能当销量用。
- **店铺 / 门店 / 商家 / 卖家** → `shop_name` / `shop_id`
- **品牌 / 牌子 / 厂商** → `brand`
- **类目 / 品类 / 分类 / 品种** → `company_category_path` / `company_category_id`
- **客人 / 用户 / 买家 / 消费者** → `buyer_uv`
- **单 / 单量 / 订单** → `order_cnt`

---

## 二、排序口径消歧（重要）

| 业务说法 | 对应排序 |
|---|---|
| 卖得最好 / 最畅销 / 爆款 / 卖得最多 / 最好卖 / 头号 | **`ORDER BY gmv DESC`**（默认按销售额） |
| 销量最高 / 卖得最多件 / 卖得数量最多 | `ORDER BY quantity DESC` |
| 人气最高 / 买的人最多 / 访客最多 | `ORDER BY buyer_uv DESC` |
| 客单价最高 | `ORDER BY avg_order_amount DESC` |
| 头部 / Top / 前几名 | `LIMIT N`；未说明 N 时默认 `LIMIT 10` |

**"卖得最好"默认按 GMV 而非销量。** 若用户明确说"件数/数量"，才用 quantity。

---

## 三、指标口径字典

### 指标 1：GMV（成交总额）
- **业务定义**：已支付订单的金额合计，不扣退款
- **SQL 片段**：`SUM(gmv)`，或直接用 `gmv`（汇总表已聚合好）
- **可用表**：`ads_realtime_overview` / `dws_shop_daily_gmv` / `dws_spu_daily_sales` / `dws_category_daily_sales`
- **常见问法**：卖了多少钱 / 销售额 / 成交额 / GMV / 营收
- **易混淆**：≠ 销量(`quantity`) ≠ 净支付金额(`net_pay_amt`) ≠ 支付GMV(`paid_gmv`)

### 指标 2：销量（quantity）
- **业务定义**：售出的商品件数
- **SQL 片段**：`SUM(quantity)`；店铺表用 `total_quantity`
- **可用表**：`dws_spu_daily_sales` / `dws_category_daily_sales` / `ads_top_spu_daily`
- **常见问法**：卖了多少件 / 出货量 / 件数
- **易混淆**：≠ `sku_sold_cnt`（该字段是"售出的 SKU 种类数"，不是件数）

### 指标 3：客单价（avg_order_amount）
- **业务定义**：GMV ÷ 订单数
- **可用表**：`ads_realtime_overview` / `dws_shop_daily_gmv` / `ads_shop_rank_daily`
- **常见问法**：平均每单多少钱 / 单均价 / 客单

### 指标 4：买家数（buyer_uv）
- **业务定义**：下单的去重买家数
- **可用表**：`ads_realtime_overview` / `dws_user_daily_activity` / `dws_shop_daily_gmv`
- **常见问法**：多少人买 / 客群规模 / 用户数

### 指标 5：排名（rank_no）
- **业务定义**：ADS 排行表**已预计算**好的名次，1 为最高
- **可用表**：`ads_shop_rank_daily` / `ads_top_spu_daily`
- **用法**：取第一名用 `rank_no = 1`；取前 N 名用 `ORDER BY rank_no ASC LIMIT N`
- **⚠️ 注意**：排行表按**单日**计算。跨时间范围汇总（如"最近7天总GMV最高的店铺"）必须改用 `dws` 汇总表自行 `SUM`，**不可对 ADS 排行表的 gmv 直接 SUM**。

### 指标 6：净支付金额（net_pay_amt）
- **业务定义**：GMV − 优惠金额 − 运费后的实付金额
- **可用表**：`dws_shop_daily_gmv`
- **常见问法**：实付 / 到手金额 / 净收入

---

## 四、通用时间口径

- **未指定时间** → 默认最近 7 天
- **昨天 / 今天 / 本周 / 上月** → 换算为具体的 `stat_date` 区间
- 所有日期字段为 **STRING** 类型，格式 `'yyyy-MM-dd'`
- **跨天汇总**（如"最近7天总GMV"）→ 用 `dws` 汇总表 + `SUM`；不要用 ADS 排行表直接 `SUM`
