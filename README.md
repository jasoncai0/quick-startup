# quick-startup

[![CI](https://github.com/jasoncai0/quick-startup/actions/workflows/ci.yml/badge.svg)](https://github.com/jasoncai0/quick-startup/actions/workflows/ci.yml)

> 我的 AI 编码环境基线：**42 个 skill + 1 套后端红线 + CodeGraph 记忆块 + MCP 接线**。
> 换一台机器、换一个会话，5 分钟装回「我熟悉的状态」，并且**每次改动都有测试与 CI 兜底**。

```bash
git clone https://github.com/jasoncai0/quick-startup.git ~/quick-startup
cd ~/quick-startup && make install && make verify
```

装完重启 DSH（或新开会话），skill 清单里应能看到 42 项。全程幂等，可反复执行。

---

## 这是什么

不是 npm 包，也不是应用，而是**个人 AI 编码环境的可移植快照**，四层结构：

| 层 | 仓库位置 | 安装到 | 解决什么问题 |
|---|---|---|---|
| **记忆** | [`AGENTS.md`](AGENTS.md)、`memory/` | `~/.dsh/AGENTS.md` | 每次会话都要重复交代的背景：CodeGraph 用法、后端红线 |
| **规范** | [`standards/backend-standards.md`](standards/backend-standards.md) | `~/.dsh/backend-standards.md` | 213 行、11 节的 Java/Go 后端强制规范（N+1、Join、JSON、事务、迁移…） |
| **技能** | `skills/`（42 个） | `~/.dsh/skills/` | 可复用的任务方法论：从 TDD、系统化调试到 Web 质量审计、架构图 |
| **接线** | [`mcp/`](mcp/codegraph.cordis.patch.yml) | `~/.dsh/cordis.patch.yml` | CodeGraph MCP server，让 agent 一次调用拿到符号源码 + 调用链 |

## 目录结构

```
quick-startup/
├── AGENTS.md                      # 全局记忆（可移植版，路径用 ~/.dsh/...）
├── README.md
├── LICENSE                        # MIT，仅覆盖原创部分
├── THIRD-PARTY-NOTICES.md         # 42 个 skill 的来源 / 许可 / 本地改动声明
├── CHANGELOG.md · VERSION · ROADMAP.md
├── Makefile                       # make install|verify|test|export|lint|secret
├── standards/
│   └── backend-standards.md       # 后端规范全文（213 行）
├── memory/
│   ├── codegraph.md               # CodeGraph 记忆块 + 安装事实 + 维护命令
│   └── preferences.md             # DSH 模型/展示偏好（手工对齐，不自动覆盖）
├── mcp/
│   └── codegraph.cordis.patch.yml # CodeGraph MCP 的 Cordis patch 参考配置
├── skills/
│   ├── SOURCES.md                 # 上游仓库 + 固定 commit + 本地改动说明
│   ├── manifest.tsv               # 锁文件：name/files/size_kb/digest/group
│   └── <skill-name>/SKILL.md …
├── scripts/
│   ├── install.sh                 # 安装/更新（幂等、备份、--dry-run）
│   ├── verify.sh                  # 三层校验（仓库/安装/密钥）
│   ├── export-from-local.sh       # 反向同步：~/.dsh → 仓库
│   ├── make-manifest.py           # 生成锁文件
│   ├── dir_digest.py              # 目录内容指纹
│   ├── check_manifest.py          # 锁文件 ↔ 磁盘 ↔ 本机安装 三方一致
│   ├── check_docs.py              # README/VERSION/CHANGELOG 防漂移
│   ├── check_agents.py            # 记忆块与红线语义校验
│   └── secret-patterns.txt        # 密钥扫描规则
├── tests/run.sh                   # 33 项集成测试（临时 DSH_HOME，不碰真实环境）
├── .githooks/pre-commit           # 可选本地门禁
└── .github/workflows/ci.yml       # ubuntu + macos 双平台
```

## 质量门禁

这个仓库的可信度不靠「我跑过」，靠可复跑的检查。

| 门禁 | 命令 | 覆盖什么 |
|---|---|---|
| 集成测试 | `make test` | **33 项**：首次安装、幂等、dry-run、覆盖前备份、漂移检测、密钥扫描、反向导出、未知参数、含空格路径 |
| 三层校验 | `make verify` | **16 项**：① 仓库完整性 ② 本机安装一致性 ③ 密钥扫描 |
| 锁文件 | `python3 scripts/check_manifest.py --repo .` | 每个 skill 的内容指纹（`digest`）与锁文件一致；未登记/已失效/未分组都报错 |
| 文档防漂移 | `python3 scripts/check_docs.py .` | README 的 skill 数量、42 个名字、规范行数、相对链接、`VERSION` 与 `CHANGELOG` 必须与仓库现实一致 |
| 静态检查 | `make lint` | shellcheck（0 告警）+ Python 语法 |
| CI | push / PR | ubuntu + macos 双平台跑上面全部，外加 gitleaks 全历史扫描 |

本地全量：`make all`（= lint + test + verify）。想在提交前拦截：`git config core.hooksPath .githooks`。

**设计取舍**：锁文件里存的是「目录内容指纹」而不是 mtime/大小，所以换机器、改权限都不会误报；
而新增、删除、改名、改一个字节都会变。`verify.sh` 用它与「仓库 / 锁文件 / 本机安装」三方对齐。

## 42 个 skill

按用途分组，全部来自上游开源仓库（固定 commit，见 [`skills/SOURCES.md`](skills/SOURCES.md)，
许可与改动声明见 [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md)）：

| 组 | 数量 | skill |
|---|---|---|
| **工程流程**（superpowers） | 13 | `brainstorming` `writing-plans` `executing-plans` `test-driven-development` `systematic-debugging` `verification-before-completion` `requesting-code-review` `receiving-code-review` `using-git-worktrees` `finishing-a-development-branch` `subagent-driven-development` `dispatching-parallel-agents` `writing-skills` |
| **代码理解**（Understand Anything） | 9 | `understand` `understand-chat` `understand-dashboard` `understand-diff` `understand-domain` `understand-explain` `understand-figma` `understand-knowledge` `understand-onboard` |
| **Web 质量**（addyosmani） | 6 | `accessibility` `best-practices` `core-web-vitals` `performance` `seo` `web-quality-audit` |
| **元技能 / 文档**（anthropics，Apache-2.0） | 6 | `skill-creator` `doc-coauthoring` `mcp-builder` `claude-api` `frontend-design` `webapp-testing` |
| **前端 / React**（vercel-labs） | 4 | `vercel-react-best-practices` `vercel-composition-patterns` `vercel-react-view-transitions` `web-design-guidelines` |
| **规划与行为约束** | 3 | `planning-with-files` `i-have-adhd` `karpathy-guidelines` |
| **可视化**（diagram-design） | 1 | `diagram-design` |

两个特殊点：

- `i-have-adhd` 的 frontmatter 是 `disable-model-invocation: true`，**不会**出现在模型可见目录里，需要自己敲 `/i-have-adhd`。
- `claude-api` 的 `SKILL.md` 有 105 KB（约 26k tokens），不用 Anthropic API 就可以删。

## 安装细节

`scripts/install.sh` 做四件事，前三件可单独回退：

1. **skills** → `~/.dsh/skills/<name>/`：逐目录 `rm -rf` 后整目录复制（不做软链，避免外部 checkout 被删后断链）。
2. **AGENTS.md** → `~/.dsh/AGENTS.md`：先比对，内容不同才覆盖，旧文件备份到 `~/.dsh/backups/quick-startup-<时间戳>/`。
3. **规范** → `~/.dsh/backend-standards.md`。
4. **MCP** → 往 `~/.dsh/cordis.patch.yml` 追加 `mcp-codegraph` 段；已存在同名 id 就跳过，`codegraph` 未安装则跳过并提示。

```bash
./scripts/install.sh --dry-run           # 只打印将要做什么
DSH_HOME=/tmp/test ./scripts/install.sh  # 装到别处（沙箱试跑）
```

**注意**：`install.sh` 会把外部插件（`diagram-design`、`understand*`）从软链变成实体副本。
如果你在本机保留了「软链到上游 checkout、靠 `git pull` 更新」的布局，就不要跑 install，
只跑 `make verify`（它已能正确识别软链安装）。

## 记忆与规范怎么用

`AGENTS.md` 被 DSH 自动注入每个会话，所以只放**每条会话都值得占用上下文**的内容：

- CodeGraph 行为约定（有 `.codegraph/` 就先查图，没有就跳过，不擅自建索引）
- 后端 10 条常驻红线（全文 213 行放 `backend-standards.md`，按需读）

规范按「必须/应当 + 偏离流程」写，不是口号：每条 MUST 都有可验证形式
（例如 N+1 → 「1 行与 N 行数据断言 SQL 条数相同」），CR 清单可直接勾。

## 更新与漂移治理

日常在本机改 skill / 改规范后，反向导出：

```bash
make export                    # ~/.dsh → 仓库，并重生成 manifest.tsv
git add -A && git commit && git push
```

规则：

- **仓库是唯一真相**，本机 `~/.dsh` 是部署产物；改完记得导出，否则 `make verify` 会报不一致。
- 软链 skill 在仓库里存的是**实体拷贝**；上游更新靠 `git -C ~/.diagram-design/repo pull` 后重新导出。
- 升级单个 skill：`git clone --depth 1 <上游>` 后 `cp -R` 到 `~/.dsh/skills/`，再 `make export`。
- 改了 skill 内容却忘了更新锁文件，CI 的「锁文件必须是最新的」会直接挂。

待办与下一步见 [`ROADMAP.md`](ROADMAP.md)。

## 刻意不包含

| 排除项 | 原因 |
|---|---|
| `~/.dsh/.credentials.yaml`、API token、`~/.claude/settings.json` | 密钥绝不入公开仓库；`.gitignore` 兜底，CI 用 gitleaks 全历史扫 |
| `~/.dsh/sessions/`、`storages/` | 会话历史与工作区索引，含隐私且体积大 |
| 简历等个人文档 | 与工具链无关 |
| `understand` 插件的构建产物 | 该插件需 `pnpm` 本地构建，见 `skills/SOURCES.md`；此处只带 skill 层 |

## 已知限制

- `planning-with-files` 的 `hooks:` 是 Claude Code 约定，DSH 不执行；磁盘上的 `task_plan.md` 工作流仍可手动用。
- `understand*` 与 `diagram-design` 的 `/command` 提示词（`$ARGUMENTS` 等）是 Claude Code 约定，DSH 不做参数替换。
- CodeGraph 的 `command` 是 macOS/Homebrew 绝对路径；Linux 需改 `mcp/` 配置（`install.sh` 会优先取 `command -v codegraph`）。
- `verify.sh` 检查本机安装时假定 `~/.dsh` 是可写目录；只读环境请用 `DSH_HOME` 指向临时目录。

## 许可证

- 本仓库原创部分（脚本、测试、文档、规范、记忆）：MIT，见 [LICENSE](LICENSE)。
- `skills/` 下每个 skill 版权归上游作者：MIT 或 Apache-2.0，见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 与各目录内 `LICENSE.txt`。
