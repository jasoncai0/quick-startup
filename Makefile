# quick-startup —— 日常入口
# 依赖：bash 3.2+、python3（脚本里没有别的东西）
.DEFAULT_GOAL := help
.PHONY: help all install verify test export manifest docs license privacy upstream upgrade doctor purge-check lint secret clean

help: ## 显示可用目标
	@awk 'BEGIN {FS = ":.*## "; printf "\n用法：make <目标>\n\n"} \
	     /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

all: lint test verify ## 本地全量门禁（= CI 的 test+lint）

install: ## 安装/更新到 ~/.dsh
	./scripts/install.sh $(ARGS)

verify: ## 校验仓库 + 本机安装一致性
	./scripts/verify.sh

test: ## 跑集成测试
	./tests/run.sh

export: ## 从 ~/.dsh 反向导出到仓库
	./scripts/export-from-local.sh

manifest: ## 重新生成 skills/manifest.tsv
	python3 scripts/make-manifest.py .

docs: ## 检查 README / VERSION / CHANGELOG 一致性
	python3 scripts/check_docs.py .

license: ## 校验 LICENSE 与上游许可快照
	python3 scripts/check_license.py .

privacy: ## 脱敏检查（工作区 + 全部历史）
	python3 scripts/check_privacy.py . --history

upstream: ## 复核上游 HEAD 与许可证（需 gh 认证）
	python3 scripts/check_upstream.py . --online

upgrade: ## 升级单个 skill：make upgrade SKILL=<name> [ARGS=--apply]
	./scripts/upgrade_skill.sh $(SKILL) $(ARGS)

doctor: ## 环境体检（只读）：安装完整性、断链、MCP、工具链
	./scripts/doctor.sh

purge-check: ## 检查是否还有可被 SHA 访问的旧 commit（只读）
	./scripts/purge_history.sh --check

lint: ## shellcheck + ruff + python 语法
	@command -v shellcheck >/dev/null 2>&1 \
	  && shellcheck -x scripts/*.sh tests/run.sh \
	  || echo "（未安装 shellcheck，跳过；CI 会跑）"
	@python3 -m py_compile scripts/*.py && echo "python 语法 OK"
	@if command -v ruff >/dev/null 2>&1; then ruff check --select E9,F scripts/; \
	 else echo "（未安装 ruff，跳过静态检查；CI 会跑）"; fi

secret: ## 只跑密钥扫描
	@grep -rIiE -f scripts/secret-patterns.txt . \
	  --exclude-dir=.git --exclude-dir=node_modules \
	  --exclude='secret-patterns.txt' \
	  && { echo "发现疑似密钥"; exit 1; } || echo "未发现疑似密钥"

clean: ## 清理编译缓存
	find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	find . -name '*.pyc' -delete 2>/dev/null || true
	@echo "已清理"
