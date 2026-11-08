# CodeGraph 记忆块

> 这一段会被安装到 `~/.dsh/AGENTS.md` 顶部（标记围栏 `CODEGRAPH_START/END` 之间）。
> 同时同步到 `~/.claude/CLAUDE.md`（如果你也用 Claude Code）。

## 行为约定

在**有 `.codegraph/` 索引的仓库**里，先 CodeGraph 再 grep/find/读文件：

- 有问题优先 `codegraph_explore`（MCP 工具）：一次返回相关符号的原文 + 调用路径 + 影响面；
  查询里带上文件名或符号名，就能读到它当前带行号的源码。
- 没有 MCP 时用 shell：`codegraph explore "<符号名或问题>"`。
- **没有 `.codegraph/` 的仓库直接跳过**——是否建索引由人决定，不要自行 `codegraph init`。

## 本机安装事实（2026-11-08）

| 项 | 值 |
|---|---|
| CLI | `@colbymchenry/codegraph` 1.6.2，全局安装在 `/opt/homebrew/bin/codegraph` |
| 实现 | 薄启动器 + 内置 Node 24 运行时 |
| DSH 接线 | `~/.dsh/cordis.patch.yml` 插入 `mcp-codegraph`（`@deepseek-ai/dsh-mcp-client`） |
| 遥测 | 已关闭（`~/.codegraph/telemetry.json`，`codegraph telemetry on` 可恢复） |
| 版本坑 | 1.6.2 的 `codegraph install --target=dsh` 还不存在，故手写 patch；上游 main 已支持 |

## 常用命令

```bash
cd <repo> && codegraph init       # 建 .codegraph/（人工决定，别自动跑）
codegraph status                  # 看索引状态
codegraph explore "OrderService createOrder"   # 无 MCP 时的等价查询
```

## 维护

```bash
# 升级（默认 ~/.npm 缓存有 root 文件，换一个 cache 目录）
npm --cache ~/.cache/npm-codegraph install -g @colbymchenry/codegraph@latest

# 卸载
npm uninstall -g @colbymchenry/codegraph
# 再删 ~/.dsh/cordis.patch.yml 里的 mcp-codegraph 段与 AGENTS.md 里的记忆块
```
