#!/usr/bin/env bash
# quick-startup 集成测试：在临时 DSH_HOME 里真实跑 install / verify / export，断言行为。
#
#   ./tests/run.sh
#   KEEP=1 ./tests/run.sh      # 保留临时目录便于排查
#
# 不依赖网络、不碰真实 ~/.dsh；全部写入 mktemp 目录，退出时清理。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

g=$'\033[1;32m'; r=$'\033[1;31m'; b=$'\033[1;34m'; o=$'\033[0m'
pass=0; fail=0

ok()   { pass=$((pass + 1)); printf '%sPASS%s %s\n' "$g" "$o" "$1"; }
bad()  { fail=$((fail + 1)); printf '%sFAIL%s %s\n' "$r" "$o" "$1"; }
dump() { printf '%s\n' "$1" | tail -10 | sed 's/^/     /'; }
head2() { printf '\n%s▸ %s%s\n' "$b" "$*" "$o"; }

# T：命令必须成功
T() {
  local desc="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "$desc"; else bad "$desc"; dump "$out"; fi
}
# T_fail：命令必须失败（非 0）
T_fail() {
  local desc="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then bad "${desc}（期望失败，实际成功）"; dump "$out"; else ok "$desc"; fi
}
# T_code：命令退出码必须等于期望值
T_code() {
  local desc="$1" want="$2"; shift 2
  local out got
  out="$("$@" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then ok "$desc"; else bad "${desc}（exit=${got}，期望 ${want}）"; dump "$out"; fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/qs-test.XXXXXX")"
trap '[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"' EXIT

# codegraph 桩：可执行，让 MCP 注入与 doctor 的路径检查可离线验证
mkdir -p "$WORK/bin"
printf '#!/bin/sh\n echo "stub 0.0.0"\n' > "$WORK/bin/codegraph"
chmod +x "$WORK/bin/codegraph"
export CODEGRAPH_BIN="$WORK/bin/codegraph"
export DSH_HOME="$WORK/dsh"

head2 "1. 首次安装"
T "install.sh 成功" "$REPO/scripts/install.sh"
T "安装 42 个 skill" test "$(find "$DSH_HOME/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')" -eq 42
T "写入 AGENTS.md 且与仓库一致" cmp -s "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
T "写入 backend-standards.md 且与仓库一致" cmp -s "$REPO/standards/backend-standards.md" "$DSH_HOME/backend-standards.md"
T "写入 GitHub 记忆 github-usage.md" cmp -s "$REPO/memory/github.md" "$DSH_HOME/github-usage.md"
T "注入 mcp-codegraph 并使用 CODEGRAPH_BIN" grep -q "$CODEGRAPH_BIN" "$DSH_HOME/cordis.patch.yml"
T "注入内容含 serverName" grep -q 'serverName: codegraph' "$DSH_HOME/cordis.patch.yml"
T "首次安装不产生备份目录" test ! -d "$DSH_HOME/backups"

head2 "2. 幂等与 dry-run"
T "二次安装成功" "$REPO/scripts/install.sh"
T "二次安装不新增备份" test ! -d "$DSH_HOME/backups"
T "二次安装未改动 AGENTS.md" cmp -s "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
before="$(find "$DSH_HOME" -type f -exec cksum {} + 2>/dev/null | sort | cksum)"
T "dry-run 成功" "$REPO/scripts/install.sh" --dry-run
after="$(find "$DSH_HOME" -type f -exec cksum {} + 2>/dev/null | sort | cksum)"
T "--dry-run 不改动任何文件" test "$before" = "$after"

head2 "3. 覆盖前备份"
printf '\n<!-- test marker -->\n' >> "$DSH_HOME/AGENTS.md"
printf '\n<!-- gh marker -->\n' >> "$DSH_HOME/github-usage.md"
T "覆盖前备份：install 成功" "$REPO/scripts/install.sh"
T "生成备份目录" test -d "$DSH_HOME/backups"
T "备份保留被覆盖内容" grep -rq 'test marker' "$DSH_HOME/backups"
T "AGENTS.md 仓库内容完整" python3 "$REPO/scripts/check_agents.py" "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
T "本机改动未被吞掉" grep -q 'test marker' "$DSH_HOME/AGENTS.md"
T "GitHub 记忆也备份并恢复" cmp -s "$REPO/memory/github.md" "$DSH_HOME/github-usage.md"
T "备份保留 GitHub 记忆改动" grep -rq 'gh marker' "$DSH_HOME/backups"

T "GitHub 记忆含账号与 LICENSE 坑" bash -c "grep -q 'jasoncai0' '$DSH_HOME/github-usage.md' && grep -q 'NOASSERTION' '$DSH_HOME/github-usage.md'"

head2 "4. verify.sh 全绿"
T "verify --require-install 成功" "$REPO/scripts/verify.sh" --require-install
T "汇总行为 fail=0" bash -c "'$REPO/scripts/verify.sh' --require-install 2>&1 | grep -q 'fail=0'"

head2 "5. 漂移检测"
printf '\ndrift\n' >> "$DSH_HOME/skills/seo/SKILL.md"
T_fail "内容漂移时 verify 失败" "$REPO/scripts/verify.sh"
T "失败输出指出 seo" bash -c "'$REPO/scripts/verify.sh' 2>&1 | grep -q 'seo'"
rm -rf "$DSH_HOME/skills/seo"
cp -R "$REPO/skills/seo" "$DSH_HOME/skills/seo"
T "复原后 verify 成功" "$REPO/scripts/verify.sh" --require-install

head2 "6. 密钥扫描"
SCAN="$WORK/scan-repo"
cp -R "$REPO" "$SCAN"
# 令牌按片段拼接，避免测试文件自身被扫描命中
printf 'token=%s%s\n' "gh" "p_abcdefghijklmnopqrstuvwxyz0123456789" > "$SCAN/skills/leak-fixture.txt"
T_fail "植入假令牌后 verify 失败" env DSH_HOME="$DSH_HOME" "$SCAN/scripts/verify.sh"
T "输出指名命中文件" bash -c "DSH_HOME='$DSH_HOME' '$SCAN/scripts/verify.sh' 2>&1 | grep -q 'leak-fixture'"
rm -f "$SCAN/skills/leak-fixture.txt"
T "移除后 verify 成功" env DSH_HOME="$DSH_HOME" "$SCAN/scripts/verify.sh"
printf '\n---\n\n本许可仅覆盖原创部分。\n' >> "$SCAN/LICENSE"
T_fail "LICENSE 被追加说明后 verify 失败" env DSH_HOME="$DSH_HOME" "$SCAN/scripts/verify.sh"
T "失败原因指向 LICENSE" bash -c "DSH_HOME='$DSH_HOME' '$SCAN/scripts/verify.sh' 2>&1 | grep -q 'MIT'"
git -C "$SCAN" checkout -- LICENSE 2>/dev/null || cp "$REPO/LICENSE" "$SCAN/LICENSE"
printf '\n联系邮箱：someone@%s\n' "gmail.com" >> "$SCAN/README.md"
T_fail "README 出现个人邮箱后 verify 失败" env DSH_HOME="$DSH_HOME" "$SCAN/scripts/verify.sh"
T "失败原因指向个人邮箱" bash -c "DSH_HOME='$DSH_HOME' '$SCAN/scripts/verify.sh' 2>&1 | grep -q '个人邮箱'"
cp "$REPO/README.md" "$SCAN/README.md"

head2 "7. 反向导出"
cp -R "$REPO" "$WORK/export-repo"
printf '\nlocal tweak\n' >> "$DSH_HOME/skills/seo/SKILL.md"
T "export-from-local 成功" env DSH_HOME="$DSH_HOME" "$WORK/export-repo/scripts/export-from-local.sh"
T "改动回流到仓库副本" grep -q 'local tweak' "$WORK/export-repo/skills/seo/SKILL.md"
T "导出后副本 verify 通过" env DSH_HOME="$DSH_HOME" "$WORK/export-repo/scripts/verify.sh"

head2 "8. 环境体检 doctor"
T "doctor 成功后退出 0" env DSH_HOME="$DSH_HOME" "$REPO/scripts/doctor.sh"
T "doctor 输出体检结果" bash -c "DSH_HOME='$DSH_HOME' '$REPO/scripts/doctor.sh' 2>&1 | grep -q '体检结果'"
mv "$DSH_HOME/AGENTS.md" "$DSH_HOME/AGENTS.md.bak"
T_fail "doctor 能发现缺失的 AGENTS.md" env DSH_HOME="$DSH_HOME" "$REPO/scripts/doctor.sh"
mv "$DSH_HOME/AGENTS.md.bak" "$DSH_HOME/AGENTS.md"
T "还原后 doctor 恢复通过" env DSH_HOME="$DSH_HOME" "$REPO/scripts/doctor.sh"
env DSH_HOME="$DSH_HOME" "$REPO/scripts/doctor.sh" --json > "$WORK/doctor.json" 2>/dev/null
T "doctor --json 可解析且 fail=0" python3 -c "import json,sys; d=json.load(open('$WORK/doctor.json')); sys.exit(0 if d['fail']==0 and d['pass']>0 else 1)"

head2 "9. 许可证守卫"
T "仓库 LICENSE 通过" python3 "$REPO/scripts/check_license.py" "$REPO"
T "上游许可快照齐全" test -f "$REPO/licenses/README.md"

head2 "10. 参数与边界"
T_code "install.sh 未知参数返回 2" 2 "$REPO/scripts/install.sh" --bogus
T "install.sh --help 返回 0" "$REPO/scripts/install.sh" --help
T_code "verify.sh 未知参数返回 2" 2 "$REPO/scripts/verify.sh" --bogus
T "verify.sh --help 返回 0" "$REPO/scripts/verify.sh" --help
T "DSH_HOME 含空格可安装" env DSH_HOME="$WORK/with space/dsh" "$REPO/scripts/install.sh"
T "含空格的安装目录 verify 成功" env DSH_HOME="$WORK/with space/dsh" "$REPO/scripts/verify.sh" --require-install
T "purge_history --help 返回 0" "$REPO/scripts/purge_history.sh" --help
T_code "purge_history 未知参数返回 2" 2 "$REPO/scripts/purge_history.sh" --bogus
syntax_ok() { for f in "$REPO"/scripts/*.sh "$REPO"/tests/run.sh; do bash -n "$f" || return 1; done; }
T "所有脚本语法正确" syntax_ok

head2 "11. AGENTS.md 合并（不吞本机追加）"
printf '\n## 本机笔记\n\n只属于这台机器的一行。\n' >> "$DSH_HOME/AGENTS.md"
T "带本机笔记重装成功" "$REPO/scripts/install.sh"
T "仓库内容仍完整" python3 "$REPO/scripts/check_agents.py" "$REPO/AGENTS.md" "$DSH_HOME/AGENTS.md"
T "本机追加被保留" grep -q '只属于这台机器的一行' "$DSH_HOME/AGENTS.md"
T "标记段只出现一次" test "$(grep -c '本机追加（安装器保留）' "$DSH_HOME/AGENTS.md")" -eq 1
T "再次重装不叠加" "$REPO/scripts/install.sh"
T "仍只有一处标记段" test "$(grep -c '本机追加（安装器保留）' "$DSH_HOME/AGENTS.md")" -eq 1

printf '\n%s结果%s  pass=%d  fail=%d\n' "$b" "$o" "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
