#!/usr/bin/env bash
# 反向同步：~/.dsh → 仓库。本机改完 skill / 规范后跑一次，再 git commit。
#
#   ./scripts/export-from-local.sh
#
# 注意：AGENTS.md 不自动回写（仓库版路径是可移植的 ~/.dsh/...，本机版可能是绝对路径），
# 需要在两边手工确认后再改仓库文件。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
SRC="$DSH_HOME/skills"

g=$'\033[1;32m'; y=$'\033[1;33m'; b=$'\033[1;34m'; o=$'\033[0m'
step() { printf '%s▸%s %s\n' "$b" "$o" "$*"; }

[ -d "$SRC" ] || { echo "找不到 $SRC" >&2; exit 1; }

step "导出 skills（解引用软链）"
n=0
for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || { printf '%s!%s 跳过 %s（无 SKILL.md）\n' "$y" "$o" "$name"; continue; }
  rm -rf "$REPO/skills/$name"
  cp -RL "$dir" "$REPO/skills/$name"
  [ -L "$dir" ] && printf '    %s 原本是软链 → 实体拷贝 %s\n' "$name" "$(readlink "$dir")"
  n=$((n + 1))
done
printf '%s✓%s 导出 %d 个 skill\n' "$g" "$o" "$n"

step "删除本机已不存在的 skill"
removed=0
for dir in "$REPO"/skills/*/; do
  name="$(basename "$dir")"
  if [ ! -d "$SRC/$name" ]; then
    printf '    - %s\n' "$name"
    rm -rf "$dir"
    removed=$((removed + 1))
  fi
done
printf '%s✓%s 删除 %d 个\n' "$g" "$o" "$removed"

step "导出规范"
cp "$DSH_HOME/backend-standards.md" "$REPO/standards/backend-standards.md"
printf '%s✓%s standards/backend-standards.md\n' "$g" "$o"

step "重新生成 manifest"
python3 "$REPO/scripts/make-manifest.py" "$REPO"

printf '\n下一步：git -C %s status  # 确认 diff 后提交\n' "$REPO"
printf '%s!%s AGENTS.md 需人工比对：diff %s/AGENTS.md %s/AGENTS.md\n' "$y" "$o" "$REPO" "$DSH_HOME"
