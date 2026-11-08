<!-- 由 quick-startup 维护：https://github.com/jasoncai0/quick-startup
     本机追加的笔记可以写在文件末尾；verify 只校验 CodeGraph 块、各条编号约定与规范指针。 -->

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## 后端开发规范（Java / Go，个人默认强制）

完整版：`~/.dsh/backend-standards.md`。做后端、数据访问、接口或迁移任务前先读完整版；以下是常驻红线。

1. **禁止 N+1**：循环/遍历内不得访问 DB、缓存、RPC、HTTP；关联数据用批量 `IN` / `Preload` 一次取。查询条数不得随结果行数增长（不设固定条数上限，但要可解释、稳定，PR 说明）；测试用 1 行与 N 行数据断言 SQL 条数相同。
2. **默认不 Join**：禁止 3 表及以上 Join；2 表 Join 必须同时满足：驱动表过滤后 ≤1000 行、连接列有索引且类型一致、`EXPLAIN` 无全表/临时表/filesort、列明确、有超时；跨库/分片禁 Join；不得用 Join 解 N+1。报表走数仓。
3. **业务字段不进 JSON**：仅允许只写不查的 payload、第三方原始报文、审计快照三类例外；≤16KB、带 `schemaVersion`、写入校验；禁止 JSON 路径查询、排序、唯一约束、外键。
4. **查询**：禁 `SELECT *`、禁无界查询；深分页用 keyset；过滤/排序走索引；禁左模糊、函数包列、隐式类型转换；大结果集流式处理。
5. **写入**：批量 500–1000；写接口幂等（唯一键/幂等表/token）；并发更新用乐观锁；核心数据软删除 + 审计字段。
6. **事务**：尽量短；事务内禁 HTTP/RPC/MQ/文件 IO；跨服务用 outbox + 幂等消费。
7. **缓存**：cache-aside，先写 DB 再删缓存；TTL + 穿透/击穿/雪崩防护。
8. **API**：服务端校验/鉴权/租户隔离；统一错误码；超时 + 有限重试；分页有上限；版本兼容。
9. **安全**：参数化 SQL、最小权限、密钥外置、日志脱敏、SSRF 白名单。
10. **迁移与测试**：expand-contract、online DDL、可回滚；集成测试用真实 DB 并断言 SQL 条数。

偏离以上红线需在 PR 写明：违反哪条、原因、`EXPLAIN`/压测证据、回滚方案。

## GitHub（jasoncai0）

完整版：`~/.dsh/github-usage.md`。建仓、提交、推送、发布、改 CI 前先读完整版；下面是常驻约定。

1. **账号**：个人仓库一律归 `jasoncai0`（邮箱 `you@example.com`，归属看邮箱不看 name）；`another-account` 是 0 仓库的空号，别用。
2. **分支与 PR**：只有 `main`；个人仓库不开 PR，直接 commit → push → 看 CI 结论，红了当场修。
3. **推送**：HTTPS + `GH_CONFIG_DIR=<workspace>/.tools/ghconfig` 的 gh 凭据；token 绝不写进 remote URL 或脚本。
4. **提交**：`type: 一句话` + `-` 列改动；修 bug 必须写清「哪个门禁抓到的、怎么验证」。
5. **推送前**：密钥扫描、本地测试通过、`git status` 干净；不 force push `main`、不重写已推送历史。
6. **LICENSE**：只放 MIT 原文，**不加任何说明**——加了会被 GitHub 识别成 `NOASSERTION`，说明放 `THIRD-PARTY-NOTICES.md`。
7. **发布**：只有面向用户的产品打 tag/release；工具、服务类仓库不打。
8. **不碰别人的仓**：不直接 push 非本人仓库，走 fork + PR。
