# RAG + NL2SQL 提示词架构（贴合真实部署）

> 适用：Insta360 抖音订单实时数仓（StarRocks + Paimon 外部 Catalog）
> 核心原则：**用户问题只做检索输入，Schema 语义由向量库动态召回，再拼进 Prompt**。
> 已修正的关键事实：SQL 在 StarRocks 上执行，Catalog 必须用 `paimon_oss_catalog.mall_dw`（不是 Flink 的 `paimon_catalog1`）。

---

## 1. 为什么原来的 Prompt 不好

| 原来的写法 | 问题 | RAG 写法 |
|---|---|---|
| 把 7 张表 DDL 全塞进 system prompt | 静态、臃肿、爆 token；模型容易"顺手"用错字段 | Schema 由检索动态召回，只给相关片段 |
| 用 LLM 节点做"数据路由"选表 | 路由结果不可靠，且和检索职责重叠 | 检索天然完成"路由"，召回哪几张表就是哪几张 |
| 表名硬编码 `paimon_catalog1` | StarRocks 查不到，直接报 Unknown catalog | 用真实 `paimon_oss_catalog.mall_dw` |
| 权限校验信任 LLM 输出的 `candidate_tables` | LLM 可能漏报/错报 | 改解析**最终 SQL** 里实际引用的表 |

---

## 2. 工作流改造（节点级）

```
用户输入(input)
   │
   ├─► Knowledge Retrieval   ← 用户问题作为检索 query，召回相关 Schema 片段
   │        │  result（召回数组，每个元素含 content/title/metadata）
   │        │  → 关联进 Text2SQL 节点的「上下文变量」
   │        ▼
   ├─► Text2SQL (LLM)        ← system 只放规则+方言+catalog，Schema 用占位符注入
   │        │  {{#text2sql.text#}}
   │        ▼
   ├─► 权限校验 (Code)        ← 解析 SQL 里实际引用的表，比对 allowed_tables
   │        │  has_permission
   │        ▼
   ├─► if-else ──false──► 无权限兜底 (LLM)
   │        │ true
   │        ▼
   ├─► HTTP 请求              ← POST 到 Flask /api/starrocks/query
   │        │  body: {"sql": "{{#text2sql.text#}}"}
   │        ▼
   ├─► 数据分析 (LLM) + 数据可视化 (LLM)
   │        ▼
   └─► End
```

> 说明：把原来的"数据路由"LLM 节点**删掉/换成 Knowledge Retrieval 节点**。权限校验的入参从"路由 JSON"改为"Text2SQL 生成的 SQL 文本"。

---

## 3. Knowledge 库怎么建（召回质量决定 SQL 质量）

建一个 Dify 知识库，分段录入以下内容（每段一个 chunk，便于向量检索按相关性召回）：

**A. 每张表的 Schema 卡片（7 张）**，格式示例：
```
【表】paimon_oss_catalog.mall_dw.ads_realtime_overview
【用途】平台整体经营总览。适合：整体 GMV、订单数、支付、买家数、客单价趋势。
【主键】stat_date
【字段】
- stat_date STRING  统计日期 yyyy-MM-dd
- gmv DECIMAL(16,2) 成交总额
- order_cnt BIGINT 总订单数
- buyer_uv BIGINT 买家数
- paid_order_cnt BIGINT 支付订单数（本 demo 等同 order_cnt，DWS 已过滤已支付）
- paid_gmv DECIMAL(16,2) 支付 GMV
- paid_buyer_uv BIGINT 支付买家数
- discount_amt DECIMAL(16,2) 优惠金额
- freight_amt DECIMAL(16,2) 运费
- avg_order_amount DECIMAL(16,2) 平均客单价
【典型问题】"今天 GMV 多少"、"最近一周整体趋势"、"平均客单价"
```

其余 6 张表同理（字段严格按 `docker/flink/init/*.sql` 的真实 DDL）：
- `ads_shop_rank_daily`（店铺排行，含 rank_no/shop_id/shop_name/gmv/order_cnt/buyer_uv/avg_order_amount）
- `ads_top_spu_daily`（SPU 排行，含 rank_no/spu_id/spu_name/brand/quantity/gmv/order_cnt/buyer_uv）
- `dws_shop_daily_gmv`（店铺日汇总，含 shop_id/shop_name/order_cnt/buyer_uv/gmv/discount_amt/freight_amt/net_pay_amt/avg_order_amount/total_quantity）
- `dws_spu_daily_sales`（SPU 日汇总，含 spu_id/spu_name/brand/order_cnt/sku_sold_cnt/quantity/gmv/discount_amt/buyer_uv）
- `dws_category_daily_sales`（类目日汇总，含 company_category_id/company_category_path/order_cnt/quantity/gmv/discount_amt/buyer_uv）
- `dws_user_daily_activity`（用户日活，含 buyer_uv/new_buyer_uv/order_cnt/gmv/avg_orders_per_user/avg_gmv_per_user）

**B. 业务术语表**（帮助模型把口语映射到字段）：
```
GMV/成交额/销售额 → gmv
订单数/单量 → order_cnt
支付订单 → paid_order_cnt
买家数/人数/UV → buyer_uv
客单价 → avg_order_amount
销量/销售量 → quantity（SPU 表）或 total_quantity（店铺表）
优惠/折扣 → discount_amt
运费 → freight_amt
品牌 → brand
类目 → company_category_path
店铺 → shop_name / shop_id
商品/SPU → spu_name / spu_id
人均单数 → avg_orders_per_user
人均金额 → avg_gmv_per_user
排名 → rank_no（ADS 排行表已算好）
```

**C. Few-shot 示例**（问题→SQL，提升准确率）：
```
Q: 最近7天整体 GMV 趋势
A: SELECT stat_date, gmv FROM paimon_oss_catalog.mall_dw.ads_realtime_overview
   WHERE stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS STRING)
   ORDER BY stat_date ASC;

Q: 昨天 GMV 最高的前10个店铺
A: SELECT shop_name, gmv FROM paimon_oss_catalog.mall_dw.ads_shop_rank_daily
   WHERE stat_date = CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AS STRING)
   ORDER BY rank_no ASC LIMIT 10;

Q: 本周卖得最好的前10个商品
A: SELECT spu_name, brand, gmv, quantity FROM paimon_oss_catalog.mall_dw.ads_top_spu_daily
   WHERE stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS STRING)
   ORDER BY rank_no ASC LIMIT 10;
```

> 检索参数建议：TopK=4~6，召回字段片段 + 术语 + 示例混合，按问题相关性。

---

## 4. 各节点提示词（直接复制）

### 4.1 Knowledge Retrieval（配置，非提示词）
- **节点位置**：画布空白处点「+」→ 选择「知识检索（Knowledge Retrieval）」节点拖入。
- 知识库：上面建的 Schema 库（本场景只选这一个）。
- 检索变量（Query）：`{{#start.input#}}`（Workflow 类型；若你建的是 **Chatflow**，则用 `sys.query`）。
  ⚠️ 知识库单次查询上限 200 字符，问题过长会被截断。
- **输出变量叫 `result`（不是 text）**，类型是「召回分段数组」，每个元素含 content/title/metadata。
- **怎么让 Text2SQL 用上它（两种引用方式，推荐①）**：
  ①【推荐·上下文变量】在 Text2SQL 的 LLM 节点编辑面板里，找到「上下文 / Context」配置区 → 添加 → 选「知识检索」节点的 `result`。Dify 会自动把各分段 content 拼成纯文本注入。之后在 prompt 里用 `{{#<上下文变量名>#}}` 引用（建议命名 `schema_context`，见 4.2）。
  ②【直接引用·备选】在 prompt 里写 `{{#knowledge_retrieval.result#}}`。但 result 是数组，序列化后会带 title/metadata 结构噪声，**不如①干净**，仅作备选。

### 4.2 Text2SQL（核心节点）

```
你是 StarRocks + Paimon 的 NL2SQL 引擎。把用户的中文问题转换成可在 StarRocks 上执行的只读 SQL。

【执行环境（固定事实，不可违背）】
- 查询引擎：StarRocks（MySQL 协议，9030 端口），数据在 Paimon 外部 Catalog。
- 所有表必须写完整三段式：paimon_oss_catalog.mall_dw.<表名>。
  禁止只写表名，禁止写 mall_dw.<表名> 以外的任意前缀。
- stat_date 是 STRING，格式 'yyyy-MM-dd'。
  最近7天写法：stat_date >= CAST(DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS STRING)
  指定某天写法：stat_date = '2026-08-26'
- 只允许 SELECT（含 WITH 公共表表达式）；禁止 INSERT/UPDATE/DELETE/DROP/TRUNCATE/ALTER/CREATE。
- 明细查询最多 LIMIT 200；聚合/排行查询最多 LIMIT 100。
- 趋势类必须按 stat_date 升序；排行类必须按核心指标降序。

【Schema 上下文（来自向量检索，动态召回，仅可使用此处出现的表与字段）】
{{#schema_context#}}
（即：把知识检索节点的 result 配成名为 schema_context 的「上下文变量」后，在此处引用。若你直接写 `{{#knowledge_retrieval.result#}}` 也行，但会带数组结构噪声。）

【用户问题】
{{#start.input#}}

【生成规则】
1. 只能使用 Schema 上下文中出现的表和字段；上下文未出现的字段一律不得使用。
2. 如果问题需要的表没有被召回（不在上下文中），返回 NO_VALID_SQL 并说明缺哪张表。
3. 只输出 SQL：不要解释、不要 Markdown 代码块、不要注释、不要分号结尾。
4. 时间未指定默认最近7天（用上面的写法，不要用具体写死的日期）。
5. 若确实无法生成正确 SQL，返回 NO_VALID_SQL。

仅输出 SQL 或 NO_VALID_SQL：
```

> 模型温度建议 0.1~0.2（SQL 要确定性，别用 0.7）。模型选你 Dify 里实际已配置、能联网的（qwen-max / deepseek / moonshot 等均可，与提示词无关）。

### 4.3 权限校验（Code 节点，Python3）

入参：
- `arg1` = `{{#start.allowed_tables#}}`（逗号分隔的已授权表名）
- `arg2` = `{{#text2sql.text#}}`（Text2SQL 生成的 SQL）

```python
import re

def main(arg1: str, arg2: str):
    allowed_tables = [x.strip() for x in arg1.split(",") if x.strip()]
    sql = arg2 or ""

    # 抽取 SQL 中实际引用的表（优先完整三段式，兜底 mall_dw. 前缀）
    tables = set(re.findall(r"paimon_oss_catalog\.mall_dw\.(\w+)", sql, re.IGNORECASE))
    tables |= set(re.findall(r"mall_dw\.(\w+)", sql, re.IGNORECASE))

    unauthorized_tables = [t for t in tables if t not in allowed_tables]
    has_permission = (len(unauthorized_tables) == 0) and (len(tables) > 0)

    return {
        "tables": sorted(tables),
        "unauthorized_tables": unauthorized_tables,
        "has_permission": has_permission
    }
```

> 比原来的"信任 LLM 路由 JSON"更稳：直接校验最终 SQL 真引用的表。

### 4.4 无权限兜底（LLM 节点，接 if-else 的 false 分支）

```
你是企业数据分析助手的权限提示模块。用户的问题涉及无权限的数据表，请输出一段简洁、礼貌、专业的提示话术。

要求：
1. 明确说明当前问题涉及的数据暂无查询权限，列出无权限的表名；
2. 不暴露内部实现细节（不要提向量检索、Catalog、SQL）；
3. 引导用户调整为已授权表范围内的问题，或联系管理员开通权限；
4. 输出简洁，仅输出最终话术，不要解释。

输入：
- 用户名：{{#start.user_name#}}
- 用户问题：{{#start.input#}}
- 无权限表：{{#code.unauthorized_tables#}}
```

### 4.5 数据分析（LLM 节点，接 HTTP 之后）

```
你是企业经营分析助手。基于用户问题和查询结果，输出简洁、专业的分析。

要求：
1. 用 Markdown 输出；先直接回答问题。
2. 核心数据优先用 Markdown 表格展示，最多展示前 5 条。
3. 给出 2-3 条关键发现（趋势说走势、排行说头部、对比说差异）。
4. 结果为空时输出"当前查询条件下暂无数据"。
5. 不得编造数据，不要原样输出完整 JSON。

输入：
- 用户问题：{{#start.input#}}
- 查询结果：{{#http_request.body#}}
```

### 4.6 数据可视化（LLM 节点，接 HTTP 之后，与 4.5 并行）

```
你是数据可视化助手。基于用户问题和查询结果，输出前端可直接渲染的 ECharts option（合法 JSON）。

要求：
1. 仅输出 ECharts option 的 JSON，不要解释文字。
2. 趋势用 line，排行/对比用 bar，占比用 pie。
3. 必须基于查询结果生成，不得编造。
4. 结果为空时返回 null。

输入：
- 用户问题：{{#start.input#}}
- 查询结果：{{#http_request.body#}}
```

---

## 5. 关键修正清单（对照原 yml）

| 项 | 原来 | 现在 |
|---|---|---|
| Catalog 名 | `paimon_catalog1.mall_dw` | `paimon_oss_catalog.mall_dw`（yml 已改 3 处） |
| Schema 来源 | 静态硬编码 7 表 DDL | 向量检索动态召回（知识检索 `result` → Text2SQL「上下文变量」） |
| 数据路由 | LLM 节点选表 | 删除，由检索召回替代 |
| 权限校验 | 信任 LLM 的 candidate_tables | 解析最终 SQL 实际引用表 |
| SQL 温度 | 0.7 | 0.1~0.2 |
| HTTP 取数 | `{{#text2sql.text#}}`（跳过审核） | 直接用 Text2SQL 输出即可（RAG 已收敛） |

> 注：原 yml 的 HTTP 请求体直接取 Text2SQL 输出是合理的（RAG 已把 Schema 收敛到召回范围，SQL 审核节点可省略）。若你要保留审核节点，让 HTTP body 取审核节点的 `fixed_sql`。
