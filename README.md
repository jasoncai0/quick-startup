# quick-startup

> 我的 AI 编码环境基线：**42 个 skill + 1 套后端红线 + CodeGraph 记忆块 + MCP 接线**，
> 换一台机器、换一个会话，5 分钟装回「我熟悉的状态」。

```bash
git clone https://github.com/jasoncai0/quick-startup.git ~/quick-startup
cd ~/quick-startup && ./scripts/install.sh && ./scripts/verify.sh
```

装完重启 DSH（或新开会话），skill 清单里应能看到 42 项。全程幂等，可反复执行。

---

## 这是什么

不是一个 npm 包，也不是一个应用。它是**个人 AI 编码环境的可移植快照**，四层结构：

| 层 | 仓库位置 | 安装到 | 解决什么问题 |
|---|---|---|---|
| **记忆** | `AGENTS.md`、`memory/` | `~/.dsh/AGENTS.md` | 每次会话都要重复交代的背景：CodeGraph 用法、后端红线 |
| **规范** | `standards/backend-standards.md` | `~/.dsh/backend-standards.md` | 213 行、11 节的 Java/Go 后端强制规范（N+1、Join、JSON、事务、迁移…） |
| **技能** | `skills/`（42 个） | `~/.dsh/skills/` | 可复用的任务方法论：从 TDD、系统化调试到 Web 质量审计、架构图 |
| **接线** | `mcp/` | `~/.dsh/cordis.patch.yml` | CodeGraph MCP server，让 agent 一次调用拿到符号源码 + 调用链 |

仓库同时校验「本机装好的」和「仓库里的」是否一致，防止两边漂移。

## 目录结构

```
quick-startup/
├── AGENTS.md                      # 全局记忆（可移植版，路径用 ~/.dsh/...）
├── README.md
├── standards/
│   └── backend-standards.md       # 后端规范全文
├── memory/
│   ├── codegraph.md               # CodeGraph 记忆块 + 本机安装事实 + 维护命令
│   └── preferences.md             # DSH 模型/展示偏好（手工对齐，不自动覆盖）
├── mcp/
│   └── codegraph.cordis.patch.yml # CodeGraph MCP 的 Cordis patch 参考配置
├── skills/                        # 42 个 skill，逐个目录，自包含
│   ├── SOURCES.md                 # 上游仓库 + 固定 commit + 本地改动说明
│   ├── manifest.tsv               # 名称/文件数/体积/来源（脚本生成）
│   └── <skill-name>/SKILL.md …
└── scripts/
    ├── install.sh                 # 安装/更新（幂等，带备份，支持 --dry-run）
    ├── verify.sh                  # 校验：数量、内容一致性、密钥扫描
    └── export-from-local.sh       # 反向同步：从 ~/.dsh 导出回仓库
```

## 安装细节

`scripts/install.sh` 做四件事，每件都可单独回退：

1. **skills** → `~/.dsh/skills/<name>/`：逐目录 `rm -rf` 后整目录复制（不做软链，避免外部 checkout 被删后断链）。
2. **AGENTS.md** → `~/.dsh/AGENTS.md`：先比对，内容不同才覆盖，旧文件备份到 `~/.dsh/backups/quick-startup-<时间戳>/`。
3. **规范** → `~/.dsh/backend-standards.md`。
4. **MCP** → 往 `~/.dsh/cordis.patch.yml` 追加 `mcp-codegraph` 段；已存在同名 id 就跳过，`codegraph` 未安装则跳过并提示。

```bash
./scripts/install.sh --dry-run     # 只打印将要做什么
DSH_HOME=/tmp/test ./scripts/install.sh   # 装到别处（沙箱试跑）
```

`scripts/verify.sh` 输出 `PASS/FAIL` 计数并以退出码反映结果，可直接挂 CI：

- 仓库与已安装的 skill 数量、逐目录内容一致（`diff -rq`）
- 每个 skill 都有 `SKILL.md`
- `AGENTS.md` 含 CodeGraph 围栏标记与规范指针
- 规范文件存在且 ≥ 200 行
- 全仓密钥扫描（`gho_`/`ghp_`/`sk-`/`ANTHROPIC_AUTH_TOKEN`/私钥头）

## 42 个 skill

按用途分组，全部来自上游开源仓库（固定 commit，见 `skills/SOURCES.md`）：

| 组 | 数量 | skill |
|---|---|---|
| **工程流程**（superpowers） | 13 | `brainstorming` `writing-plans` `executing-plans` `test-driven-development` `systematic-debugging` `verification-before-completion` `requesting-code-review` `receiving-code-review` `using-git-worktrees` `finishing-a-development-branch` `subagent-driven-development` `dispatching-parallel-agents` `writing-skills` |
| **代码理解**（Understand Anything） | 9 | `understand` `understand-chat` `understand-dashboard` `understand-diff` `understand-domain` `understand-explain` `understand-figma` `understand-knowledge` `understand-onboard` |
| **Web 质量**（addyosmani） | 6 | `accessibility` `best-practices` `core-web-vitals` `performance` `seo` `web-quality-audit` |
| **元技能 / 文档**（anthropics） | 6 | `skill-creator` `doc-coauthoring` `mcp-builder` `claude-api` `frontend-design` `webapp-testing` |
| **前端 / React**（vercel-labs） | 4 | `vercel-react-best-practices` `vercel-composition-patterns` `vercel-react-view-transitions` `web-design-guidelines` |
| **规划与行为约束** | 3 | `planning-with-files` `i-have-adhd` `karpathy-guidelines` |
| **可视化**（diagram-design） | 1 | `diagram-design` |

两个特殊点：

- `i-have-adhd` 的 frontmatter 是 `disable-model-invocation: true`，**不会**出现在模型可见目录里，需要自己敲 `/i-have-adhd`。
- `claude-api` 的 `SKILL.md` 有 105 KB（约 26k tokens），不用 Anthropic API 就可以删。

## 记忆与规范怎么用

`AGENTS.md` 被 DSH 自动注入每个会话，所以只放**每条会话都值得占用上下文**的内容：

- CodeGraph 行为约定（有 `.codegraph/` 就先查图，没有就跳过，不擅自建索引）
- 后端 10 条常驻红线（全文 213 行放 `backend-standards.md`，按需读）

规范本身按「必须/应当 + 偏离流程」写，不是口号：每条 MUST 都有可验证形式
（例如 N+1 → 「1 行与 N 行数据断言 SQL 条数相同」），CR 清单可直接勾。

## 更新与漂移治理

日常在本机改 skill / 改规范后，反向导出：

```bash
./scripts/export-from-local.sh        # ~/.dsh → 仓库，并重生成 manifest.tsv
git add -A && git commit -m "sync: ..." && git push
```

规则：

- **仓库是唯一真相**，本机 `~/.dsh` 是部署产物；改完记得导出，否则 `verify.sh` 会报不一致。
- 软链 skill（`diagram-design`、`understand*`）在仓库里存的是**实体拷贝**；上游更新靠 `git -C ~/.diagram-design/repo pull` 后重新导出。
- 升级单个 skill：直接从上游 `git clone --depth 1` 后 `cp -R` 到 `~/.dsh/skills/`，再导出。

## 刻意不包含

| 排除项 | 原因 |
|---|---|
| `~/.dsh/.credentials.yaml`、API token、`~/.claude/settings.json` | 密钥绝不入公开仓库；`.gitignore` 已兜底 |
| `~/.dsh/sessions/`、`storages/` | 会话历史与工作区索引，含隐私且体积大 |
| 简历等个人文档 | 与工具链无关 |
| `understand` 插件的构建产物重建 | 该插件需 `pnpm` 本地构建，见 `skills/SOURCES.md` 的说明；此处只带 skill 层 |

## 已知限制

- `planning-with-files` 的 `hooks:` 是 Claude Code 约定，DSH 不执行；磁盘上的 `task_plan.md` 工作流仍可手动用。
- `understand*` 与 `diagram-design` 的 `/command` 提示词文件（`$ARGUMENTS` 等）是 Claude Code 约定，DSH 不做参数替换。
- CodeGraph 的 `command` 是 macOS/Homebrew 绝对路径；Linux 或非 Homebrew 安装需改 `mcp/` 配置（`install.sh` 会优先取 `command -v codegraph`）。

## 来源与许可

所有 skill 版权归各上游仓库，许可见 `skills/SOURCES.md` 与各目录内的 LICENSE。本仓库仅做整理与可移植化。
