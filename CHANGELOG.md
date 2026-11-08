# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。
`VERSION` 文件与本节最新版本号必须一致（由 `scripts/check_docs.py` 强制）。

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
