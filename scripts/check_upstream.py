#!/usr/bin/env python3
"""校验 skills 的上游来源：结构（离线）与上游状态（在线）。

  python3 scripts/check_upstream.py [repo]            # 离线：结构 + 覆盖度
  python3 scripts/check_upstream.py [repo] --online    # 再查上游 HEAD 与许可证

离线检查（失败即 1）：
  - 42 个 skill 每个恰好被一个上游声明覆盖，不多不少；
  - commit 是 7–40 位十六进制；
  - license 在允许集合内（MIT / Apache-2.0）；
  - 声明了 licenses/ 快照文件且文件存在。

在线检查（需 gh）：
  - pin 的 commit 在上游仍存在；
  - 上游 HEAD 是否前进（信息性，不失败）；
  - 上游许可证是否从 null 变成具体值、或与声明不符（**失败**，属合规风险）。
"""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

ENV = os.environ.copy()

ALLOWED_LICENSES = {"MIT", "Apache-2.0"}
COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")
# 上游没有 LICENSE 文件、但 README/SKILL 声明了许可的仓库，API 会返回 null
NULL_LICENSE_OK = {"vercel-labs/agent-skills", "multica-ai/andrej-karpathy-skills", "anthropics/skills"}


def find_gh() -> str | None:
    candidates = ["gh", str(Path(__file__).resolve().parent.parent.parent / ".tools" / "gh_2.103.3_macOS_arm64" / "bin" / "gh")]
    for cand in candidates:
        try:
            subprocess.run([cand, "--version"], capture_output=True, check=True, timeout=10)
            return cand
        except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
    return None


def api(gh: str, path: str, jq: str) -> str | None:
    try:
        out = subprocess.run(
            [gh, "api", path, "--jq", jq],
            capture_output=True, text=True, timeout=30, env=ENV,
        )
    except subprocess.TimeoutExpired:
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def load(repo: Path) -> dict:
    path = repo / "skills" / "upstreams.json"
    if not path.is_file():
        raise SystemExit(f"缺少 {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path} 不是合法 JSON：{exc}")


def offline(repo: Path, data: dict) -> list[str]:
    problems = []
    if data.get("schema") != 1:
        problems.append(f"schema 应为 1，实际 {data.get('schema')!r}")

    upstreams = data.get("upstreams") or []
    if not upstreams:
        return ["upstreams 为空"]

    seen: dict[str, str] = {}
    for entry in upstreams:
        name = entry.get("repo", "<缺 repo>")
        commit = str(entry.get("commit", ""))
        license_name = entry.get("license", "")
        snapshot = entry.get("license_snapshot", "")

        if not COMMIT_RE.match(commit):
            problems.append(f"{name}: commit 应为 7–40 位十六进制，实际 {commit!r}")
        if license_name not in ALLOWED_LICENSES:
            problems.append(f"{name}: license 只允许 {sorted(ALLOWED_LICENSES)}，实际 {license_name!r}")
        if not snapshot:
            problems.append(f"{name}: 缺 license_snapshot")
        elif not (repo / "licenses" / snapshot).is_file():
            problems.append(f"{name}: 快照文件不存在 licenses/{snapshot}")

        skills = entry.get("skills") or []
        if not skills:
            problems.append(f"{name}: skills 为空")
        for skill in skills:
            if skill in seen:
                problems.append(f"{skill}: 被 {seen[skill]} 与 {name} 重复声明")
            seen[skill] = name
            if not (repo / "skills" / skill).is_dir():
                problems.append(f"{skill}: 声明了但目录不存在")

    on_disk = {p.name for p in (repo / "skills").iterdir() if p.is_dir() and (p / "SKILL.md").is_file()}
    for skill in sorted(on_disk - set(seen)):
        problems.append(f"{skill}: 目录存在但未在任何上游声明")
    for skill in sorted(set(seen) - on_disk):
        problems.append(f"{skill}: 已声明但磁盘无对应 skill 目录")

    return problems


def online(repo: Path, data: dict) -> list[str]:
    gh = find_gh()
    if gh is None:
        print("  （未找到 gh，跳过在线检查）")
        return []

    auth = subprocess.run([gh, "auth", "status"], capture_output=True, text=True, env=ENV, timeout=20)
    if auth.returncode != 0:
        print("  （gh 未认证，跳过在线检查；设置 GH_CONFIG_DIR 或先 gh auth login）")
        print("   注意：不能把「未认证」当成「上游不存在」——那会产生假阴性")
        return []

    problems = []
    print(f"  {'上游':<40}{'pin':<10}{'HEAD':<10}{'新增':<6}许可")
    for entry in data["upstreams"]:
        name = entry["repo"]
        pin = entry["commit"]
        declared = entry["license"]

        head = api(gh, f"repos/{name}/commits/HEAD", ".sha[0:7]")
        pinned = api(gh, f"repos/{name}/commits/{pin}", ".sha[0:7]")
        spdx = api(gh, f"repos/{name}", '.license.spdx_id // "null"')

        if pinned is None:
            problems.append(f"{name}: pin {pin} 在上游已不存在（被 rebase/删除？）")
        if head is None:
            problems.append(f"{name}: 无法读取 HEAD（限流或仓库改名？）")
            continue

        ahead = ""
        if pinned:
            cmp_json = api(gh, f"repos/{name}/compare/{pin}...{head}", ".ahead_by")
            if cmp_json and cmp_json.isdigit():
                ahead = cmp_json

        license_cell = spdx or "null"
        if spdx and spdx not in ("null", declared):
            problems.append(f"{name}: 上游许可为 {spdx}，与声明的 {declared} 不符（合规风险）")
        elif spdx == "null" and name not in NULL_LICENSE_OK:
            problems.append(f"{name}: 上游许可证消失（原为 {declared}）——需复核是否仍可再分发")

        print(f"  {name:<40}{pin:<10}{head:<10}{ahead or '-':<6}{license_cell}")

    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo", nargs="?", default=".")
    ap.add_argument("--online", action="store_true", help="同时查询上游 HEAD 与许可证")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()

    # 没显式设置时，自动找同级的 .tools/ghconfig（本机 gh 的登录态在这里）
    if "GH_CONFIG_DIR" not in ENV:
        candidate = repo.parent / ".tools" / "ghconfig"
        if candidate.is_dir():
            ENV["GH_CONFIG_DIR"] = str(candidate)

    data = load(repo)

    problems = offline(repo, data)
    total = sum(len(e.get("skills") or []) for e in data["upstreams"])

    if not problems:
        print(f"  {len(data['upstreams'])} 个上游 / {total} 个 skill，结构一致")

    if args.online:
        print()
        problems += online(repo, data)

    if problems:
        print()
        for p in problems:
            print(f"  ✗ {p}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
