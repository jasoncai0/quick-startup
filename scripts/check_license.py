#!/usr/bin/env python3
"""许可证守卫：LICENSE 必须是**逐行等于 MIT 标准文本**的原文。

背景（真实踩过）：在 MIT 原文后追加一段中文说明，licensee 就匹配不上，
仓库页不再显示 MIT，`gh api ... --jq .license.spdx_id` 返回 NOASSERTION。

不靠「行数/是否含中文」这类启发式——版权行里出现中文名是合法的。
做法是拿标准 MIT 正文逐行比对，允许且只允许两处差异：
  1. 版权行（`Copyright (c) ...`）内容与年份；
  2. 空行。

这样任何"加工"（追加说明、翻译、删改条款）都会被抓到。

另查：licenses/ 快照是否齐全（9 个上游）。
可选：--github owner/repo 再查 GitHub 侧的 spdx_id（需要 gh，失败则跳过）。

用法：python3 scripts/check_license.py [--github owner/repo] [repo_root]
"""
import argparse
import os
import re
import subprocess
from pathlib import Path

# MIT 标准正文的非空行（不含版权行）
MIT_BODY = [
    "MIT License",
    "Permission is hereby granted, free of charge, to any person obtaining a copy",
    'of this software and associated documentation files (the "Software"), to deal',
    "in the Software without restriction, including without limitation the rights",
    "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell",
    "copies of the Software, and to permit persons to whom the Software is",
    "furnished to do so, subject to the following conditions:",
    "The above copyright notice and this permission notice shall be included in all",
    "copies or substantial portions of the Software.",
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
    "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,",
    "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE",
    "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER",
    "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,",
    "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE",
    "SOFTWARE.",
]
COPYRIGHT_RE = re.compile(r"^copyright\s*(\(c\)|©)?", re.I)
EXPECTED_UPSTREAMS = 9


def check_license_file(path: Path) -> list[str]:
    if not path.is_file():
        return [f"缺少 {path}"]

    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    copyright_lines = [l for l in lines if COPYRIGHT_RE.match(l)]
    body = [l for l in lines if not COPYRIGHT_RE.match(l)]

    problems = []
    if not copyright_lines:
        problems.append("缺少版权行（Copyright (c) <年份> <作者>）")
    if len(copyright_lines) > 1:
        problems.append(f"版权行出现 {len(copyright_lines)} 次，应只有 1 行")

    if body == MIT_BODY:
        return problems

    for i, expected in enumerate(MIT_BODY):
        actual = body[i] if i < len(body) else "<缺失>"
        if actual != expected:
            problems.append(f"第 {i + 1} 行与 MIT 标准文本不符：")
            problems.append(f"      期望：{expected[:66]}")
            problems.append(f"      实际：{actual[:66]}")
            break
    extra = len(body) - len(MIT_BODY)
    if extra > 0:
        problems.append(f"正文多出 {extra} 行：疑似追加了说明（licensee 会识别失败）")
    elif extra < 0:
        problems.append(f"正文少 {abs(extra)} 行：疑似删改了条款")
    return problems


def check_snapshots(repo: Path) -> list[str]:
    lic_dir = repo / "licenses"
    if not lic_dir.is_dir():
        return ["缺少 licenses/（上游许可证快照）"]
    if not (lic_dir / "README.md").is_file():
        return ["缺少 licenses/README.md（快照映射表）"]
    entries = [p for p in lic_dir.iterdir() if p.suffix in (".txt", ".md") and p.name != "README.md"]
    if len(entries) != EXPECTED_UPSTREAMS:
        return [f"licenses/ 有 {len(entries)} 个上游条目，应为 {EXPECTED_UPSTREAMS}"]
    return []


def check_github(repo_slug: str) -> list[str]:
    candidates = ["gh", str(Path(__file__).resolve().parent.parent.parent / ".tools" / "gh_2.103.3_macOS_arm64" / "bin" / "gh")]
    gh = None
    for cand in candidates:
        try:
            subprocess.run([cand, "--version"], capture_output=True, check=True, timeout=10)
            gh = cand
            break
        except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
    if gh is None:
        print("  （未找到 gh，跳过 GitHub 侧校验）")
        return []

    try:
        out = subprocess.run(
            [gh, "api", f"repos/{repo_slug}", "--jq", '.license.spdx_id // "null"'],
            capture_output=True, text=True, timeout=30, env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired:
        print("  （GitHub 查询超时，跳过）")
        return []

    if out.returncode != 0:
        print(f"  （GitHub 查询失败，跳过：{out.stderr.strip()[:60]}）")
        return []
    spdx = out.stdout.strip()
    if spdx != "MIT":
        return [f"GitHub 识别为 {spdx}，应为 MIT（LICENSE 可能被加工过）"]
    print("  GitHub 侧识别：MIT")
    return []


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo", nargs="?", default=".")
    ap.add_argument("--github", metavar="OWNER/REPO")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    problems = check_license_file(repo / "LICENSE")
    problems += check_snapshots(repo)
    if args.github:
        problems += check_github(args.github)

    if problems:
        for p in problems:
            print(f"  ✗ {p}")
        return 1
    print("  LICENSE 为 MIT 标准原文；上游许可快照齐全")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
