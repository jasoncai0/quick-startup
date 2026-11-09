#!/usr/bin/env bash
# 按上游 HEAD 升级单个 skill：预览 diff，确认后替换并更新 pin。
#
#   ./scripts/upgrade_skill.sh <skill>                 # 预览差异（不动文件）
#   ./scripts/upgrade_skill.sh <skill> --apply         # 写入 skills/<skill> 并更新 upstreams.json 的 commit
#   ./scripts/upgrade_skill.sh <skill> --source <dir>  # 用本地目录/其它 git URL 代替 GitHub（离线测试）
#
# 为什么默认只预览：skill 是别人写的提示词，升级等于换行为。先看 diff 再决定。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL=""
APPLY=0
SOURCE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --source) [ $# -ge 2 ] || { echo "--source 需要参数" >&2; exit 2; }; SOURCE="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "未知参数：$1" >&2; exit 2 ;;
    *) SKILL="$1"; shift ;;
  esac
done

b=$'\033[1;34m'; g=$'\033[1;32m'; y=$'\033[1;33m'; r=$'\033[1;31m'; o=$'\033[0m'
step() { printf '%s▸%s %s\n' "$b" "$o" "$*"; }
ok()   { printf '%s✓%s %s\n' "$g" "$o" "$*"; }
warn() { printf '%s!%s %s\n' "$y" "$o" "$*"; }
die()  { printf '%s✗%s %s\n' "$r" "$o" "$*" >&2; exit 1; }

[ -n "$SKILL" ] || die "用法：$0 <skill> [--apply] [--source <dir>]"
[ -d "$REPO/skills/$SKILL" ] || die "本地没有这个 skill：skills/$SKILL"

# 1. 从 upstreams.json 查出上游仓库、pin、路径
meta="$(python3 - "$REPO/skills/upstreams.json" "$SKILL" <<'PY'
import json, sys
path, skill = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
for e in data["upstreams"]:
    if skill in (e.get("skills") or []):
        p = (e.get("path_overrides") or {}).get(skill) or e["path_template"].replace("{skill}", skill)
        print(f'{e["repo"]}\t{e["commit"]}\t{p}')
        break
else:
    sys.exit(1)
PY
)" || die "upstreams.json 里没有 $SKILL 的来源声明"

repo_slug="$(printf '%s' "$meta" | cut -f1)"
pin="$(printf '%s' "$meta" | cut -f2)"
subpath="$(printf '%s' "$meta" | cut -f3)"

# --apply 是破坏性路径：先在克隆之前快速失败，别等拉完才报错
if (( APPLY )) && [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ]; then
  die "工作区不干净，先提交或 stash 再升级"
fi

step "来源：${repo_slug} @ ${pin}"
step "上游路径：${subpath}"

# 2. 取上游（默认 GitHub HTTPS，--source 可指向本地目录或其他 git URL）
tmp="$(mktemp -d "${TMPDIR:-/tmp}/qs-upgrade.XXXXXX")"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

src="${SOURCE:-https://github.com/${repo_slug}.git}"
step "拉取：${src}"
git clone --depth 1 --quiet "$src" "$tmp/up" 2>/dev/null || die "clone 失败：${src}"
head_sha="$(git -C "$tmp/up" rev-parse --short HEAD)"
ok "上游 HEAD：${head_sha}"

[ -d "$tmp/up/$subpath" ] || die "上游没有 ${subpath}（目录改名了？请更新 upstreams.json）"
[ -f "$tmp/up/$subpath/SKILL.md" ] || die "上游 ${subpath} 没有 SKILL.md，拒绝替换"

# 3. 差异
step "差异（本地 vs 上游 HEAD）"
if diff -rq "$tmp/up/$subpath" "$REPO/skills/$SKILL" >/dev/null 2>&1; then
  ok "内容已与上游一致（pin 仍指向 ${pin}，可把 commit 更新为 ${head_sha}）"
  exit 0
fi

changed="$(diff -rq "$tmp/up/$subpath" "$REPO/skills/$SKILL" 2>/dev/null | wc -l | tr -d ' ')"
printf '    有变化的文件：%s 个\n' "$changed"
diff -rq "$tmp/up/$subpath" "$REPO/skills/$SKILL" 2>/dev/null | sed 's/^/    /' | head -12
echo
diff -ru "$REPO/skills/$SKILL" "$tmp/up/$subpath" 2>/dev/null | head -60 | sed 's/^/    /'
echo

if (( ! APPLY )); then
  warn "预览模式，未改动任何文件。确认后加 --apply"
  exit 0
fi

# 4. 写入
[ -z "$(git -C "$REPO" status --porcelain)" ] || die "工作区不干净，先提交再升级"

step "写入 skills/$SKILL"
rm -rf "$REPO/skills/$SKILL"
cp -R "$tmp/up/$subpath" "$REPO/skills/$SKILL"
ok "已替换"

step "更新 pin 并重算锁文件"
python3 - "$REPO/skills/upstreams.json" "$repo_slug" "$head_sha" "$SKILL" <<'PY'
import json, sys
path, slug, sha, skill = sys.argv[1:5]
data = json.load(open(path, encoding="utf-8"))
for e in data["upstreams"]:
    if e["repo"] == slug and skill in (e.get("skills") or []):
        e["commit"] = sha
data_text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
open(path, "w", encoding="utf-8").write(data_text)
print(f"    {slug} 的 commit → {sha}")
PY
python3 "$REPO/scripts/make-manifest.py" "$REPO" | sed 's/^/    /'

printf '\n下一步：\n'
printf '  1. git diff 检查改动是否合理\n'
printf '  2. make verify   # 锁文件/文档/脱敏/上游一致性\n'
printf '  3. make upstream # 确认上游许可未变\n'
printf '  4. ./scripts/install.sh   # 装到 ~/.dsh 生效\n'
