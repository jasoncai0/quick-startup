# Roadmap

目标：让这个仓库**越用越准**，而不是越用越旧。每一项都要求「可验证」——要么有测试，要么有 CI 门禁。

## 当前状态

- **0.2.0**（2026-11-09）：完成测试、CI、锁文件、文档防漂移、许可证合规基线。
- **0.3.0**（2026-11-09）：GitHub 使用记忆入库并接入安装/校验（`memory/github.md`）。
- **0.4.0**（2026-11-09）：`doctor.sh` 环境体检、`check_license.py` 许可守卫、`licenses/` 上游快照、
  `merge_agents.py` 记忆合并。

## 0.5.0 — 升级与合规

- [ ] `scripts/upgrade-skill.sh <name>`：按 `skills/SOURCES.md` 里 pin 的 commit 重新拉取单个 skill，
      自动 `git diff --stat` 预览 + `make export`，避免手工 `cp -R` 出错。
- [ ] `scripts/check-upstream.py`：对每个上游仓库查询「当前 HEAD vs pinned commit」，
      输出可升级列表（只报告，不自动改），作为季度复核入口。
- [x] `licenses/`：9 个上游的许可快照（7 份原文 + 2 份授权说明）。
- [ ] `skills/manifest.tsv` 增加 `upstream`、`commit` 两列，让 SOURCES.md 的表格与锁文件同源。

## 0.5.x — 环境体检

- [x] `scripts/doctor.sh`：布局、断链、MCP 路径、codegraph/python/gh 体检。
- [ ] `doctor.sh` 增补：DSH 版本、Python Playwright/Chromium 可用性、cordis patch 是否被覆盖。
- [ ] `doctor.sh --json` 输出机器可读结果，便于以后接进 DSH 的会话启动检查。

## 0.6.0 — 跨平台

- [ ] Linux 支持：`install.sh` 在无 Homebrew 的机器上自动探测 `codegraph` 路径；
      CI 增加 `ubuntu-latest` 下的「完整安装 + verify」用例（当前只在临时目录跑）。
- [ ] 支持 `XDG` 布局（`$XDG_CONFIG_HOME/dsh`）而不只是 `~/.dsh`。

## 持续项（每次迭代都做）

- [ ] 每季度复核：上游 commit、许可证变更、DSH 是否改了 skill 目录约定。
- [ ] **GitHub 使用记忆**：每踩到一个新坑（如 `NOASSERTION`），就更新 `memory/github.md`，
      并在 `verify.sh` 或 `check_docs.py` 里加对应检查，避免同一坑踩第二次。
- [ ] 每新增一个 skill：更新 `GROUPS`、README 表格、`SOURCES.md`、`THIRD-PARTY-NOTICES.md`，
      然后 `make manifest && make all`（少一项都会被 CI 拦下）。
- [ ] 每次改 `AGENTS.md`：只改仓库版，再 `make install`；不要直接改 `~/.dsh/AGENTS.md`。

## 明确不做

- 不做成 npm 包 / CLI 工具发行版：它就是一份可 clone 的个人配置，避免多一层版本管理。
- 不自动 `codegraph init` 任何仓库：索引与否是人的决定。
- 不把 `claude-api`（105 KB）之类的大块参考资料常驻上下文，按需读。
