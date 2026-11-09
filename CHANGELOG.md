# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。
`VERSION` 文件与本节最新版本号必须一致（由 `scripts/check_docs.py` 强制）。

## [0.7.0] - 2026-11-09

### Added

- `scripts/upgrade_skill.sh`：按上游 HEAD 升级单个 skill。默认只预览（列出变化文件 + diff 前 60 行），
  `--apply` 才写入，并自动回写 `upstreams.json` 的 pin、重算 `manifest.tsv`。
  `--source` 可指向本地目录/其它 git URL，因此测试完全离线。
- `upstreams.json` 增加 `path_template` / `path_overrides`：解决「本地 skill 名 ≠ 上游目录名」
  （如 `vercel-react-best-practices` → `skills/react-best-practices`）。
- `make upgrade SKILL=<name>` 入口；记忆里补上用法。

### Fixed

- 升级器先克隆再检查工作区，导致脏树白跑一次网络；改为 `--apply` 在克隆前快速失败。
- 测试断言原本 grep diff 的新增行，但整文件替换时新增行在 60 行预览之外；改断言 hunk 头 `@@`。

## [0.6.0] - 2026-11-09

### Added

- `skills/upstreams.json`：9 个上游 / 42 个 skill 的机器可读来源表（repo、pin 的 commit、
  许可证、快照文件名、覆盖的 skill 列表），与 `SOURCES.md` 互为human/机器版本。
- `scripts/check_upstream.py`：离线校验覆盖度与许可声明；`--online` 复核 pin 是否仍存在、
  上游新增多少 commit、许可证是否变更（变更即失败）。
- `make upstream`：季度复核入口。verify 新增第 20 项（离线结构校验）。

### Fixed

- 在线检查最初把「gh 未认证」误报成「上游 commit 不存在」——典型的假阴性。
  现在先查 `gh auth status`，未认证时明确跳过，并自动发现同级的 `.tools/ghconfig`。

## [0.5.0] - 2026-11-09

### Added

- `scripts/purge_history.sh`：清除悬空历史。`--check` 只列出「仍可按 SHA 访问」的旧 commit，
  `--yes-i-mean-it` 才执行「删除仓库 → 重建同名仓库 → 恢复描述/topics → 推送 → 复核」。
  执行前自动打 bundle 备份，工作区不干净直接拒绝。
- `make purge-check`：只读体检入口。

### 记录

- 真实坑：`git push --force` 后旧 commit **仍可通过 SHA 访问**（实测两个 SHA 返回 200）；
  彻底清除必须删库重建或 GitHub Support 清理。
- 第二个坑：默认 OAuth token 没有 `delete_repo` scope，`gh repo delete` 需要先
  `gh auth refresh -h github.com -s delete_repo`。

## [0.4.1] - 2026-11-09

### 安全

- **脱敏**：公开仓库里的私人邮箱与另一个空账号名全部替换为描述性表述；
  历史中 8 个 commit 的作者/提交者身份改写为 GitHub noreply 地址并重建历史。
- `scripts/check_privacy.py`：新增脱敏门禁——个人邮箱、家目录真名路径、IPv4、凭证文件名；
  跳过 `skills/`（第三方），支持 `.privacy-denylist`（本机真名/内网域名，不入库）与 `--history`。
- `verify.sh` 第 19 项接入脱敏检查；CI 的 secret-scan job 用 `--history` 扫全部提交。
- `install.sh --no-skills`：只更新记忆/规范/MCP，不动 skills（保留软链布局）。

## [0.4.0] - 2026-11-09

### Added

- `scripts/doctor.sh`：环境体检（只读，支持 `--json`）——安装完整性、断链、MCP command 可执行性、
  codegraph 版本与遥测、python/gh 可用性。缺可选工具只记 WARN，不误判失败。
- `scripts/check_license.py`：LICENSE 必须**逐行等于 MIT 标准文本**（只允许版权行与空行不同）。
  不靠行数/CJK 之类启发式——版权行本来就可能含中文名。`--github owner/repo` 还能核对
  GitHub 侧的 `spdx_id`，把「识别成 NOASSERTION」挡在推送前。
- `licenses/`：9 个上游的许可快照（7 份原文 + 2 份无 LICENSE 文件的授权说明），
  合规不再依赖上游仓库还活着；`licenses/README.md` 给出映射表与复核命令。
- `scripts/merge_agents.py`：安装 AGENTS.md 时**合并而非覆盖**，本机追加内容收进
  「## 本机追加（安装器保留）」段，重复安装不叠加。

### Fixed

- `skills/LICENSES/` 被当成第 43 个 skill（`skills/` 下只该有 skill）——移到仓库根 `licenses/`。
- `doctor.sh` 新增的 `$DSH_HOME（` 触发 locale 风险写法，回归门禁当场抓到并修正。
- 安装器会静默覆盖 `~/.dsh/AGENTS.md` 里的本机内容（真实风险：服务器地址、内网路径）。

## [0.3.0] - 2026-11-09

### Added

- `memory/github.md` + `~/.dsh/github-usage.md`：GitHub 使用记忆（账号归属、单分支/不开 PR、
  提交格式、推送凭据、CI 约定、许可证坑、季度复核清单），常驻摘要进 `AGENTS.md` 第 8 条。
- `install.sh` 安装该记忆并备份旧版；`verify.sh` 比对一致性；`tests/run.sh` 增至 37 项。

### Fixed

- `LICENSE` 混入了中文说明，导致 GitHub 把仓库识别成 `NOASSERTION`；改为纯 MIT 原文，
  范围说明移到 `THIRD-PARTY-NOTICES.md` 与 README。

## [0.2.0] - 2026-11-09

### Added

- `tests/run.sh`：22 项集成测试，在临时 `DSH_HOME` 中真跑安装/校验/导出，
  覆盖幂等、dry-run、覆盖前备份、漂移检测、密钥扫描、反向导出、含空格路径。
- `scripts/dir_digest.py` + `skills/manifest.tsv` 新增 `digest` 列：每个 skill 的内容指纹，
  用于「仓库 vs 锁文件 vs 本机安装」三方一致性校验。
- `scripts/check_manifest.py`：锁文件校验（未登记/已失效/摘要不符/未分组）。
- `scripts/check_docs.py`：文档防漂移——README 的 skill 数量、每个 skill 名、
  规范行数、相对链接、`VERSION` 与 `CHANGELOG` 必须与仓库现实一致。
- `.github/workflows/ci.yml`：ubuntu + macos 双平台跑测试；shellcheck；ruff(E9,F)；gitleaks。
- `LICENSE`（MIT，仅覆盖原创部分）、`THIRD-PARTY-NOTICES.md`（Apache-2.0 变更声明）、
  `VERSION`、`CHANGELOG.md`、`Makefile`、`.githooks/pre-commit`。

### Changed

- `scripts/verify.sh`：改用锁文件摘要校验，新增 `--require-install`；
  未安装时降级为 SKIP 而非 FAIL，可直接用于「只查仓库」的场景。
- `scripts/install.sh`：增加 `~/.dsh` 可写性与锁文件存在性检查。
- `scripts/make-manifest.py`：输出 digest，未分组 skill 直接报错退出。

### Fixed

- `verify.sh` 早期版本用 `find -exec test` 判断 `SKILL.md`，会把 skill 内的子目录误判为缺失。
- `verify.sh` 用 `find -type d` 统计已安装 skill，漏算软链安装（本机 42 个只数到 32 个）。
- **locale 敏感**：`$var（` 这类写法在 macOS runner 的 C locale 下会把全角括号吞进变量名，
  报 `unbound variable`。统一改为 `${var}`，并加仓库级检查防止回潮。

## [0.1.0] - 2026-11-09

### Added

- 从本机 `~/.dsh` 导出 42 个 Agent Skill（含 10 个原本为软链的外部插件 skill），
  逐个目录自包含。
- `standards/backend-standards.md`：Java/Go 后端规范 v1.0（213 行，11 节）。
- `AGENTS.md`（可移植路径）+ `memory/codegraph.md` + `memory/preferences.md`。
- `mcp/codegraph.cordis.patch.yml`：CodeGraph MCP 的 Cordis patch。
- `scripts/install.sh`、`scripts/verify.sh`、`scripts/export-from-local.sh`。
- `skills/SOURCES.md`：上游仓库、固定 commit、本地适配说明。
