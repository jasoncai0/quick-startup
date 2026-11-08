# GitHub 使用记忆（jasoncai0）

> 版本：1.0（2026-11-09）｜安装到 `~/.dsh/github-usage.md`，`AGENTS.md` 里有常驻摘要。
> 这份文件不是通用最佳实践，是**从我自己 44 个仓库的历史里提取的习惯**，以及踩过的坑。
> 每条都尽量给出「为什么」和「怎么验证」，避免变成口号。

---

## 1. 账号与身份

| 项 | 值 |
|---|---|
| 主账号 | `jasoncai0`（`github.com/jasoncai0`），所有个人仓库归它 |
| 提交邮箱 | `you@example.com`（GitHub 已验证，`git config --global user.email` 一致） |
| 显示名 | git 全局是 `another-account`，GitHub 账号是 `jason cai`；**归属看邮箱，不看 name** |
| 另一个账号 | `another-account`：0 个仓库，**不要用**（容易搞混头像/权限） |

判断「用哪个账号」的最快方式：仓库要归谁就 `gh api user --jq .login`。

---

## 2. 本机 gh 环境（可复现，别重装）

- **没有** PATH 上的 `gh`，也**不要**用 Homebrew 装：`/opt/homebrew` 归 root，`brew install` 会失败，
  修它需要 `sudo chown -R`，不值得。
- 现役二进制：`<workspace>/.tools/gh_2.103.3_macOS_arm64/bin/gh`（官方 tarball，免 sudo）。
- 认证：OAuth device flow，token 存在 `.tools/ghconfig/hosts.yml`，scopes = `repo, read:org, gist`。
- **必须设 `GH_CONFIG_DIR`**，否则 gh 会去读 `~/.config/gh`（那里是空的）：

```bash
export GH_CONFIG_DIR="<workspace>/.tools/ghconfig"
```

- 远程是 HTTPS（本机没有 SSH key，`~/.ssh` 只有 known_hosts）。**不要**把 token 写进 remote URL，
  它会留在 `.git/config` 里。用临时 credential helper：

```bash
git -c credential.helper="!GH_CONFIG_DIR=<...>/.tools/ghconfig <...>/gh auth git-credential" push origin main
```

---

## 3. 仓库惯例（按我自己的历史）

| 维度 | 习惯 | 证据 |
|---|---|---|
| 可见性 | 工具/技能/开源默认 **public**；含个人数据或未公开业务用 **private** | private 例：`wechat-autotag`、`wxq-advisor`、`ai-codegen-rules`、`achievements-sandbox` |
| 分支 | **只用 `main`**，不建 `develop`/`release` 分支 | 抽样的 6 个仓库全是 `main` |
| PR | **个人仓库不开 PR**，直接 commit → push → 看 CI | 抽样仓库 PR 数全为 0 |
| 发布 | 只有**面向用户的产品**打 tag/release（`jypora` 8 个、`pixel-cat-pet` 1 个）；工具/服务类不打 | 0 release 的仓库占多数 |
| 许可 | MIT | 6 个抽样仓库 5 个识别为 MIT |
| CI | 有价值的项目才加 `ci.yml`；做发布再加 `release.yml` | `jypora` 两者都有 |

### 仓库最低配置

- `README.md`：中文为主，**前三行必须能看懂这是什么 + 怎么跑**（我自己不会读完长 README）。
- `.gitignore`：至少 `.DS_Store`、`__pycache__`、`.env`、密钥文件。
- `LICENSE`：MIT。
- topics：目前普遍为空；公开工具库建议补 2–4 个（`ai-agents`、`claude-code`、`skill` 之类）。

---

## 4. 许可证的坑（真实踩过）

**`LICENSE` 文件只放许可证原文，一个字都不要加。**

我在 `quick-startup` 的 MIT 原文后面追加了一段「本许可仅覆盖原创部分…」，
结果 GitHub 把它识别成 `NOASSERTION`（licensee 无法匹配），仓库页不显示 MIT 标识。

- 版权范围说明放 `THIRD-PARTY-NOTICES.md` 或 README，**不要**放 `LICENSE`。
- 验证：`make license`（本地逐行比对 MIT 原文）+ `gh api repos/<owner>/<repo> --jq .license.spdx_id` 应为 `MIT`。

> 已自动化：`scripts/check_license.py` 逐行比对 MIT 标准文本，任何追加、翻译、改字都会让 CI 变红。
> 这个检查本身也踩过坑——最初用「行数 + 是否含中文」判断，结果误伤了 `Copyright (c) 2026 蔡振盛`
> 这一行。**启发式校验会误伤自己**，能用标准文本比对就别猜。

---

## 5. 提交信息规范

格式：`type: 一句话（可带范围/版本）`

`type` 只用这几个：`feat` `fix` `docs` `chore` `ci` `refactor` `test` `perf`。

- 主题行中英文都可以，**但同一个仓库内保持一致**（`quick-startup` 用中文，`pixel-cat-pet` 用英文）。
- 正文用 `-` 列具体改动；涉及排障时写清「现象 → 根因 → 验证」。
- 单个提交只做一件事；重构与功能分开提交。
- AI 协作产生的提交保留 `Co-Authored-By: Claude <noreply@anthropic.com>`。
- 修 bug 的提交要能回答：**哪个门禁抓到的**（本地测试 / CI 哪个 job / 哪个平台）。

好的例子（来自本仓库）：

```
fix: 消除 locale 敏感的 ${var} 写法，并加回归门禁

macOS runner（bash 3.2 + C locale）会把紧跟变量的全角标点吞进变量名，
导致 "manifest_rows: unbound variable"，CI 的 macos 任务因此失败。
本地 zh_CN.UTF-8 下无法复现——这类问题只有跨 locale 才暴露。

- 11 处 `$var（` → `${var}（`
- verify.sh 新增第 10 项仓库检查
- 已用 LC_ALL=C 复跑：tests 33/33、verify 16/16
```

---

## 6. 推送前必做

1. **密钥扫描**：`grep` 规则 + CI gitleaks（全历史）。本地先扫一遍，别等 CI。
2. **本地测试/构建通过**：不要用「CI 会跑」当借口省掉本地验证。
   注意 `py_compile` 只能查语法，查不出未使用的 import——本地跑 `make lint`（含 ruff）。
3. **`git status` 干净**：没有 `.DS_Store`、`__pycache__`、临时脚本、备份目录。
4. **看 diff 规模**：一次 push 混进 3 件不相关的事，事后很难 revert。
5. 推完**必须看 CI 结论**，红了当场修，不留过夜红。

**禁止**：`git push --force` 到 `main`；重写已推送历史（除非是清理泄露的密钥，那时要配套
`git filter-repo` + 作废 token + 通知协作者）。**禁止**在别人的仓库直接 push，走 fork + PR。

---

## 7. CI 约定

```yaml
on: { push: { branches: [main] }, pull_request:, workflow_dispatch: }
permissions: { contents: read }
concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
```

- 涉及 shell 的仓库**必须**跑 `ubuntu-latest` + `macos-latest` 双平台：
  macOS 的 bash 3.2 + C locale 会暴露 locale 问题（`$var（` 被判成变量名），Linux 上永远发现不了。
- 密钥扫描单独一个 job（gitleaks），不要塞进 test job 里当附带步骤。
- 门禁脚本要能在本地一句命令复跑，CI 只是「同一个脚本换个机器跑」。

---

## 8. 常用命令

```bash
export GH_CONFIG_DIR="<workspace>/.tools/ghconfig"
GH="<workspace>/.tools/gh_2.103.3_macOS_arm64/bin/gh"

# 当前账号 / 我的仓库
$GH api user --jq .login
$GH repo list --limit 30

# 建公开仓库并推送（先本地 commit）
$GH repo create <owner>/<name> --public --description "…"
git remote add origin https://github.com/<owner>/<name>.git
git -c credential.helper="!GH_CONFIG_DIR=$GH_CONFIG_DIR $GH auth git-credential" push -u origin main

# 看 CI
$GH run list --limit 5
$GH run view <run-id> --log-failed

# 本机环境体检（只读；不对劲先跑它）
make doctor

# 发布
$GH release create v1.0.0 --title "v1.0.0" --notes-file CHANGELOG.md

# 改描述 / topics / 查许可识别
$GH repo edit --description "…" --add-topic ai-agents
$GH api repos/<owner>/<repo> --jq .license.spdx_id
```

---

## 9. 红线

- token、`~/.claude/settings.json`、`~/.dsh/.credentials.yaml`、会话记录、简历——**永不入库**。
- 不用 `gh` 的 token 去操作非本人仓库。
- 不把 public 仓库临时改 private 再改回来（会丢 star 与 fork 关系）。
- 不在公开仓库里贴内网地址、公司域名、真实用户数据。

---

## 10. 持续维护

这份记忆是**活的**：每次在新仓库踩到坑，就回来加一条，并在 `quick-startup` 里加对应检查
（例如「LICENSE 只放原文」→ 检查 `.license.spdx_id != NOASSERTION`）。

季度复核清单：

- [ ] `make doctor` 全绿（安装完整性、断链、MCP 路径）
- [ ] `gh --version` 是否有新版（二进制在 `.tools/`，替换即可）
- [ ] token scope 是否仍是最小集（`repo, read:org, gist`）
- [ ] 每个仓库的可见性是否仍合适（尤其含个人数据的）
- [ ] `gh api repos/<owner>/<repo> --jq .license.spdx_id` 是否都识别正确
- [ ] 长期没动的仓库：归档而不是删除
