#!/usr/bin/env python3
"""脱敏检查：公开仓库里不该出现的个人信息。

规则来自本项目真实踩过的点（私人邮箱写进了 AGENTS.md，并被 8 个 commit 携带）：

  1. 个人邮箱（gmail/qq/163/…），放行 users.noreply.github.com 与 example.com
  2. 家目录绝对路径（/Users/<真名>/、/home/<真名>/），放行 /Users/x/ 这类占位
  3. IPv4 地址，放行回环、文档保留段（192.0.2.0/24 等）
  4. 凭证文件名（cred 前缀文件、私钥文件名等）

默认只扫「本仓库自己的内容」，跳过 skills/（第三方内容）与 licenses/（上游版权文本）；
需要连第三方一起扫时加 --include-vendored。

  python3 scripts/check_privacy.py [repo]
  python3 scripts/check_privacy.py --history      # 扫全部提交的 diff（改写历史后用来自证）

本机还可以放一份 `.privacy-denylist`（已在 .gitignore 里），
一行一个不该出现的字符串（真名、内网域名…），不入库但参与扫描。
"""
import argparse
import re
import subprocess
from pathlib import Path

ALLOW_EMAIL_DOMAINS = ("users.noreply.github.com", "example.com", "example.org", "anthropic.com")
ALLOW_HOME = {"x", "user", "username", "example", "yourname", "shared", "runner", "you", "me"}
ALLOW_IPS = {"127.0.0.1", "0.0.0.0", "8.8.8.8", "1.1.1.1", "255.255.255.255"}
ALLOW_IP_PREFIXES = ("192.0.2.", "198.51.100.", "203.0.113.")
SKIP_DIRS = {".git", "node_modules", "__pycache__", "skills", "licenses"}

# git grep 用的是 POSIX ERE（不支持 \b），这里给每条规则一个宽松的预过滤，
# 命中后再用上面的 Python 正则做精确判断与放行。
GREP_PREFILTER = {
    "个人邮箱": r"@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    "家目录绝对路径": r"/(Users|home)/",
    "IPv4 地址": r"([0-9]{1,3}\.){3}[0-9]{1,3}",
    "凭证文件": r"\.cred|id" + r"_rsa",
}

RULES = [
    ("个人邮箱", re.compile(r"\b[A-Za-z0-9][A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b")),
    ("家目录绝对路径", re.compile(r"/(?:Users|home)/([A-Za-z0-9._-]+)/")),
    ("IPv4 地址", re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")),
    # 拆开拼接：避免脚本自身被自己的规则命中（自我匹配）
    ("凭证文件", re.compile(r"\.cred" + r"-[A-Za-z0-9]|\.dsh/hosts/\.cred|\bid" + r"_rsa\b")),
]


def allowed(match: re.Match, name: str) -> bool:
    if name == "个人邮箱":
        domain = match.group(1).lower()
        return any(domain.endswith(d) for d in ALLOW_EMAIL_DOMAINS)
    if name == "家目录绝对路径":
        return match.group(1).lower() in ALLOW_HOME
    if name == "IPv4 地址":
        ip = match.group(0)
        return ip in ALLOW_IPS or ip.startswith(ALLOW_IP_PREFIXES)
    return False


def scan_text(text: str, origin: str, denylist: list[str]) -> list[str]:
    hits = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if any(token and token in line for token in denylist):
            hits.append(f"{origin}:{lineno}: 命中本机 denylist")
            continue
        for name, pattern in RULES:
            for match in pattern.finditer(line):
                if allowed(match, name):
                    continue
                hits.append(f"{origin}:{lineno}: {name} → {match.group(0)}")
    return hits


def scan_tree(repo: Path, include_vendored: bool, denylist: list[str]) -> list[str]:
    hits = []
    for path in sorted(repo.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(repo)
        parents = set(rel.parts[:-1])
        if parents & {".git", "node_modules", "__pycache__"}:
            continue
        if not include_vendored and parents & {"skills", "licenses"}:
            continue
        if path.suffix in {".png", ".jpg", ".zip", ".gz", ".bundle"}:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        hits += scan_text(text, str(rel), denylist)
    return hits


def scan_history(repo: Path, denylist: list[str]) -> list[str]:
    """逐 commit 扫，排除第三方目录，避免上游示例邮箱误报。"""
    try:
        revs = subprocess.run(
            ["git", "-C", str(repo), "rev-list", "--all"],
            capture_output=True, text=True, timeout=60,
        ).stdout.split()
    except subprocess.TimeoutExpired:
        return ["git rev-list 超时，跳过历史扫描"]

    if not revs:
        return []

    hits = []
    seen = set()
    for rev in revs:
        for name, pattern in RULES:
            proc = subprocess.run(
                ["git", "-C", str(repo), "grep", "-I", "-n", "-E", "-e",
                 GREP_PREFILTER.get(name, pattern.pattern),
                 rev, "--", ".", ":(exclude)skills", ":(exclude)licenses"],
                capture_output=True, text=True,
            )
            for raw in proc.stdout.splitlines():
                parts = raw.split(":", 3)
                if len(parts) < 4:
                    continue
                text = parts[3]
                for match in pattern.finditer(text):
                    if allowed(match, name):
                        continue
                    key = (name, match.group(0))
                    if key in seen:
                        continue
                    seen.add(key)
                    hits.append(f"历史中：{name} → {match.group(0)}（{parts[1]}）")

    # denylist 连第三方一起扫（真名可能出现在任何地方）
    diff = subprocess.run(
        ["git", "-C", str(repo), "log", "--all", "--pretty=format:", "-p"],
        capture_output=True, text=True, timeout=120,
    ).stdout
    for token in denylist:
        if token and token in diff:
            hits.append(f"历史中：命中本机 denylist → {token[:20]}…")
    return hits


def load_denylist(repo: Path) -> list[str]:
    path = repo / ".privacy-denylist"
    if not path.is_file():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo", nargs="?", default=".")
    ap.add_argument("--history", action="store_true", help="同时扫描全部提交的 diff")
    ap.add_argument("--include-vendored", action="store_true", help="连 skills/ 与 licenses/ 一起扫")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    denylist = load_denylist(repo)

    hits = scan_tree(repo, args.include_vendored, denylist)
    if args.history:
        hits += scan_history(repo, denylist)

    if hits:
        for hit in hits[:20]:
            print(f"  ✗ {hit}")
        if len(hits) > 20:
            print(f"  … 另有 {len(hits) - 20} 处")
        return 1

    scope = "工作区 + 全部历史" if args.history else "工作区"
    extra = f"；denylist {len(denylist)} 条" if denylist else ""
    print(f"  {scope}未发现个人信息（{extra.strip('；') or '无 denylist'}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
