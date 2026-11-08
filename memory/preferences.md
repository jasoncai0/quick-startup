# DSH 环境偏好（本机导出，2026-11-09）

> 这些是 DSH **profile 级**设置，存放在 `~/.dsh/profiles/desktop/cordis.patch.yml`。
> 与 skill / 规范不同，它们和 DSH 版本、本机路径相关，安装脚本**不会**自动覆盖你的配置；
> 换机时按需手工对齐。

## 模型与推理

| 项 | 值 |
|---|---|
| provider | `deepseek-account` |
| model | `deepseek-flash` |
| reasoningEffort | `high` |

## 会话与展示

| 项 | 值 |
|---|---|
| transcriptView | `detailed`（完整展开工具调用） |
| performanceUsage | `detailed` |
| ui-settings.version | `1` |
| purpose | `development` |
| process | `detailed` |
| completion | `completed` |
| usage | `detailed` |
| developerTools | `true` |

## profile bundles

```
@deepseek-ai/dsh-base
@deepseek-ai/dsh-web-app
```

## 备注

- 这些偏好不是「规范」，只是当前工作方式；DSH 升级后字段可能改名（`version` 字段即用于迁移）。
- 若要一键复刻，把本文件里的表翻译回 `~/.dsh/profiles/desktop/cordis.patch.yml` 的
  `agent-default-model` / `ui-*` 条目即可。
