# 第三方组件声明（THIRD-PARTY NOTICES）

本仓库的 `skills/` 目录是**上游开源项目的整目录副本**，版权归各上游作者所有。
本文件记录来源、许可与本地改动，用于满足 MIT / Apache-2.0 的署名与「变更声明」义务。

- 逐 skill 的来源与固定 commit：见 [`skills/SOURCES.md`](skills/SOURCES.md)
- 机器可读清单（含内容摘要）：见 [`skills/manifest.tsv`](skills/manifest.tsv)
- 本仓库原创部分（脚本、文档、规范）的许可见 [`LICENSE`](LICENSE)

## 汇总

| 上游仓库 | 许可 | 收录 skill | 文件内许可 |
|---|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | 13 | 未随目录分发（上游根目录 LICENSE） |
| [anthropics/skills](https://github.com/anthropics/skills) | **Apache-2.0** | 6 | 每个目录内 `LICENSE.txt` |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | MIT | 4 | 未随目录分发 |
| [addyosmani/web-quality-skills](https://github.com/addyosmani/web-quality-skills) | MIT | 6 | 未随目录分发 |
| [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) | MIT | 1 | 未随目录分发 |
| [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | MIT | 1 | 未随目录分发 |
| [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) | MIT | 1 | 未随目录分发 |
| [Egonex-AI/Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | MIT | 9 | 未随目录分发 |
| [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) | MIT | 1 | 未随目录分发 |

## 本地改动（Apache-2.0 §4(b) 要求的变更声明）

### Apache-2.0 组件（anthropics/skills）

- **未修改**：`claude-api`、`frontend-design`、`mcp-builder`、`skill-creator`、`webapp-testing`、`doc-coauthoring`
  按上游原样整目录复制，`LICENSE.txt` 随目录保留。本仓库未添加 NOTICE 文件，因为上游未提供。

### MIT 组件

- **obra/superpowers（13 个）**：删除了 Markdown 正文中的 `superpowers:` 命名空间前缀
  （DSH 的 skill 名是扁平的，`superpowers:tdd` 无法解析）；未收录上游的
  `using-superpowers`、`diagnosing-superpowers`（它们依赖 Claude Code 的 hook 引导）。
- **planning-with-files**：保留 frontmatter 的 `hooks:` 字段但未删除（DSH 不执行 Claude Code hook），
  文档中已标注该限制。
- **Understand-Anything（9 个）**：从插件仓库 `understand-anything-plugin/skills/` 复制 skill 层，
  **不含** `packages/core`、`dashboard` 等构建产物；上游为软链安装，本仓库改为实体副本。
- **diagram-design**：仅复制 `skills/diagram-design/`，未包含上游 `prompts/`
  （`/export-diagram` 等 Claude Code 斜杠命令）与 marketplace 清单。
- **其余 MIT 组件**：整目录原样复制，未修改。

## 依赖与商标

- 本仓库不打包任何二进制；`webapp-testing` 与 `diagram-design` 的 PNG 导出需要用户自行安装
  Python Playwright + Chromium。
- CodeGraph 是独立项目（`@colbymchenry/codegraph`），本仓库只提供接入配置，不再分发其代码。
- 各上游名称与商标归其所有者；此处引用仅用于说明来源。
