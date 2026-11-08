#!/usr/bin/env python3
"""合并 AGENTS.md：仓库版为准，但保留本机追加的内容。

为什么需要：`~/.dsh/AGENTS.md` 里有只属于这台机器、且**不该进公开仓库**的内容
（例如服务器 IP、内网路径）。install.sh 直接 `cp` 会把它静默删掉。

规则：
  - 仓库版内容永远为准（按行覆盖）；
  - 本机独有的非空行收进文末「## 本机追加」段落，重复安装不会叠加；
  - 本机独有的行若已经出现在仓库版里，不重复保留。

用法：
  python3 scripts/merge_agents.py <repo_AGENTS.md> <installed_AGENTS.md> [--check]

  --check  只报告会保留多少行，不写文件（退出码 0）
"""
import sys
from pathlib import Path

MARKER = "## 本机追加（安装器保留）"


def split_local(text: str) -> tuple[str, list[str]]:
    """把文件拆成（安装器管理的部分，本机追加的行）。"""
    if MARKER not in text:
        # 没有标记时，整份文件都参与 diff：repo 里有的行不会进「本机追加」
        return "", [line for line in text.splitlines() if line.strip()]
    head, _, tail = text.partition(MARKER)
    local = [line for line in tail.splitlines() if line.strip()]
    return head.rstrip() + "\n", local


def merge(repo_text: str, inst_text: str) -> tuple[str, int]:
    repo_lines = {line.strip() for line in repo_text.splitlines() if line.strip()}
    _, local = split_local(inst_text)
    keep = [line for line in local if line.strip() not in repo_lines]

    merged = repo_text.rstrip() + "\n"
    if keep:
        merged += f"\n{MARKER}\n\n" + "\n".join(keep) + "\n"
    return merged, len(keep)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    check_only = "--check" in sys.argv
    repo_path, inst_path = Path(sys.argv[1]), Path(sys.argv[2])
    repo_text = repo_path.read_text(encoding="utf-8")

    if not inst_path.is_file():
        if not check_only:
            inst_path.parent.mkdir(parents=True, exist_ok=True)
            inst_path.write_text(repo_text, encoding="utf-8")
        print("  首次安装：直接写入仓库版")
        return 0

    inst_text = inst_path.read_text(encoding="utf-8")
    merged, kept = merge(repo_text, inst_text)

    if merged == inst_text:
        print("  已是最新（无需写入）")
        return 0

    if check_only:
        print(f"  将保留本机追加 {kept} 行")
        return 0

    inst_path.write_text(merged, encoding="utf-8")
    if kept:
        print(f"  已更新仓库内容；本机追加的 {kept} 行已保留在「{MARKER}」段")
    else:
        print("  已更新为仓库版（无本机追加内容）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
