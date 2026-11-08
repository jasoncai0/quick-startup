#!/usr/bin/env python3
"""校验 skills/manifest.tsv 与磁盘内容是否一致（锁文件语义）。

  python3 scripts/check_manifest.py --repo .                  # 仓库内 42 个目录 vs 锁文件
  python3 scripts/check_manifest.py --repo . --installed DIR   # 再加本机安装目录

退出码 0 = 全部一致；1 = 有不一致（逐条打印）。
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dir_digest import digest  # noqa: E402

COLUMNS = ["name", "files", "size_kb", "digest", "group"]


def load(manifest: Path) -> dict:
    rows = {}
    with manifest.open(encoding="utf-8") as fh:
        header = fh.readline().rstrip("\n").split("\t")
        if header != COLUMNS:
            raise SystemExit(f"{manifest}: 表头应为 {COLUMNS}，实际 {header}")
        for lineno, line in enumerate(fh, start=2):
            if not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) != len(COLUMNS):
                raise SystemExit(f"{manifest}:{lineno}: 列数应为 {len(COLUMNS)}")
            row = dict(zip(COLUMNS, parts))
            rows[row["name"]] = row
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--installed")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    manifest = repo / "skills" / "manifest.tsv"
    if not manifest.is_file():
        print(f"缺少锁文件：{manifest}")
        return 1

    rows = load(manifest)
    problems = []

    on_disk = {p.name for p in (repo / "skills").iterdir() if p.is_dir() and (p / "SKILL.md").is_file()}
    for name in sorted(on_disk - set(rows)):
        problems.append(f"未登记：skills/{name}（跑 scripts/make-manifest.py 更新锁文件）")
    for name in sorted(set(rows) - on_disk):
        problems.append(f"已失效：manifest 有 {name}，磁盘无对应目录")
    for name in sorted(on_disk & set(rows)):
        d = repo / "skills" / name
        actual_files = len([f for f in d.rglob("*") if f.is_file() and not f.is_symlink()])
        if actual_files != int(rows[name]["files"]):
            problems.append(f"{name}: 文件数 {actual_files} ≠ 锁文件 {rows[name]['files']}")
        actual = digest(d)
        if actual != rows[name]["digest"]:
            problems.append(f"{name}: 内容摘要不符（仓库已改但未更新锁文件）")
        if rows[name]["group"] == "未分类":
            problems.append(f"{name}: 未分组（scripts/make-manifest.py 的 GROUPS）")

    if args.installed:
        inst = Path(args.installed)
        if not inst.is_dir():
            problems.append(f"安装目录不存在：{inst}")
        else:
            for name in sorted(set(rows)):
                d = inst / name
                if not d.is_dir():
                    problems.append(f"{name}: 未安装")
                elif digest(d) != rows[name]["digest"]:
                    problems.append(f"{name}: 已安装版本与锁文件不一致（漂移）")

    if problems:
        for p in problems:
            print(f"  ✗ {p}")
        return 1
    scope = f"{len(rows)} 个 skill"
    print(f"  {scope} 与锁文件一致" + ("；安装目录一致" if args.installed else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
