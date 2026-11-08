# 上游许可证快照

本目录（仓库根 `licenses/`）存放 42 个 skill 所依赖的 **9 个上游仓库**的许可证原文或授权说明。
目的：合规不再依赖「上游仓库还活着、文件没改名」。

为什么需要：GitHub 的 licensee 只认仓库根目录的 `LICENSE` 文件。
上游若把许可写在 README 或 SKILL.md frontmatter 里，API 会返回 `null`，
但**授权依然成立**——只是需要有本地凭证，别在复核时误判。

## 映射

| 文件 | 上游 | 许可 | 依据 |
|---|---|---|---|
| `obra-superpowers.txt` | [obra/superpowers](https://github.com/obra/superpowers) | MIT | 根目录 `LICENSE`（21 行原文） |
| `anthropics-skills.Apache-2.0.txt` | [anthropics/skills](https://github.com/anthropics/skills) | Apache-2.0 | 每个 skill 目录内 `LICENSE.txt`（此处为该文件副本） |
| `addyosmani-web-quality-skills.txt` | [addyosmani/web-quality-skills](https://github.com/addyosmani/web-quality-skills) | MIT | 根目录 `LICENSE` |
| `OthmanAdi-planning-with-files.txt` | [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) | MIT | 根目录 `LICENSE` |
| `ayghri-i-have-adhd.txt` | [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | MIT | 根目录 `LICENSE` |
| `cathrynlavery-diagram-design.txt` | [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) | MIT | 根目录 `LICENSE` |
| `Egonex-AI-Understand-Anything.txt` | [Egonex-AI/Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | MIT | 根目录 `LICENSE` |
| `vercel-labs-agent-skills.NOTE.md` | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | MIT | 无 LICENSE 文件；README「## License → MIT」+ 3 个 SKILL.md `license: MIT` |
| `multica-ai-karpathy-skills.NOTE.md` | [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) | MIT | 无 LICENSE 文件；README「## License → MIT」+ SKILL.md `license: MIT` |

## 复核方式

```bash
# 上游是否新增/变更了 LICENSE
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/HEAD/LICENSE | head -3

# GitHub 侧的识别结果（null 不代表没有授权，见上表）
gh api repos/<owner>/<repo> --jq '.license.spdx_id'
```

## 更新规则

- 上游许可证**变更或收紧**时，先停用对应 skill（从 `skills/` 移除），再更新本目录与
  `THIRD-PARTY-NOTICES.md`，最后 `make manifest && make all`。
- 快照与上游不一致时，以**上游当前文本**为准，快照用于举证「我们当时看到的版本」。
