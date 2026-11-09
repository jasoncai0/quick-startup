#!/usr/bin/env bash
# 彻底清除一个公开仓库的历史：删除并重建同名仓库，再推送当前干净历史。
#
# 为什么需要：`git push --force` 只移动分支指针，旧 commit 仍可通过 SHA 访问
# （GitHub 不立即回收悬空对象）。要让旧 SHA 真正 404，只有删库重建，
# 或让 GitHub Support 清理。
#
#   ./scripts/purge_history.sh --check                  # 只体检：列出现在还能访问的旧 SHA
#   ./scripts/purge_history.sh --yes-i-mean-it          # 真正执行（删库 → 重建 → 推送 → 验证）
#
# 前置：
#   - 已安装 gh，且 GH_CONFIG_DIR 指向登录态；
#   - token 需要 delete_repo scope：`gh auth refresh -h github.com -s delete_repo`
#   - 本地工作区干净（有未提交改动会拒绝执行）
#
# 安全设计：默认绝不删除，必须显式 --yes-i-mean-it；执行前自动打 bundle 备份。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OWNER="${OWNER:-jasoncai0}"
NAME="${NAME:-quick-startup}"
SLUG="${OWNER}/${NAME}"
GH_BIN="${GH_BIN:-$(command -v gh || true)}"
MODE="check"
TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --yes-i-mean-it) MODE="purge"; shift ;;
    --sha)
      [ $# -ge 2 ] || { echo "--sha 需要参数" >&2; exit 2; }
      TARGETS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

# 目标 SHA 的来源：命令行 --sha、本地 .purge-targets（重写前记录），
# 以及 reflog 里不在当前主线上的 commit（gc 之前有效）。
TARGET_FILE="$REPO/.purge-targets"
if [ -f "$TARGET_FILE" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && TARGETS+=("$line")
  done < "$TARGET_FILE"
fi

b=$'\033[1;34m'; g=$'\033[1;32m'; y=$'\033[1;33m'; r=$'\033[1;31m'; o=$'\033[0m'
step() { printf '%s▸%s %s\n' "$b" "$o" "$*"; }
ok()   { printf '%s✓%s %s\n' "$g" "$o" "$*"; }
warn() { printf '%s!%s %s\n' "$y" "$o" "$*"; }
die()  { printf '%s✗%s %s\n' "$r" "$o" "$*" >&2; exit 1; }

[ -n "$GH_BIN" ] || die "找不到 gh；设置 GH_BIN 指向二进制"
export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$REPO/../.tools/ghconfig}"

scopes="$("$GH_BIN" auth status 2>&1 | grep -i scopes || true)"
has_delete=0
case "$scopes" in *delete_repo*) has_delete=1 ;; esac

step "仓库：${SLUG}"
if ! "$GH_BIN" api "repos/${SLUG}" --jq '.name' >/dev/null 2>&1; then
  die "仓库不存在或无权访问：${SLUG}"
fi

# 当前远端可达的旧 commit（重写前的那批）
step "检查悬空对象"
current="$(git -C "$REPO" rev-parse HEAD)"
live=" $(git -C "$REPO" rev-list HEAD 2>/dev/null | tr '\n' ' ') "
for sha in $(git -C "$REPO" reflog --all --format='%H' 2>/dev/null | sort -u | head -60); do
  [ "$sha" = "$current" ] && continue
  case "$live" in *" $sha "*) continue ;; esac
  TARGETS+=("$sha")
done

gone=0
for sha in "${TARGETS[@]}"; do
  [ -n "$sha" ] || continue
  if "$GH_BIN" api "repos/${SLUG}/commits/${sha}" --jq '.sha' >/dev/null 2>&1; then
    printf '    仍可访问：%s\n' "${sha:0:7}"
    gone=$((gone + 1))
  fi
done
if [ "$gone" -eq 0 ]; then
  ok "没有仍可访问的旧 commit"
else
  warn "有 ${gone} 个旧 commit 仍可通过 SHA 访问——需要删库重建才能清除"
fi

if [ "$MODE" = "check" ]; then
  printf '\n（--check 模式，未做任何修改；确认要清除请加 --yes-i-mean-it）\n'
  [ "$has_delete" -eq 1 ] || warn "当前 token 缺 delete_repo scope：gh auth refresh -h github.com -s delete_repo"
  exit 0
fi

# ── 真正执行 ────────────────────────────────────────────────────────────────
[ "$has_delete" -eq 1 ] || die "token 缺 delete_repo scope：gh auth refresh -h github.com -s delete_repo"
[ -z "$(git -C "$REPO" status --porcelain)" ] || die "工作区不干净，先提交或 stash"

STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE="$HOME/${NAME}-clean-${STAMP}.bundle"
step "备份当前干净历史"
git -C "$REPO" bundle create "$BUNDLE" --all >/dev/null 2>&1 || die "bundle 备份失败，中止"
ok "$BUNDLE"

meta="$("$GH_BIN" api "repos/${SLUG}" --jq '[.description, (.topics|join(","))] | @tsv')" || die "读取元数据失败"
desc="$(printf '%s' "$meta" | cut -f1)"
topics="$(printf '%s' "$meta" | cut -f2)"
step "保存元数据"
ok "description / topics / visibility=public 已记录"

step "删除仓库"
"$GH_BIN" repo delete "$SLUG" --yes >/dev/null 2>&1 || die "删除失败（scope 或权限问题）"
ok "已删除 ${SLUG}"

step "重建同名仓库"
"$GH_BIN" repo create "$SLUG" --public --description "$desc" >/dev/null 2>&1 || die "重建失败"
ok "已重建"

if [ -n "$topics" ]; then
  IFS=',' read -r -a topic_arr <<< "$topics"
  args=()
  for t in "${topic_arr[@]}"; do [ -n "$t" ] && args+=(--add-topic "$t"); done
  [ "${#args[@]}" -eq 0 ] || "$GH_BIN" repo edit "$SLUG" "${args[@]}" >/dev/null 2>&1
fi
ok "topics 已恢复"

step "推送干净历史"
git -C "$REPO" remote set-url origin "https://github.com/${SLUG}.git"
git -C "$REPO" push -u origin main >/dev/null 2>&1 || die "推送失败"
ok "$(git -C "$REPO" rev-parse --short HEAD) → origin/main"

step "复核"
sleep 3
still=0
for sha in "${TARGETS[@]}"; do
  [ -n "$sha" ] || continue
  "$GH_BIN" api "repos/${SLUG}/commits/${sha}" --jq '.sha' >/dev/null 2>&1 && still=$((still + 1))
done
if [ "$still" -eq 0 ]; then
  ok "旧 commit 已全部不可达"
else
  warn "仍有 ${still} 个 SHA 可达（GitHub 缓存，可能需数分钟或 Support 清理）"
fi
printf '\n完成。备份：%s\n' "$BUNDLE"
