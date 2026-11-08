#!/usr/bin/env bash
# quick-startup 校验器：仓库完整性 + 本机安装一致性 + 密钥扫描。
# 退出码：0 全过；1 有失败。可直接挂 CI。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
SKILLS_DST="$DSH_HOME/skills"
PATTERNS="$REPO/scripts/secret-patterns.txt"

g=$'\033[1;32m'; r=$'\033[1;31m'; y=$'\033[1;33m'; b=$'\033[1;34m'; o=$'\033[0m'
pass=0; fail=0; skip=0

check() { # check <描述> <命令...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1)); printf '%sPASS%s %s\n' "$g" "$o" "$desc"
  else
    fail=$((fail + 1)); printf '%sFAIL%s %s\n' "$r" "$o" "$desc"
  fi
}
note() { printf '%s     %s%s\n' "$y" "$*" "$o"; }
head2() { printf '\n%s▸ %s%s\n' "$b" "$*" "$o"; }

repo_skills=$(find "$REPO/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
inst_skills=0
[ -d "$SKILLS_DST" ] && inst_skills=$(find "$SKILLS_DST" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

head2 "1. 仓库完整性"
check "skills/ 有 42 个目录（实际 $repo_skills）" [ "$repo_skills" -eq 42 ]
missing_skillmd=0
for d in "$REPO"/skills/*/; do [ -f "${d}SKILL.md" ] || missing_skillmd=$((missing_skillmd + 1)); done
check "每个 skill 都有 SKILL.md（缺失 $missing_skillmd）" [ "$missing_skillmd" -eq 0 ]
check "standards/backend-standards.md 存在且 ≥200 行" \
  [ "$(wc -l < "$REPO/standards/backend-standards.md" 2>/dev/null | tr -d ' ')" -ge 200 ]
check "AGENTS.md 含 CodeGraph 围栏标记" grep -q 'CODEGRAPH_START' "$REPO/AGENTS.md"
check "AGENTS.md 指向后端规范" grep -q 'backend-standards.md' "$REPO/AGENTS.md"
check "skills/SOURCES.md 存在" [ -s "$REPO/skills/SOURCES.md" ]
check "skills/manifest.tsv 行数与目录数一致" \
  test "$(tail -n +2 "$REPO/skills/manifest.tsv" 2>/dev/null | wc -l | tr -d ' ')" -eq "$repo_skills"

head2 "2. 本机安装一致性（$DSH_HOME）"
if [ ! -d "$SKILLS_DST" ]; then
  fail=$((fail + 1)); printf '%sFAIL%s 未安装：%s 不存在（先跑 scripts/install.sh）\n' "$r" "$o" "$SKILLS_DST"
else
  check "已安装 skill 数与仓库一致（$inst_skills / $repo_skills）" [ "$inst_skills" -eq "$repo_skills" ]
  drifted=""
  while IFS= read -r dir; do
    name="$(basename "$dir")"
    if [ ! -d "$SKILLS_DST/$name" ]; then drifted="$drifted $name(缺)"; continue; fi
    diff -rq "$dir" "$SKILLS_DST/$name" >/dev/null 2>&1 || drifted="$drifted $name"
  done < <(find "$REPO/skills" -maxdepth 1 -mindepth 1 -type d)
  if [ -z "$drifted" ]; then
    pass=$((pass + 1)); printf '%sPASS%s 每个 skill 内容与仓库逐字节一致\n' "$g" "$o"
  else
    fail=$((fail + 1)); printf '%sFAIL%s 内容漂移：%s\n' "$r" "$o" "$drifted"; note "跑 ./scripts/export-from-local.sh 反向导出，或重装"
  fi
  check "已安装 AGENTS.md 与仓库一致" cmp -s "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
  check "已安装规范与仓库一致" cmp -s "$REPO/standards/backend-standards.md" "$DSH_HOME/backend-standards.md"
  check "cordis.patch.yml 已注入 mcp-codegraph" grep -q 'mcp-codegraph' "$DSH_HOME/cordis.patch.yml"
fi

head2 "3. 密钥扫描"
if [ ! -f "$PATTERNS" ]; then
  skip=$((skip + 1)); printf '%sSKIP%s 缺 %s\n' "$y" "$o" "$PATTERNS"
else
  hits="$(cd "$REPO" && grep -rIiE -f "$PATTERNS" . \
            --exclude-dir=.git --exclude-dir=node_modules \
            --exclude='secret-patterns.txt' 2>/dev/null | head -5)"
  if [ -z "$hits" ]; then
    pass=$((pass + 1)); printf '%sPASS%s 未发现疑似密钥\n' "$g" "$o"
  else
    fail=$((fail + 1)); printf '%sFAIL%s 发现疑似密钥：\n%s\n' "$r" "$o" "$hits"
  fi
fi

printf '\n%s结果%s  pass=%d  fail=%d  skip=%d\n' "$b" "$o" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
