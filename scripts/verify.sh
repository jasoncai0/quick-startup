#!/usr/bin/env bash
# quick-startup 校验器：仓库完整性 + 文档一致性 + 本机安装一致性 + 密钥扫描。
#
#   ./scripts/verify.sh                  # 仓库检查；已安装则顺带查一致性
#   ./scripts/verify.sh --require-install # 未安装即判失败（部署后自检用）
#
# 退出码：0 全过；1 有失败。可直接挂 CI。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
SKILLS_DST="$DSH_HOME/skills"
PATTERNS="$REPO/scripts/secret-patterns.txt"
REQUIRE_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --require-install) REQUIRE_INSTALL=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

g=$'\033[1;32m'; r=$'\033[1;31m'; y=$'\033[1;33m'; b=$'\033[1;34m'; o=$'\033[0m'
pass=0; fail=0; skip=0

ok()   { pass=$((pass + 1)); printf '%sPASS%s %s\n' "$g" "$o" "$1"; }
bad()  { fail=$((fail + 1)); printf '%sFAIL%s %s\n' "$r" "$o" "$1"; }
skipping() { skip=$((skip + 1)); printf '%sSKIP%s %s\n' "$y" "$o" "$1"; }
note() { printf '     %s\n' "$*" | head -12; }
head2() { printf '\n%s▸ %s%s\n' "$b" "$*" "$o"; }

check() { # check <描述> <命令...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
check_out() { # 同 check，但失败时打印命令输出
  local desc="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "$desc"; else bad "$desc"; note "$out"; fi
}

command -v python3 >/dev/null 2>&1 || { echo "需要 python3" >&2; exit 2; }

head2 "1. 仓库完整性"
repo_skills=$(find "$REPO/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
manifest_rows=$(( $(wc -l < "$REPO/skills/manifest.tsv" 2>/dev/null | tr -d ' ') - 1 ))
check "skills/ 目录数与锁文件一致（$repo_skills / ${manifest_rows}）" test "$repo_skills" -eq "$manifest_rows"
check "至少存在一个 skill" test "$repo_skills" -gt 0

missing_skillmd=0
for d in "$REPO"/skills/*/; do [ -f "${d}SKILL.md" ] || missing_skillmd=$((missing_skillmd + 1)); done
check "每个 skill 都有 SKILL.md（缺失 ${missing_skillmd}）" [ "$missing_skillmd" -eq 0 ]

std_lines=$(wc -l < "$REPO/standards/backend-standards.md" 2>/dev/null | tr -d ' ')
check "规范存在且 ≥200 行（$std_lines 行）" [ "${std_lines:-0}" -ge 200 ]
check "AGENTS.md 含 CodeGraph 围栏标记" grep -q 'CODEGRAPH_START' "$REPO/AGENTS.md"
check "AGENTS.md 指向后端规范" grep -q 'backend-standards.md' "$REPO/AGENTS.md"
check "skills/SOURCES.md 存在" test -s "$REPO/skills/SOURCES.md"
check_out "锁文件与仓库内容一致" python3 "$REPO/scripts/check_manifest.py" --repo "$REPO"
check_out "文档与实现一致" python3 "$REPO/scripts/check_docs.py" "$REPO"
check_out "LICENSE 为 MIT 原文且许可快照齐全" python3 "$REPO/scripts/check_license.py" "$REPO"
check_out "脱敏检查（无个人信息）" python3 "$REPO/scripts/check_privacy.py" "$REPO"

locale_hits=$(grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$REPO"/scripts/*.sh "$REPO"/tests/run.sh 2>/dev/null | head -3)
if [ -z "$locale_hits" ]; then
  ok "shell 脚本无「变量紧邻非 ASCII」写法（locale 安全）"
else
  bad "存在 locale 风险写法：\$var 后紧跟全角字符，请改成 \${var}"
  note "$locale_hits"
fi

head2 "2. 本机安装一致性（${DSH_HOME}）"
if [ ! -d "$SKILLS_DST" ]; then
  if [ "$REQUIRE_INSTALL" -eq 1 ]; then
    bad "未安装：$SKILLS_DST 不存在（先跑 scripts/install.sh）"
  else
    skipping "未安装，跳过（加 --require-install 可强制）"
  fi
else
  inst_skills=0
  for d in "$SKILLS_DST"/*/; do [ -d "$d" ] && inst_skills=$((inst_skills + 1)); done
  check "已安装 skill 数与仓库一致（$inst_skills / ${repo_skills}）" [ "$inst_skills" -eq "$repo_skills" ]
  check_out "每个 skill 与锁文件逐字节一致" python3 "$REPO/scripts/check_manifest.py" --repo "$REPO" --installed "$SKILLS_DST"
  check_out "记忆块与编号约定与仓库一致" python3 "$REPO/scripts/check_agents.py" "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
  check "已安装规范与仓库一致" cmp -s "$REPO/standards/backend-standards.md" "$DSH_HOME/backend-standards.md"
  check "已安装 GitHub 记忆与仓库一致" cmp -s "$REPO/memory/github.md" "$DSH_HOME/github-usage.md"
  check "cordis.patch.yml 已注入 mcp-codegraph" grep -q 'mcp-codegraph' "$DSH_HOME/cordis.patch.yml"
fi

head2 "3. 密钥扫描"
if [ ! -f "$PATTERNS" ]; then
  skipping "缺 $PATTERNS"
else
  hits="$(cd "$REPO" && grep -rIiE -f "$PATTERNS" . \
            --exclude-dir=.git --exclude-dir=node_modules \
            --exclude='secret-patterns.txt' 2>/dev/null | head -5)"
  if [ -z "$hits" ]; then ok "未发现疑似密钥"; else bad "发现疑似密钥"; note "$hits"; fi
fi

printf '\n%s结果%s  pass=%d  fail=%d  skip=%d\n' "$b" "$o" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
