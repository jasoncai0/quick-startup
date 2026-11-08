#!/usr/bin/env python3
"""生成 skills/manifest.tsv：name / files / size_kb / digest / group。

digest 由 scripts/dir_digest.py 计算，verify.sh 用它判断「本机安装 vs 仓库」是否漂移。
分组只影响可读性；来源（上游仓库 + commit）见 skills/SOURCES.md。

用法：python3 scripts/make-manifest.py [repo_root]
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dir_digest import digest  # noqa: E402

GROUPS = {
    "工程流程": [
        "brainstorming", "writing-plans", "executing-plans", "test-driven-development",
        "systematic-debugging", "verification-before-completion", "requesting-code-review",
        "receiving-code-review", "using-git-worktrees", "finishing-a-development-branch",
        "subagent-driven-development", "dispatching-parallel-agents", "writing-skills",
    ],
    "代码理解": [
        "understand", "understand-chat", "understand-dashboard", "understand-diff",
        "understand-domain", "understand-explain", "understand-figma",
        "understand-knowledge", "understand-onboard",
    ],
    "Web 质量": ["accessibility", "best-practices", "core-web-vitals", "performance", "seo", "web-quality-audit"],
    "元技能/文档": ["skill-creator", "doc-coauthoring", "mcp-builder", "claude-api", "frontend-design", "webapp-testing"],
    "前端/React": ["vercel-react-best-practices", "vercel-composition-patterns",
                   "vercel-react-view-transitions", "web-design-guidelines"],
    "规划与行为约束": ["planning-with-files", "i-have-adhd", "karpathy-guidelines"],
    "可视化": ["diagram-design"],
}


def group_of(name: str) -> str:
    for group, names in GROUPS.items():
        if name in names:
            return group
    return "未分类"


def main() -> int:
    repo = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    skills_dir = repo / "skills"

    rows = []
    for d in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        if not (d / "SKILL.md").is_file():
            continue
        files = [f for f in d.rglob("*") if f.is_file() and not f.is_symlink()]
        size_kb = sum(f.stat().st_size for f in files) // 1024
        rows.append((d.name, len(files), size_kb, digest(d), group_of(d.name)))

    out = skills_dir / "manifest.tsv"
    with out.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("name\tfiles\tsize_kb\tdigest\tgroup\n")
        for row in rows:
            fh.write("\t".join(map(str, row)) + "\n")

    total_files = sum(r[1] for r in rows)
    total_kb = sum(r[2] for r in rows)
    ungrouped = [r[0] for r in rows if r[4] == "未分类"]
    print(f"manifest: {len(rows)} skills, {total_files} files, {total_kb / 1024:.1f} MB → {out}")
    if ungrouped:
        print(f"警告：未分组 {ungrouped}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
