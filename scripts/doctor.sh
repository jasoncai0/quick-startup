#!/usr/bin/env bash
# quick-startup 环境体检：只读，不改任何文件。
#
#   ./scripts/doctor.sh           # 人读格式，有问题时退出码 1
#   ./scripts/doctor.sh --json    # 机器可读（供会话启动检查用）
#
# 检查本机这套环境是否「装好了、接对了、没断链」。
# 可选依赖（codegraph / gh）缺失只记 WARN，不判失败——换机器时它们可能是后装的。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
JSON=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：${arg}" >&2; exit 2 ;;
  esac
done

if (( JSON )); then
  ok_sym='OK'; warn_sym='WARN'; fail_sym='FAIL'
else
  ok_sym=$'\033[1;32m✓\033[0m'; warn_sym=$'\033[1;33m!\033[0m'; fail_sym=$'\033[1;31m✗\033[0m'
fi

fails=0; warns=0; passes=0
json_items="" 

emit() { # emit <level> <名称> <细节>
  local level="$1" name="$2" detail="${3:-}"
  case "$level" in
    ok) passes=$((passes + 1)) ;;
    warn) warns=$((warns + 1)) ;;
    fail) fails=$((fails + 1)) ;;
  esac
  if (( JSON )); then
    item="{\"level\":\"${level}\",\"name\":\"${name}\",\"detail\":\"${detail}\"}"
    if [ -z "$json_items" ]; then json_items="$item"; else json_items="${json_items},${item}"; fi
  else
    case "$level" in
      ok)   printf '%s %-34s %s\n' "$ok_sym" "$name" "$detail" ;;
      warn) printf '%s %-34s %s\n' "$warn_sym" "$name" "$detail" ;;
      fail) printf '%s %-34s %s\n' "$fail_sym" "$name" "$detail" ;;
    esac
  fi
}

# 1. DSH_HOME
if [ -d "$DSH_HOME" ]; then
  if [ -w "$DSH_HOME" ]; then emit ok "DSH_HOME 可写" "$DSH_HOME"
  else emit fail "DSH_HOME 不可写" "$DSH_HOME"; fi
else
  emit fail "DSH_HOME 不存在" "${DSH_HOME}（先跑 scripts/install.sh）"
fi

# 2. skills 数量 vs 锁文件
expected=0
if [ -f "$REPO/skills/manifest.tsv" ]; then
  expected=$(($(wc -l < "$REPO/skills/manifest.tsv" | tr -d ' ') - 1))
fi
installed=0
if [ -d "${DSH_HOME}/skills" ]; then
  for d in "${DSH_HOME}"/skills/*/; do [ -d "$d" ] && installed=$((installed + 1)); done
fi
if [ "${installed}" -eq "${expected}" ] && [ "${expected}" -gt 0 ]; then
  emit ok "skill 数量一致" "${installed}/${expected}"
else
  emit fail "skill 数量不一致" "${installed}/${expected}（跑 make export 或重装）"
fi

# 3. 记忆文件
if python3 "$REPO/scripts/check_agents.py" "$REPO/AGENTS.md" "${DSH_HOME}/AGENTS.md" >/dev/null 2>&1; then
  emit ok "AGENTS.md 记忆块完整" "CodeGraph + 编号约定"
else
  emit fail "AGENTS.md 与本仓库不一致" "跑 make install"
fi

if cmp -s "$REPO/memory/github.md" "${DSH_HOME}/github-usage.md" 2>/dev/null; then
  emit ok "GitHub 记忆已安装" "github-usage.md"
else
  emit warn "GitHub 记忆缺失或过期" "跑 make install"
fi

if cmp -s "$REPO/standards/backend-standards.md" "${DSH_HOME}/backend-standards.md" 2>/dev/null; then
  emit ok "后端规范已安装" "backend-standards.md"
else
  emit warn "后端规范缺失或过期" "跑 make install"
fi

# 4. 断链（软链安装的 skill 上游被删就会断）
broken=""
if [ -d "${DSH_HOME}/skills" ]; then
  broken=$(find "${DSH_HOME}/skills" -maxdepth 2 -type l ! -exec test -e {} \; -print 2>/dev/null | head -5)
fi
if [ -z "$broken" ]; then emit ok "无断链" "skills/ 下软链均有效"
else emit warn "存在断链" "$(printf '%s' "$broken" | tr '\n' ' ')"; fi

# 5. CodeGraph（可选）
cg=$(command -v codegraph 2>/dev/null || true)
if [ -n "$cg" ]; then
  ver=$("$cg" --version 2>/dev/null | head -1)
  emit ok "codegraph CLI" "${cg} ${ver}"
  tfile="$HOME/.codegraph/telemetry.json"
  if [ ! -f "$tfile" ]; then
    emit warn "codegraph 无遥测配置" "${tfile}"
  elif grep -qE '"enabled"[[:space:]]*:[[:space:]]*false' "$tfile"; then
    emit ok "codegraph 遥测" "已关闭"
  elif grep -qE '"enabled"[[:space:]]*:[[:space:]]*true' "$tfile"; then
    emit warn "codegraph 遥测已开启" "codegraph telemetry off"
  else
    emit warn "codegraph 遥测状态未知" "${tfile}"
  fi
else
  emit warn "codegraph CLI 未安装" "MCP 会不可用；npm i -g @colbymchenry/codegraph"
fi

# 6. MCP 接线
patch="${DSH_HOME}/cordis.patch.yml"
if grep -q 'mcp-codegraph' "$patch" 2>/dev/null; then
  cmd=$(grep -A8 'id: mcp-codegraph' "$patch" 2>/dev/null | sed -n 's/^ *command: *//p' | head -1)
  if [ -n "$cmd" ] && [ -x "$cmd" ]; then
    emit ok "MCP codegraph 已接线" "$cmd"
  else
    emit fail "MCP command 路径不可执行" "${cmd:-<空>}"
  fi
else
  emit warn "MCP 未接线" "跑 make install（需先装 codegraph）"
fi

# 7. Python
if command -v python3 >/dev/null 2>&1; then
  pv=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)
  if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
    emit ok "python3" "${pv}"
  else
    emit fail "python3 版本过低" "${pv}（需 ≥3.8）"
  fi
else
  emit fail "python3 缺失" "脚本需要 python3"
fi

# 8. gh（可选）
ghbin=$(command -v gh 2>/dev/null || true)
if [ -z "$ghbin" ]; then
  for cand in "${REPO}"/../.tools/gh_*/bin/gh; do
    if [ -x "$cand" ]; then ghbin="$(cd "$(dirname "$cand")" && pwd -P)/gh"; break; fi
  done
fi
if [ -n "$ghbin" ]; then
  emit ok "gh CLI" "${ghbin}"
else
  emit warn "gh CLI 不在 PATH" "GitHub 操作需指定绝对路径"
fi

# 汇总
if (( JSON )); then
  printf '{"pass":%d,"warn":%d,"fail":%d,"checks":[%s]}\n' \
    "${passes}" "${warns}" "${fails}" "$json_items"
else
  printf '\n体检结果：%d 通过，%d 警告，%d 失败\n' "${passes}" "${warns}" "${fails}"
fi
[ "${fails}" -eq 0 ] || exit 1
