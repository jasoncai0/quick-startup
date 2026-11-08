#!/usr/bin/env python3
"""校验 README / VERSION / CHANGELOG 与仓库现实是否一致。

宁可让 CI 挂，也不让文档说谎：
  - README 里的 skill 数量 == manifest 行数
  - README 里每个 skill 名都出现（代码风格 `name`）
  - README 里声明的规范行数 == standards/backend-standards.md 实际行数
  - README 中的所有相对链接可解析
  - VERSION == CHANGELOG 最新的版本号
  - README 提到的脚本/文件都存在

用法：python3 scripts/check_docs.py [repo_root]
"""
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
TICK_RE = re.compile(r"`([a-z0-9][a-z0-9-]*)`")


def main() -> int:
    repo = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    problems = []

    readme = (repo / "README.md").read_text(encoding="utf-8")
    manifest = (repo / "skills" / "manifest.tsv").read_text(encoding="utf-8").strip().splitlines()
    rows = [line.split("\t") for line in manifest[1:] if line.strip()]
    names = [r[0] for r in rows]
    n = len(rows)

    # 1. 计数
    if str(n) not in readme:
        problems.append(f"README 未出现 skill 数量 {n}")

    # 2. 每个 skill 名都要出现
    missing = [name for name in names if f"`{name}`" not in readme]
    if missing:
        problems.append(f"README 漏列 {len(missing)} 个 skill：{', '.join(missing[:6])}{' …' if len(missing) > 6 else ''}")

    # 3. 规范行数
    std = repo / "standards" / "backend-standards.md"
    lines = len(std.read_text(encoding="utf-8").splitlines()) if std.is_file() else 0
    if f"{lines} 行" not in readme:
        problems.append(f"README 未声明规范行数「{lines} 行」（规范已变更？同步 README）")

    # 4. 相对链接
    for target in LINK_RE.findall(readme):
        target = target.split("#", 1)[0].strip()
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        if not (repo / target).exists():
            problems.append(f"README 链接指向不存在的路径：{target}")

    # 5. README 提到的脚本存在
    for script in set(re.findall(r"scripts/([A-Za-z0-9_.-]+)", readme)):
        if not (repo / "scripts" / script).exists():
            problems.append(f"README 提到不存在的脚本：scripts/{script}")

    # 6. VERSION vs CHANGELOG
    version_file = repo / "VERSION"
    changelog = repo / "CHANGELOG.md"
    if version_file.is_file() and changelog.is_file():
        version = version_file.read_text(encoding="utf-8").strip()
        versions = re.findall(r"^##\s*\[?v?(\d+\.\d+\.\d+)\]?", changelog.read_text(encoding="utf-8"), re.M)
        if not versions:
            problems.append("CHANGELOG.md 没有 `## [x.y.z]` 形式的版本段")
        elif versions[0] != version:
            problems.append(f"VERSION（{version}）与 CHANGELOG 最新版本（{versions[0]}）不一致")
    else:
        problems.append("缺少 VERSION 或 CHANGELOG.md")

    if problems:
        for p in problems:
            print(f"  ✗ {p}")
        return 1
    print(f"  README / VERSION / CHANGELOG 与仓库一致（{n} 个 skill，{lines} 行规范）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
