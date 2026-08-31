# Flink + Paimon + OSS + Hive Metastore + StarRocks 踩坑与学习笔记

> 目标：把「Mock → Kafka → Flink → Paimon → OSS → StarRocks」这条实时数仓链路跑通，并理解每个坑背后的原理。
> 适用版本：Flink 1.17.2、Paimon 0.8.1、StarRocks 3.2.16、Hive Metastore 4.0.0。

---

## 一、先把正确架构刻在脑子里

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────────────┐     ┌─────────────┐
│  Mock JSON  │────▶│    Kafka    │────▶│  Flink SQL / Flink DataStream │────▶│   Paimon    │
│  (订单数据)  │     │  (事件流)   │     │  实时计算 + 水位线 + checkpoint │     │  表(主键Upsert)│
└─────────────┘     └─────────────┘     └─────────────────────────────┘     └──────┬──────┘
                                                                                   │
                                                                                   ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              分布式对象存储 (warehouse)                                     │
│                     本案例: 阿里云 OSS，以 s3:// 协议访问 (S3-compatible)                     │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                   │
                                                                                   ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              Hive Metastore (HMS)                                        │
│                      持久化存储 Paimon 的【库/表元数据】                                     │
│                         (DBS / TBLS / SDS / PARTITIONS 等表)                              │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                                                                                   │
                                                                                   ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              StarRocks 外部 Catalog                                        │
│                   FE 读 Paimon 元数据，BE 读 OSS/S3 上的 ORC/Parquet 数据文件                  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### 一句话面试版
> Flink 做实时计算，Paimon 做流批统一的存储格式，OSS 做分布式文件仓库，HMS 做元数据服务，StarRocks 做 OLAP 查询。核心优势是：实时写入、历史回溯、下游多引擎共享一份数据。

---

## 二、8 个真实踩坑 + 对应知识点

### 坑 1：Flink SQL Client 一退出，`CREATE CATALOG` 就没了

#### 现象
每次 `docker exec -it flink-jobmanager ./bin/sql-client.sh` 进去，都要重新执行：

```sql
CREATE CATALOG paimon_catalog1 WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse'
);
```

退出再进，`SHOW CATALOGS` 又只剩 `default_catalog`。

#### 根因
**Flink 的 catalog 是 session 级的**，SQL Client 一关，catalog 定义就消失。

#### 学习点：catalog  vs  catalog store

| 概念 | 作用 | 持久化位置 | Flink 1.17 支持？ |
|------|------|-----------|------------------|
| **Catalog** | 把库/表元数据组织起来，让 Flink 能找到表 | 内存/session | ✅ 支持 CREATE CATALOG |
| **Catalog Store** | 把【catalog 定义本身】持久化，重启自动加载 | HMS / JDBC | ❌ 1.17 不支持，1.18+ 才有 `catalog-store.kind=hive` |

> 注意：HMS 能存 **Paimon 表/库的元数据**（表有哪些列、分区、location），但 Flink 1.17 不会把 **catalog 定义** 存进 HMS。

#### 正确做法
用 SQL Client 的 `-i` 初始化文件，每次进会话自动建 catalog。

文件 `docker/flink/init/catalogs.sql`：

```sql
CREATE CATALOG paimon_catalog1 WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse'
);
```

启动脚本 `docker/flink/flink_sql.sh`：

```bash
#!/bin/bash
# 自动判断是否是交互终端
if [ -t 0 ]; then
  docker exec -e LC_ALL=C.UTF-8 -it flink-jobmanager ./bin/sql-client.sh -i /flink-init/catalogs.sql "$@"
else
  docker exec -e LC_ALL=C.UTF-8 -i flink-jobmanager ./bin/sql-client.sh -i /flink-init/catalogs.sql "$@"
fi
```

用法：

```bash
# 交互模式
bash docker/flink/flink_sql.sh

# 执行文件
bash docker/flink/flink_sql.sh -f /flink-init/xxx.sql
```

#### 面试话术
> "Flink 1.17 的 catalog 定义是 session 级的，SQL Client 退出就丢。我们有两个选择：一是用 `-i` 初始化文件自动建 catalog；二是升级到 Flink 1.18+，启用 `catalog-store.kind=hive` 把 catalog 定义持久化到 HMS。生产里一般用后者或托管 Flink 服务。"

---

### 坑 2：Paimon 表 SELECT 没数据

#### 现象
```sql
INSERT INTO ods_douyin_order SELECT * FROM kafka_source;
-- 显示 succeed
SELECT COUNT(*) FROM ods_douyin_order;
-- 0 条
```

#### 根因
**Paimon 的数据提交依赖 Flink checkpoint**。没有 checkpoint，数据只停在内存/临时文件，不会生成 snapshot，下游读不到。

#### 学习点：Paimon 的 LSM-tree 写入流程

```
INSERT 数据
    │
    ▼
内存 MemTable / 排序缓冲
    │
    ▼
Flink checkpoint 触发 ──▶ 刷盘 ──▶ 生成 snapshot ──▶ 元数据提交
    │
    ▼
下游 (StarRocks / 另一个 Flink 任务) 读取最新 snapshot
```

Paimon 是 LSM-tree 存储，**只有 checkpoint 完成时才会 commit 一个 snapshot**。这是它实现 exactly-once 和流批一致的核心。

#### 正确做法
每次写 Paimon 的 SQL 文件开头必加：

```sql
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
```

#### 面试话术
> "Paimon 是 LSM-tree 结构，数据写入后必须等 Flink checkpoint 完成才会生成 snapshot 并提交元数据。如果不开 checkpoint，INSERT 只是流式写入的临时状态，下游读不到。生产里 checkpoint 间隔根据延迟要求设置，通常 10s~1min。"

---

### 坑 3：Docker 网络名带下划线，Java URI 报错

#### 现象
建 Paimon catalog 时加 `metastore = 'hive'`，报错：

```
java.net.URISyntaxException: Illegal character in hostname
  at index 15: thrift://hive-metastore.aidataanalysis_starrocks_ai-analysis-net:9083
```

#### 根因
Docker Compose 默认生成的网络名是 `{project}_{network}`，本例是 `aidataanalysis_starrocks_ai-analysis-net`，**里面带下划线 `_`**。

Java 的 `URI` 类严格遵守 RFC 2396/3986，**主机名只允许 `[a-zA-Z0-9.-]`**，下划线非法。Hive 客户端把 `hive-metastore` 解析成 FQDN（Fully Qualified Domain Name）时带上了下划线，URI 解析直接抛异常。

#### 学习点：URI 主机名规范

```
合法：hive-metastore、hive-metastore.example.com、192.168.1.1
非法：hive_metastore、hive-metastore.ai_analysis_net
```

#### 正确做法
在 Flink 容器的 `/etc/hosts` 里把 IP 映射成干净主机名：

```bash
# 1. 取 hive-metastore 容器 IP
HIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hive-metastore)

# 2. 写进两个 Flink 容器
docker exec flink-jobmanager sh -c "echo '$HIP hive-metastore' >> /etc/hosts"
docker exec flink-taskmanager sh -c "echo '$HIP hive-metastore' >> /etc/hosts"
```

SQL 里继续用干净名字：

```sql
CREATE CATALOG paimon_hive_file WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse',
  'metastore' = 'hive',
  'uri' = 'thrift://hive-metastore:9083'
);
```

彻底根治：把 `docker-compose.yml` 里的网络名改成不带下划线的名字，例如 `ai-analysis-network`。

#### 面试话术
> "Docker Compose 默认网络名可能带下划线，而 Java URI 不允许主机名带下划线。我们当时在 Flink 容器 `/etc/hosts` 里把 `hive-metastore` 解析到 IP，绕过这个 DNS 问题。生产里会直接给 HMS 配置一个合法的域名。"

---

### 坑 4：开了 `metastore = 'hive'`，建表报目录不存在

#### 现象
```sql
CREATE CATALOG paimon_hive_file WITH (
  'type' = 'paimon',
  'warehouse' = 'file:///paimon_warehouse',
  'metastore' = 'hive',
  'uri' = 'thrift://hive-metastore:9083'
);

CREATE TABLE demo.test_hive_file (...);
```

报错：

```
file:/paimon_warehouse/demo.db/test_hive_file is not a directory or unable to create one
```

#### 根因
**Hive Metastore 不只是存元数据，还会管理 warehouse 目录结构**。建表时 HMS 会尝试在 warehouse 路径下创建 `db.db/tbl/` 目录。但 `paimon_warehouse` 这个 Docker volume 只挂给了 Flink，**没挂给 hive-metastore 容器**，所以 HMS 在自己的文件系统里看不到 `/paimon_warehouse`。

#### 学习点：HMS 的元数据 + 目录双重职责

HMS 会维护：
- `metastore.DBS`：库名、location
- `metastore.TBLS`：表名、所属库、SD_ID
- **同时**它要求在 `warehouse` 下真实存在对应的目录结构

#### 正确做法
把 `paimon_warehouse` 卷也挂进 `hive-metastore` 服务：

```yaml
hive-metastore:
  volumes:
    - paimon_warehouse:/paimon_warehouse
    - ./docker/hive/lib/mysql-connector-j.jar:/opt/hive/lib/mysql-connector-j.jar:ro
```

#### 面试话术
> "启用 Paimon 的 Hive metastore 后，HMS 会负责在 warehouse 路径下创建库/表目录。所以 HMS 进程必须有 warehouse 目录的访问权限，生产里 Flink 和 HMS 共享同一个 HDFS/OSS 仓库。"

---

### 坑 5：写 OSS 报错 `No FileSystem for scheme "oss"`

#### 现象
```sql
CREATE CATALOG paimon_oss WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://bucket/paimon/warehouse',
  'fs.oss.impl' = 'org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = 'xxx',
  'fs.oss.accessKeySecret' = 'xxx'
);
```

报错：

```
No FileSystem for scheme "oss"
ClassNotFoundException: org.apache.hadoop.fs.aliyun.oss.AliyunOSSFileSystem
```

#### 根因
**混淆了 Paimon 的 FileIO 与 Hadoop 的 FileSystem。**

- Paimon 0.8 自己有一个 **FileIO SPI**，不同存储后端对应不同 loader jar：
  - `paimon-oss-0.8.1.jar` → 处理 `oss://`
  - `paimon-s3-0.8.1.jar` → 处理 `s3://`
  - `paimon-hdfs-0.8.1.jar` → 处理 `hdfs://`
- 这些 loader 通过 `META-INF/services/org.apache.paimon.fs.FileIOLoader` 自动发现。
- **Paimon 0.8 的 OSS loader 不依赖 Hadoop 的 `AliyunOSSFileSystem`**，所以不需要也不应该写 `fs.oss.impl`。

#### 学习点：Paimon FileIO SPI

```
oss://bucket/path
   │
   ▼
Paimon 根据 scheme 找 FileIOLoader
   │
   ▼
paimon-oss jar 里的 OSSLoader 接管
   │
   ▼
调用阿里云 OSS SDK 读写
```

#### 正确做法（Paimon 原生 OSS）

```sql
CREATE CATALOG paimon_oss WITH (
  'type' = 'paimon',
  'warehouse' = 'oss://bucket/paimon/warehouse',
  'fs.oss.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  'fs.oss.accessKeyId' = 'xxx',
  'fs.oss.accessKeySecret' = 'xxx'
);
```

注意：**不要写 `fs.oss.impl`**。

#### 面试话术
> "Paimon 0.8 自带 OSS FileIO loader，通过 SPI 机制根据 scheme 自动选择实现，不依赖 Hadoop 的 AliyunOSSFileSystem。我们一开始错配了 `fs.oss.impl`，指向了一个不存在的 Hadoop 类，导致 FileSystem 找不到。"

---

### 坑 6：StarRocks 读 `oss://` 表，数据文件 404

#### 现象
Flink 写 OSS 成功（Flink 自己能读回），但 StarRocks 查询报：

```
The specified bucket does not exist
BE access S3 file failed
```

#### 根因
StarRocks 3.2.16 的 BE 对 `oss://` 走的是 **S3-compatible 客户端**。当 endpoint 不是标准 AWS S3 时，它默认/强制使用 **path-style 访问**（`http://oss-cn-shanghai.aliyuncs.com/bucket/object`），而阿里云 OSS 要求 **virtual-hosted 访问**（`http://bucket.oss-cn-shanghai.aliyuncs.com/object`），于是 OSS 返回 `SecondLevelDomainForbidden`。

更坑的是：StarRocks 3.2 BE **不认 `aws.s3.enable_path_style_access=false`**，所以调也没用。

#### 学习点：对象存储的两种访问风格

| 风格 | URL 形式 | OSS 支持？ |
|------|---------|-----------|
| **Virtual-hosted** | `https://bucket.endpoint/object` | ✅ OSS 主推 |
| **Path-style** | `https://endpoint/bucket/object` | ⚠️ OSS 已废弃/默认拒绝 |

#### 正确做法
**把 OSS 当作 S3-compatible 存储，warehouse 用 `s3://` 协议**：

Flink 侧：

```sql
CREATE CATALOG paimon_s3_oss WITH (
  'type' = 'paimon',
  'warehouse' = 's3://bucket/paimon/warehouse',
  's3.endpoint' = 'oss-cn-shanghai.aliyuncs.com',
  's3.access-key' = 'xxx',
  's3.secret-key' = 'xxx'
);
```

StarRocks 侧：

```sql
CREATE EXTERNAL CATALOG paimon_oss_catalog
PROPERTIES (
  "type" = "paimon",
  "paimon.catalog.type" = "filesystem",
  "paimon.catalog.warehouse" = "s3://bucket/paimon/warehouse",
  "paimon.option.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
  "paimon.option.s3.access-key" = "xxx",
  "paimon.option.s3.secret-key" = "xxx",
  "aws.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
  "aws.s3.access_key" = "xxx",
  "aws.s3.secret_key" = "xxx",
  "aws.s3.enable_ssl" = "true"
);
```

注意：
- `paimon.option.s3.*`：给 **FE 的 Paimon 元数据层**用，让它能读 snapshot/manifest。
- `aws.s3.*`：给 **BE 的数据读取层**用，让它能读 ORC/Parquet 数据文件。
- Flink 侧需要 `paimon-s3-0.8.1.jar`，StarRocks 3.2 已自带该 jar。

#### 面试话术
> "StarRocks 3.2 BE 对自定义 OSS endpoint 默认走 path-style，但 OSS 要求 virtual-hosted，导致数据文件 404。我们的解法是把 OSS 当作 S3-compatible 存储，warehouse 协议从 `oss://` 改成 `s3://`，Flink 加 paimon-s3 jar，StarRocks 用 `aws.s3.*` 顶层属性访问，最终打通。"

---

### 坑 7：Flink 写入成功，StarRocks 元数据能读但数据读不到

#### 现象
StarRocks `SHOW DATABASES FROM catalog` 能看到库，`SELECT` 能定位到 ORC 路径，但读 ORC 时 404。

#### 根因
**StarRocks 外部 catalog 的 property 要分两层给**：

| 层 | 负责什么 | 需要的属性前缀 |
|----|---------|--------------|
| **FE（Paimon 元数据层）** | 解析 snapshot、manifest、schema | `paimon.option.s3.*` / `paimon.option.fs.oss.*` |
| **BE（数据读取层）** | 读 ORC/Parquet 数据文件 | `aws.s3.*` |

只给 `paimon.option.*`，BE 没有 S3 客户端配置，会用默认 AWS endpoint 查 bucket → 404。  
只给 `aws.s3.*`，FE 的 Paimon 解析器不认识 `s3://` scheme → `UnsupportedScheme`。

#### 正确做法
**两层属性都给**：

```sql
"paimon.option.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
"paimon.option.s3.access-key" = "xxx",
"paimon.option.s3.secret-key" = "xxx",
"aws.s3.endpoint" = "oss-cn-shanghai.aliyuncs.com",
"aws.s3.access_key" = "xxx",
"aws.s3.secret_key" = "xxx"
```

#### 面试话术
> "StarRocks 读 Paimon 时分两层：FE 负责解析 Paimon 元数据，需要 `paimon.option.*`；BE 负责读底层 ORC/Parquet 文件，需要 `aws.s3.*`。两边都要配对，否则要么元数据层不认 scheme，要么数据层访问不到 bucket。"

---

### 坑 8：Flink 重启后 `/etc/hosts` 映射丢了

#### 现象
重启 Flink 容器后，原来写进去的 `172.18.0.7 hive-metastore` 没了，`CREATE CATALOG ... metastore='hive'` 又报 URI 非法字符。

#### 根因
`/etc/hosts` 是容器内临时文件，容器重建就重置。

#### 学习点：Docker 容器无状态

容器应该被设计成无状态的，配置/映射应该通过：
- Docker Compose 的 `extra_hosts`
- 自定义 DNS
- 给网络起合法名字

#### 正确做法
方案 A（临时）：每次重启后重新执行：

```bash
HIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' hive-metastore)
docker exec flink-jobmanager sh -c "echo '$HIP hive-metastore' >> /etc/hosts"
docker exec flink-taskmanager sh -c "echo '$HIP hive-metastore' >> /etc/hosts"
```

方案 B（根治）：在 `docker-compose.yml` 里给网络显式命名：

```yaml
networks:
  ai-analysis-net:
    name: ai-analysis-network   # 不含下划线
```

然后 Flink 里直接用 `thrift://hive-metastore:9083`。

#### 面试话术
> "Docker 容器是无状态的，/etc/hosts 每次重启会重置。生产里不会依赖容器内 hosts，而是用合法的 DNS 名或 K8s service。我们本地 demo 用 extra_hosts 或显式网络名解决。"

---

## 三、你需要系统补的知识清单

### 1. Paimon 核心原理（必会）

| 知识点 | 必须理解到什么程度 | 一句话 |
|--------|------------------|--------|
| LSM-tree | 知道写入流程：memtable → flush → compaction | Paimon 增量写入，读时合并 |
| Snapshot | 知道每次 checkpoint 生成一个 snapshot | 流批一致靠 snapshot |
| Primary Key | 知道 `PRIMARY KEY NOT ENFORCED` 的含义 | Paimon 按主键 upsert |
| Bucket | 知道 `bucket = N` 决定并行度和文件组织 | 桶数影响并发和查询 |
| FileIO SPI | 知道 Paimon 根据 scheme 选 loader | `oss://` 走 paimon-oss，`s3://` 走 paimon-s3 |
| Metastore | 知道 `metastore = 'hive'` 让 HMS 存表元数据 | 多引擎共享元数据 |

### 2. Flink Checkpoint（必会）

| 知识点 | 面试重点 |
|--------|---------|
| barrier | checkpoint 协调器注入的屏障 |
| aligned vs unaligned | 对齐 checkpoint 延迟高但稳，非对齐用于高反压 |
| EXACTLY_ONCE | Paimon 数据不丢不重复 |
| state backend | 本地 demo 用 Memory/FS，生产用 RocksDB |
| checkpoint interval | 越小延迟越低，但开销越大 |

### 3. Hive Metastore（校招够用的深度）

| 表 | 作用 |
|----|------|
| `DBS` | 存数据库/库名/location |
| `TBLS` | 存表名/类型/所属库/SD_ID |
| `SDS` | 存存储格式、location、input/output format |
| `COLUMNS_V2` | 存列信息 |
| `PARTITIONS` | 存分区信息 |

要知道 HMS 通过 **Thrift 协议** 对外服务（端口 9083）。

### 4. 对象存储协议（面试加分项）

| 概念 | 要点 |
|------|------|
| OSS 原生协议 | `oss://bucket/object`，阿里云 SDK |
| S3-compatible | `s3://bucket/object`，用 AWS S3 协议访问 OSS |
| virtual-hosted | `bucket.endpoint` 形式，OSS 推荐 |
| path-style | `endpoint/bucket` 形式，已逐步废弃 |
| endpoint / region / bucket | endpoint 是入口域名，bucket 是桶名 |

### 5. StarRocks 外部 Catalog 架构

```
用户 SQL
   │
   ▼
FE (Frontend)
   ├─ 解析 SQL
   ├─ 从 Paimon catalog 读元数据 (manifest/snapshot)
   └─ 生成分发计划给 BE
   │
   ▼
BE (Backend)
   └─ 直接读 OSS/S3 上的数据文件 (ORC/Parquet)
```

### 6. 生产级差异（面试必问）

| 维度 | 本地 demo | 生产 |
|------|----------|------|
| 存储 | 本地 file:// / 单 bucket OSS | OSS/HDFS 多 bucket、生命周期管理 |
| 元数据 | 单 HMS + MySQL | HMS HA + RDS，或 Glue/DLH 元数据 |
| 认证 | AK/SK 写死 SQL | RAM 角色 / STS 临时凭证 |
| 提交方式 | SQL Client 交互式 | `flink run -d` / Airflow / DolphinScheduler |
| 监控 | 看 UI | Prometheus + Grafana + 告警 |
| checkpoint | 本地 | 落 OSS/HDFS，RocksDB 增量 |
| jar 管理 | 手动 cp | 烤进自定义镜像 / 托管 Flink |

---

## 四、你现在可以讲清楚的一个完整故事

面试官如果问："你这个项目做了什么？"

你可以这样答：

> "我搭了一个校招级别的实时数仓 demo，链路是 Mock 订单数据 → Kafka → Flink SQL → Paimon → 阿里云 OSS → StarRocks 查询，同时用 Hive Metastore 持久化 Paimon 表元数据。
>
> 过程中我踩了几个很有代表性的坑：
> 1. Flink 1.17 的 catalog 是 session 级的，退出 SQL Client 就丢，我用 `-i` 初始化文件解决，也了解到 1.18+ 才有 catalog store 持久化到 HMS。
> 2. Paimon 必须等 checkpoint 才会提交 snapshot，不然下游读不到数据。
> 3. Docker 网络名带下划线，Java URI 拒绝这种主机名，我用 `/etc/hosts` 映射 IP 绕过。
> 4. HMS 启用后自己要在 warehouse 下建目录，所以必须把卷共享给 HMS 容器。
> 5. Paimon 0.8 的 OSS 走自己的 FileIO loader，不需要 Hadoop 的 AliyunOSSFileSystem，错配 `fs.oss.impl` 反而会 ClassNotFound。
> 6. StarRocks 3.2 BE 对 `oss://` 自定义端点走 path-style，OSS 要求 virtual-hosted，导致数据文件 404。我把 warehouse 协议改成 `s3://`，Flink 加 paimon-s3 jar，StarRocks 用 `aws.s3.*` 属性，最终端到端打通。
>
> 这个架构本身是生产级的，只是工程化封装还是 demo 级。生产里会用 RAM 角色代替 AK/SK、用调度平台 detached 提交作业、HMS 做 HA。"

---

## 五、下一条学习路径建议

按面试重要性排序：

1. **Paimon 核心概念**（snapshot、LSM-tree、bucket、primary key upsert）
2. **Flink checkpoint 原理**（barrier、对齐、RocksDB state backend）
3. **Kafka 与 Flink 整合**（consumer group、offset、exactly-once、watermark）
4. **Hive Metastore 表结构**（DBS/TBLS/SDS，Thrift 协议）
5. **对象存储协议细节**（virtual-hosted vs path-style、S3-compatible）
6. **StarRocks 查询优化**（物化视图、colocate join、外部 catalog 权限）

---

*文档生成时间：2026-07-27*  
*对应项目：AIDataAnalysis_StarRocks（商品域：影石 Insta360）*
