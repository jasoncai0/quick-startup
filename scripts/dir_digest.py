#!/usr/bin/env python3
"""目录内容摘要（digest），用于检测 skill 是否漂移。

digest = sha256( 逐行 "相对路径\\0文件sha256\\n" )，文件按路径排序。
与 mtime、权限、软链无关；新增/删除/改名/改内容都会改变 digest。

CLI:  python3 scripts/dir_digest.py <dir>   # 打印 64 位十六进制
库:   from dir_digest import digest
"""
import hashlib
import sys
from pathlib import Path


def digest(root: Path) -> str:
    root = Path(root)
    if not root.is_dir():
        raise SystemExit(f"不是目录：{root}")
    entries = []
    for f in root.rglob("*"):
        if f.is_symlink() or not f.is_file():
            continue
        rel = f.relative_to(root).as_posix()
        h = hashlib.sha256(f.read_bytes()).hexdigest()
        entries.append(f"{rel}\0{h}\n")
    entries.sort()
    agg = hashlib.sha256()
    for line in entries:
        agg.update(line.encode("utf-8"))
    return agg.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print("用法：python3 scripts/dir_digest.py <dir>", file=sys.stderr)
        return 2
    try:
        print(digest(Path(sys.argv[1])))
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
