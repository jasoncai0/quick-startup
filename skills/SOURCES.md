# Installed coding skills & tools — sources and maintenance

Installed: 2026-11-08 (Asia/Shanghai)
Location: 仓库 `skills/` → 安装到 `~/.dsh/skills`（用户级，所有 workspace 可见）
Total: 42 skills (41 model-invocable + i-have-adhd as user-invocable only), plus the CodeGraph MCP server
Last addition: diagram-design, 2026-11-09 (Asia/Shanghai)
Machine-readable list: `manifest.tsv`（name / files / size_kb / group，由 `scripts/make-manifest.py` 生成）

## Sources (pinned commits)

| Repo | Commit | License | Skills |
|---|---|---|---|
| https://github.com/obra/superpowers | 22f0b46 | MIT | brainstorming, writing-plans, executing-plans, test-driven-development, systematic-debugging, verification-before-completion, requesting-code-review, receiving-code-review, using-git-worktrees, finishing-a-development-branch, subagent-driven-development, dispatching-parallel-agents, writing-skills |
| https://github.com/anthropics/skills | 2c5958e | see each skill's LICENSE.txt | frontend-design, webapp-testing, mcp-builder, skill-creator, claude-api, doc-coauthoring |
| https://github.com/vercel-labs/agent-skills | 1a2c79d | see repo | vercel-react-best-practices, vercel-composition-patterns, web-design-guidelines, vercel-react-view-transitions |
| https://github.com/addyosmani/web-quality-skills | afa8da9 | MIT | accessibility, best-practices, core-web-vitals, performance, seo, web-quality-audit |
| https://github.com/OthmanAdi/planning-with-files | 2362ca3 | MIT | planning-with-files |
| https://github.com/ayghri/i-have-adhd | main@2026-11-08 | MIT | i-have-adhd |
| https://github.com/multica-ai/andrej-karpathy-skills | 2c60614 | MIT | karpathy-guidelines |
| https://github.com/Egonex-AI/Understand-Anything | a6ea402 | MIT | understand, understand-chat, understand-dashboard, understand-diff, understand-domain, understand-explain, understand-figma, understand-knowledge, understand-onboard |
| https://github.com/cathrynlavery/diagram-design | e57eda6 (v2.6.142) | MIT | diagram-design |

## Local adaptations

- Superpowers: removed the `superpowers:` namespace prefix inside copied markdown so DSH's flat skill names resolve (`test-driven-development`, not `superpowers:test-driven-development`). Excluded `using-superpowers` and `diagnosing-superpowers` (bootstrap/diagnostics assume Claude Code hooks).
- planning-with-files: the `hooks:` frontmatter is kept but DSH does not execute Claude Code hooks. The on-disk planning workflow (task_plan.md / findings.md / progress.md) works manually; automatic hook injection does not.
- i-have-adhd has `disable-model-invocation: true` by design: invoke it yourself with `/i-have-adhd`; turn it off with "stop adhd mode". It will not appear in the model's skill catalog.

## Understand Anything (plugin install)

- Full plugin checkout: `~/.understand-anything/repo` (not a plain skill copy). `~/.understand-anything-plugin` symlinks to `repo/understand-anything-plugin`; each of the 9 skills is symlinked into `~/.dsh/skills/<name>`.
- Built locally: `packages/core/dist`, `plugin/dist` (skill), `packages/dashboard/dist`. Node 23.11 (Homebrew) was used so native modules match the `node` on PATH; a `pnpm` shim lives at `~/.understand-anything/bin/pnpm` (pnpm waits on stdin unless run with `< /dev/null`).
- Usage: `/understand` builds `.ua/knowledge-graph.json`; `/understand-dashboard` serves it; `/understand-chat`, `/understand-explain`, `/understand-diff`, `/understand-onboard`, `/understand-domain`, `/understand-knowledge`, `/understand-figma` build on it.
- `$ARGUMENTS` / `argument-hint` are Claude Code conventions; DSH does not substitute them. Arguments typed after the `/command` are still visible to the model, but verify the path/query when a skill runs.
- First `/understand` on a large repo can consume a lot of tokens; default later runs are incremental.

## Diagram Design (skill install)

- Canonical checkout: `~/.diagram-design/repo` (shallow clone of `main`, ~51 MB). The skill itself is `repo/skills/diagram-design/` (SKILL.md, 45 `references/type-*.md`, `assets/` examples and templates, `scripts/`), symlinked to `~/.dsh/skills/diagram-design`.
- Upstream is a multi-host plugin repo (Claude Code/Codex/Copilot marketplaces). DSH does not consume those manifests, so only the Agent Skill is installed; the `/export-diagram`, `/import-*`, `/profile`, `/doctor` prompt files in `repo/prompts/` are not wired as DSH commands.
- Verified: skill appears in DSH's catalog live, and `python3 scripts/self_check.py assets/example-architecture.html` → `OK`.
- First diagram in a workspace triggers the skill's style-guide gate (asks for brand/site URL/profile before drawing). Saved profiles live in `~/.diagram-design/profiles/`.
- Update: `git -C ~/.diagram-design/repo pull --ff-only` (the symlink picks it up; start a new session to reload). Remove: `rm ~/.dsh/skills/diagram-design` then delete `~/.diagram-design`.

## CodeGraph (MCP server + CLI)

- CLI: `@colbymchenry/codegraph` 1.6.2, installed globally (`/opt/homebrew/bin/codegraph`). It is a thin launcher around a bundled Node 24 runtime at `/opt/homebrew/lib/node_modules/@colbymchenry/codegraph/node_modules/@colbymchenry/codegraph-darwin-arm64/`.
- DSH wiring: `~/.dsh/cordis.patch.yml` (home-level Cordis patch, applies to every profile) inserts `mcp-codegraph` using `@deepseek-ai/dsh-mcp-client`; `command` is the absolute bundled launcher so it does not depend on the GUI app's PATH.
- `~/.dsh/AGENTS.md` holds the marker-fenced CodeGraph instructions block.
- Why manual: the published 1.6.2 CLI does not yet know the `dsh` target (main branch does, `src/installer/targets/dsh.ts`). The YAML above replicates that target's output. `codegraph install --target=dsh` will work once a release ships it.
- Verified end-to-end: MCP handshake + `tools/list` (`codegraph_explore`), live tool call against a demo index, `codegraph init`/`status`/`explore`.
- Telemetry is disabled persistently (`codegraph telemetry off`, stored in `~/.codegraph/telemetry.json`). Re-enable with `codegraph telemetry on`.
- Per project: `cd <project> && codegraph init` creates `.codegraph/`; thereafter the MCP tool (or `codegraph explore "<query>"`) answers structural questions. `codegraph init` is the user's decision — agents are told to skip projects without an index.
- Upgrade: `npm --cache ~/.cache/npm-codegraph install -g @colbymchenry/codegraph@latest` (the default `~/.npm` cache has root-owned files). The MCP command path stays stable across upgrades.
- Remove: delete the `mcp-codegraph` insert from `~/.dsh/cordis.patch.yml`, remove the block from `~/.dsh/AGENTS.md`, then `npm uninstall -g @colbymchenry/codegraph`.

## Dependencies

- `webapp-testing` and `diagram-design` (PNG export / `scripts/export_png.py`) need Python Playwright + a Chromium build: `pip install playwright && playwright install chromium`. On this Homebrew Python 3.13 (PEP 668) use `python3 -m pip install --user --break-system-packages playwright`.
- `vercel-*` and web-quality skills are guidance-only; Node/pnpm are only needed for the projects you build.
- `claude-api` is a large reference (105 KB SKILL.md, ~26k tokens when loaded). Delete it if you do not build with the Anthropic API.

## Update / uninstall

Reinstall one skill:

    git clone --depth 1 https://github.com/obra/superpowers /tmp/superpowers
    cp -R /tmp/superpowers/skills/test-driven-development ~/.dsh/skills/

Remove one skill:

    rm -rf ~/.dsh/skills/<skill-name>

List installed skill names:

    find ~/.dsh/skills -maxdepth 2 -name SKILL.md
