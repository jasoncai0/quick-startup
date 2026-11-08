# 后端开发规范（Java / Go）

版本：1.0（2026-11-09）
适用：所有后端服务、数据访问、接口与迁移代码。
标记：**MUST** = 必须；**SHOULD** = 默认遵守，偏离需在 PR 说明理由与证据。
原则：规范服务于正确性和可维护性，不是教条；任何偏离都要留下「原因 + 证据 + 回滚方案」。

---

## 1. 数据访问

### 1.1 禁止 N+1（最高优先级）

- **MUST**：循环、遍历、`map/forEach/stream` 内不得访问 DB、缓存、RPC、HTTP。
- **MUST**：查询次数不得随结果行数增长（O(1)，不是 O(N)）。**不设固定条数上限**；但每个请求的查询数必须可解释、稳定，新增查询要在 PR 说明。
- 关联数据一次批量取：`WHERE id IN (...)`、ORM 预加载、`pgx.Batch`、`sqlx.In`；禁止逐条查询。
- `IN` 列表分片，单片默认 ≤ 1000，避免超长 SQL 与执行计划退化。
- **MUST**：关闭 ORM 懒加载；需要关联时显式预加载（Java：`@EntityGraph` / `@BatchSize` / MyBatis 批量；Go：GORM `Preload` / 手写批量）。
- 独立且无依赖的查询可以并行，但必须有并发上限与超时，不能演变成无界并发。
- **MUST**：数据访问测试断言「查询条数恒定」：同一接口用 1 行与 100 行数据各跑一次，SQL 条数必须相同；不是断言「≤5 条」。
- 监控：按接口统计 SQL 条数 P95；条数随数据量上升即视为回归。
- 代码评审红线：`for` / `map` 内出现 `repository` / `db` / `query` / `feign` / `http` / `client` 调用。

### 1.2 Join：默认不 Join

- **SHOULD**：核心链路默认「单表查询 + 应用层批量组装」，不用 Join 做业务拼装。
- **MUST**：禁止 3 表及以上 Join；禁止大结果集 Join 后再排序/聚合。
- **MUST**：跨库、分库分表场景禁止 Join；用冗余字段、离线宽表或应用层组装。
- **允许 2 表 Join 的条件（全部满足）**：
  1. 驱动表过滤后行数有上限（默认 ≤ 1000，按实际压测调整）；
  2. 连接列有索引，且两边数据类型完全一致；
  3. `EXPLAIN` 无全表扫描、无临时表、无 filesort；
  4. 返回列明确，禁止 `SELECT *`；
  5. 有查询超时与结果行数上限；
  6. PR 附 `EXPLAIN` 结果。
- **禁止**用 Join 解决 N+1；N+1 用批量 `IN` / 预加载。
- 报表、OLAP、多维聚合走数仓或离线宽表，不在 OLTP 主库跑大 Join。
- 如果一次 2 表小 Join 明显优于 3 次往返，允许作为例外，但必须满足上述条件并记录理由。

### 1.3 JSON：业务字段不进 JSON

- **MUST**：需要查询、排序、聚合、唯一约束、外键关联的业务字段，禁止存 JSON；必须建独立列或子表。
- **允许的 JSON 例外（仅三类）**：
  1. 只写不查的 payload（如第三方回调原文）；
  2. 第三方原始报文（排障用，不参与业务逻辑）；
  3. 审计快照 / 扩展元数据（不参与查询与约束）。
- 例外字段必须满足：
  - 大小上限默认 16 KB，超限拒绝写入；
  - 带 `schemaVersion`，写入时做 schema 校验；
  - 读时容忍缺字段，新增字段向后兼容；
  - **不得**作为查询条件、排序键、唯一约束、外键。
- **MUST**：禁止在 JSON 字段上做业务查询（`JSON_EXTRACT` / `->>` / `jsonb_path_query` 等）。确需查询时走评审：改成生成列/表达式索引，且只读。
- Java/Go 的 JSON TypeHandler（Jackson / `datatypes.JSON`）只允许用在已批准的例外列上，禁止默认开启。

### 1.4 查询

- **MUST**：禁止 `SELECT *`，明确列。
- **MUST**：所有查询有界：分页或 `LIMIT`；禁止无上限列表与全表扫描；导出走异步任务。
- 深分页用 keyset（`WHERE id > ? ORDER BY id LIMIT ?`）；禁止大 `OFFSET`，或使用延迟关联/子查询优化。
- **MUST**：过滤/排序列必须有可用索引；禁止前导 `%like`、函数包列、隐式类型转换、`OR` 拆散索引。
- 联合索引遵循最左前缀；等值列在前、范围列在后；优先覆盖索引，减少回表。
- 只读查询走只读库；大结果集流式处理，不一次性加载内存。
- 预计扫描/返回超过 1 万行的查询，PR 必须附 `EXPLAIN` 与压测数据。

### 1.5 写入

- **MUST**：批量插入/更新（batch 默认 500–1000），禁止循环单条写。
- **MUST**：写接口幂等：唯一键、幂等表或幂等 token；重试安全。
- 并发更新用乐观锁（`version`）或条件更新（`WHERE version = ?`），禁止读-改-写裸奔。
- 核心数据禁止物理删除；软删除 + 归档；软删除与唯一索引冲突时让 `deleted_at` 参与唯一键或使用归档表。
- 审计字段：`created_at` / `updated_at` / `created_by` / `updated_by` / `deleted_at`；时间统一 UTC。

### 1.6 表设计

- 主键用趋势递增 `BIGINT` 或 UUIDv7；金额用 `DECIMAL`，禁止 `FLOAT/DOUBLE`。
- 字符集 `utf8mb4`；枚举用 `TINYINT` + 字典/常量，禁止魔法字符串。
- 默认不建物理外键与级联删除，应用层保证一致性。
- 大字段（TEXT/BLOB）独立表，避免拖累主表索引。
- 字段尽量 `NOT NULL` + 默认值；索引命名 `idx_` / `uk_`。

---

## 2. 事务与一致性

- **MUST**：事务尽量短；事务内禁止 HTTP/RPC/MQ 发送/文件 IO。
- 锁顺序统一（按主键排序）；设置锁等待超时；避免间隙锁扩大。
- 跨服务一致性用「本地事务 + outbox + 幂等消费」，禁止分布式事务（强一致刚需除外）。
- 消息消费必须幂等：唯一键/去重表；至少一次投递 + 幂等处理。
- 缓存一致性：cache-aside，**先写 DB 再删缓存**；禁止先删缓存后写 DB；延迟双删只作兜底。
- 缓存三防：穿透（空值缓存/布隆）、击穿（互斥重建）、雪崩（TTL 抖动）；热 key/大 key 治理；缓存必须有 TTL 与降级。

---

## 3. API 设计

- 统一响应 `{code, message, data, traceId}`；错误码分段、可检索；禁止把堆栈返回客户端。
- 入参校验（类型/长度/范围/枚举/必填）在服务端；客户端校验只是体验。
- 鉴权与越权校验在服务端；**禁止信任客户端传来的 `tenantId` / `userId` / 角色**。
- 写接口幂等；只对幂等操作重试。
- 连接/读/写超时必设；重试有上限 + 退避 + 抖动；禁止无界重试。
- 限流、熔断、降级、背压；`429` 带 `Retry-After`。
- 分页参数上限（`pageSize` ≤ 100/200）；响应体大小上限。
- 版本兼容：新增字段不破坏旧客户端；禁止删除字段或改语义；废弃字段先标注再下线。

---

## 4. 安全（OWASP ASVS L2 基线）

- **MUST**：SQL 参数化/预编译；禁止字符串拼接 SQL。
- DB 账号最小权限；生产禁止 DDL/超管账号跑业务。
- 密钥/凭证走环境变量或密钥管理；禁止入库、入代码、入日志。
- 日志脱敏：密码、token、完整手机号/身份证/银行卡禁止打印。
- 防 SSRF：外部 URL 白名单，禁止访问内网与云元数据地址。
- 文件上传：类型/大小/内容校验，存储隔离，禁止直接落 Web 根目录。
- 依赖漏洞扫描；禁止引入未审计的包。

---

## 5. 可观测性与性能

- 结构化日志（JSON），必带 `traceId` / `requestId` / 脱敏用户标识 / 耗时 / 状态码。
- 指标：QPS、P99、错误率、慢查询、连接池、队列积压、每接口 SQL 条数。
- 慢查询阈值默认 100 ms；上线前对新增/变更 SQL 做 `EXPLAIN` 审查。
- 接口性能预算：P99 目标、DB 查询数、返回行数、响应大小四项写进设计。
- 跨服务透传 trace；关键链路有埋点与告警。

---

## 6. 数据库变更

- 迁移脚本版本化、可重复执行；禁止手工改生产表结构。
- 采用 expand-contract：先加列/双写 → 回填 → 切读 → 删旧列。
- 大表 DDL 用 online schema change（gh-ost / pt-osc / 原生 Online DDL），禁止锁表。
- 回填分批、可中断、可重入；迁移与代码发布解耦。
- 变更前备份，变更后验证；破坏性操作必须有回滚方案。

---

## 7. Java 落地

- **MyBatis / MyBatis-Plus**：
  - `IN` 批量用 `foreach` + 分片（≤1000），禁止在 `for` 里调 `selectOne/selectList`；
  - 批量写优先 `ExecutorType.BATCH` 或 `insertBatchSomeColumn`；
  - 分页用插件，禁止手写大 `OFFSET`；
  - 复杂 Join 必须写进 Mapper XML 并附 `EXPLAIN`，禁止在 Service 里循环拼查询。
- **JPA / Hibernate**：
  - 关联默认 `FetchType.LAZY`，禁止 `EAGER`；
  - 显式预加载用 `@EntityGraph` / `join fetch` / `@BatchSize`；
  - 开启 `hibernate.default_batch_fetch_size`（如 100），避免 N+1；
  - 禁止在 `@Transactional` 内做远程调用。
- **查询计数**：测试环境接 `datasource-proxy` 或 `p6spy`，断言接口 SQL 条数与数据量无关。
- **连接池**：HikariCP；`maximumPoolSize` 按 DB 容量压测确定；设置 `connectionTimeout` / `validationTimeout`。
- **迁移**：Flyway 或 Liquibase；大表变更走 gh-ost / pt-osc。
- **JSON**：Jackson TypeHandler 只用于批准的例外列；禁止在 JSON 列上写 `JSON_CONTAINS` 业务查询。
- **HTTP 客户端**：连接/读超时必须显式设置；重试配 Resilience4j（上限 + 退避 + 熔断）。

---

## 8. Go 落地

- **database/sql + sqlx / pgx**：
  - 批量 `IN` 用 `sqlx.In` 或 `pgx.Batch`，分片 ≤1000；
  - 禁止在 `for` 里 `QueryRow` / `Get` / `Select`；
  - 所有查询带 `context.WithTimeout`；
  - 大批量写用 `CopyFrom`（pgx）或事务内 prepared batch。
- **GORM**：
  - 关联用 `Preload`，禁止依赖懒加载；
  - 大结果集用 `FindInBatches`；
  - 禁止用 `Joins` 做 3 表以上关联；2 表 Join 需附 `EXPLAIN`；
  - 批量写用 `CreateInBatches`。
- **连接池**：设置 `SetMaxOpenConns` / `SetMaxIdleConns` / `SetConnMaxLifetime` / `SetConnMaxIdleTime`；按 DB 容量压测确定。
- **迁移**：golang-migrate 或 goose；大表变更走 online DDL 工具。
- **查询计数**：集成测试用 `sqlmock` 断言语句条数，或 pgx tracer 统计；用 Testcontainers 起真实 DB。
- **JSON**：`json.RawMessage` / `datatypes.JSON` 只用于批准的例外列；禁止 JSON 路径查询。
- **错误处理**：包装错误并保留上下文；禁止 `panic` 处理业务错误。

---

## 9. 测试

- 单测覆盖核心逻辑；集成测试使用真实 DB（Testcontainers / 本地容器），禁止用 H2 完全替代目标 DB。
- **数据访问测试必须断言 SQL 条数恒定**（1 行与 N 行结果条数相同），防 N+1 回归。
- 迁移脚本测试：up 后可启动、旧数据可读；必要时测 down。
- 服务间契约测试；关键链路压测；慢查询回归检查。

---

## 10. PR 评审清单

- [ ] 无循环内 DB/缓存/RPC 调用；查询条数与数据量无关
- [ ] 列表关联数据批量取；测试断言 SQL 条数恒定
- [ ] 无 3 表以上 Join；2 表 Join 有 `EXPLAIN` 证据与行数上限
- [ ] 无 `SELECT *`；查询有界；深分页用 keyset
- [ ] 业务字段不在 JSON；JSON 例外有大小上限与版本
- [ ] 写接口幂等；批量写；并发更新有乐观锁
- [ ] 事务短、无远程调用；缓存先 DB 后删
- [ ] 索引覆盖过滤/排序；无左模糊/函数包列
- [ ] 日志脱敏、带 traceId；错误码规范
- [ ] 迁移向前兼容、可回滚；无锁表 DDL
- [ ] 鉴权/租户隔离在服务端；SQL 参数化

---

## 11. 偏离流程

任何违反 MUST 的实现，PR 必须写清：

1. 违反哪一条、为什么必须违反；
2. `EXPLAIN` / 压测 / 查询计数证据；
3. 影响范围与回滚方案；
4. 后续偿还计划（如适用）。

没有以上四项，评审直接打回。
