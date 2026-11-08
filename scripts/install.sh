#!/usr/bin/env bash
# quick-startup 安装器：把仓库里的 skills / 记忆 / 规范 / MCP 配置装进 ~/.dsh
#
#   ./scripts/install.sh              # 安装 / 更新
#   ./scripts/install.sh --dry-run    # 只打印动作
#   DSH_HOME=/tmp/x ./scripts/install.sh   # 装到别处（沙箱验证）
#
# 幂等：重复执行安全。会改动的既有文件先备份到 ~/.dsh/backups/quick-startup-<时间戳>/。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
SKILLS_DST="$DSH_HOME/skills"
BACKUP="$DSH_HOME/backups/quick-startup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$arg（可用 --dry-run / --help）" >&2; exit 2 ;;
  esac
done

b=$'\033[1;34m'; g=$'\033[1;32m'; y=$'\033[1;33m'; r=$'\033[1;31m'; o=$'\033[0m'
step() { printf '%s▸%s %s\n' "$b" "$o" "$*"; }
ok()   { printf '%s✓%s %s\n' "$g" "$o" "$*"; }
warn() { printf '%s!%s %s\n' "$y" "$o" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$r" "$o" "$*" >&2; exit 1; }

run() { if (( DRY_RUN )); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

[ -f "$REPO/AGENTS.md" ] || die "仓库不完整：缺 $REPO/AGENTS.md"
[ -d "$REPO/skills" ]    || die "仓库不完整：缺 $REPO/skills"

printf '\nquick-startup → %s%s\n\n' "$DSH_HOME" "$([[ $DRY_RUN == 1 ]] && echo '  (dry-run)')"

# ── 1. skills ────────────────────────────────────────────────────────────────
step "安装 skills"
run mkdir -p "$SKILLS_DST"
n=0
for dir in "$REPO"/skills/*/; do
  name="$(basename "$dir")"
  if [ ! -f "$dir/SKILL.md" ]; then
    warn "跳过 $name：没有 SKILL.md"
    continue
  fi
  run rm -rf "$SKILLS_DST/$name"
  run cp -R "$dir" "$SKILLS_DST/$name"
  n=$((n + 1))
done
ok "$n 个 skill → $SKILLS_DST"

# ── 2. 记忆：AGENTS.md ───────────────────────────────────────────────────────
step "安装全局记忆 AGENTS.md"
if [ -f "$DSH_HOME/AGENTS.md" ] && cmp -s "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"; then
  ok "已是最新，跳过"
else
  if [ -f "$DSH_HOME/AGENTS.md" ]; then
    run mkdir -p "$BACKUP"
    run cp "$DSH_HOME/AGENTS.md" "$BACKUP/AGENTS.md"
    warn "旧文件已备份：$BACKUP/AGENTS.md"
  fi
  run cp "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
  ok "写入 $DSH_HOME/AGENTS.md"
fi

# ── 3. 规范 ──────────────────────────────────────────────────────────────────
step "安装后端规范"
if cmp -s "$REPO/standards/backend-standards.md" "$DSH_HOME/backend-standards.md" 2>/dev/null; then
  ok "已是最新，跳过"
else
  if [ -f "$DSH_HOME/backend-standards.md" ]; then
    run mkdir -p "$BACKUP"
    run cp "$DSH_HOME/backend-standards.md" "$BACKUP/backend-standards.md"
  fi
  run cp "$REPO/standards/backend-standards.md" "$DSH_HOME/backend-standards.md"
  ok "写入 $DSH_HOME/backend-standards.md"
fi

# ── 4. MCP：CodeGraph ────────────────────────────────────────────────────────
step "接线 MCP（CodeGraph）"
PATCH="$DSH_HOME/cordis.patch.yml"
if grep -q 'mcp-codegraph' "$PATCH" 2>/dev/null; then
  ok "cordis.patch.yml 已有 mcp-codegraph，跳过"
else
  CG_BIN="${CODEGRAPH_BIN:-$(command -v codegraph || true)}"
  if [ -z "$CG_BIN" ]; then
    warn "未找到 codegraph CLI，跳过 MCP 注入"
    warn "装好后重跑：npm i -g @colbymchenry/codegraph && ./scripts/install.sh"
  else
    if [ -f "$PATCH" ]; then
      run mkdir -p "$BACKUP"
      run cp "$PATCH" "$BACKUP/cordis.patch.yml"
    fi
    snippet="$(cat <<EOF

# Added by quick-startup $(date +%Y-%m-%d). CodeGraph MCP for every profile.
- insert:
    - id: mcp-codegraph
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: codegraph
        transport: stdio
        command: $CG_BIN
        args:
          - serve
          - --mcp
EOF
)"
    if (( DRY_RUN )); then
      printf '    [dry-run] append to %s:\n%s\n' "$PATCH" "$snippet"
    else
      printf '%s\n' "$snippet" >> "$PATCH"
    fi
    ok "已注入 mcp-codegraph → $CG_BIN"
  fi
fi

printf '\n完成%s。重启 DSH 或新开会话生效；用 ./scripts/verify.sh 核对。\n\n' \
  "$([[ $DRY_RUN == 1 ]] && echo '（dry-run，未改动任何文件）')"
if [ -d "$BACKUP" ]; then
  printf '备份目录：%s\n\n' "$BACKUP"
fi
