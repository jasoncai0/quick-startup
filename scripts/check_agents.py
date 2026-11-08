#!/usr/bin/env python3
"""校验已安装的 AGENTS.md 与仓库版本「语义一致」。

不逐字节比对，因为：
  - 规范路径在部署后是本机路径（`/Users/x/.dsh/...` vs `~/.dsh/...`）；
  - 记忆文件允许本机追加笔记。

真正要守住的是三件事，任一被改掉就报错：
  1. CodeGraph 标记围栏内的整块内容原样存在；
  2. 10 条后端红线逐条原样存在；
  3. 仍指向 backend-standards.md（完整版规范）。

用法：python3 scripts/check_agents.py <repo_AGENTS.md> <installed_AGENTS.md>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

START, END = "<!-- CODEGRAPH_START -->", "<!-- CODEGRAPH_END -->"
RULE_RE = re.compile(r"^\d+\.\s+\*\*")


def codegraph_block(text: str) -> str | None:
    if START not in text or END not in text:
        return None
    return text[text.index(START): text.index(END) + len(END)]


def rules(text: str) -> list[str]:
    return [line.rstrip() for line in text.splitlines() if RULE_RE.match(line.strip())]


def main() -> int:
    if len(sys.argv) != 3:
        print("用法：python3 scripts/check_agents.py <repo> <installed>", file=sys.stderr)
        return 2

    repo_path, inst_path = Path(sys.argv[1]), Path(sys.argv[2])
    for p in (repo_path, inst_path):
        if not p.is_file():
            print(f"文件不存在：{p}")
            return 1

    repo_text = repo_path.read_text(encoding="utf-8")
    inst_text = inst_path.read_text(encoding="utf-8")

    problems = []

    want_block = codegraph_block(repo_text)
    if want_block is None:
        problems.append("仓库版 AGENTS.md 缺少 CODEGRAPH 标记围栏")
    else:
        got_block = codegraph_block(inst_text)
        if got_block is None:
            problems.append("已安装版缺少 CODEGRAPH 标记围栏")
        elif got_block.strip() != want_block.strip():
            problems.append("已安装版的 CodeGraph 记忆块与仓库不一致")

    want_rules = rules(repo_text)
    got_rules = set(rules(inst_text))
    missing = [r for r in want_rules if r not in got_rules]
    if missing:
        problems.append(f"已安装版缺少 {len(missing)} 条红线：")
        for line in missing[:5]:
            problems.append(f"    {line[:60]}…")

    if "backend-standards.md" not in inst_text:
        problems.append("已安装版不再指向 backend-standards.md")

    if problems:
        for p in problems:
            print(f"  ✗ {p}")
        return 1

    extra = len([l for l in inst_text.splitlines() if l.strip()]) - len([l for l in repo_text.splitlines() if l.strip()])
    print(f"  记忆块与 {len(want_rules)} 条红线完整；本机额外 {max(extra, 0)} 行")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
