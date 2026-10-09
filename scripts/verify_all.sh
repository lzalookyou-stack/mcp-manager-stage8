#!/usr/bin/env bash
# 阶段 8：一键跑全部验证（静态检查 + 测试套件 + MCP stdio 冒烟）
#
# 用法：
#   bash scripts/verify_all.sh
#
# 退出码 0 表示全部通过；任何一项失败都会打印 FAIL 并返回非 0。
#
# 重要：本机可用内存约 2.4 GB，测试**必须串行**（pytest.ini 已禁止 xdist），
#       本脚本不做任何并发，请勿同时跑第二份。
#
# 注意：本脚本不使用 set -e / set -o errexit——需要收集全部失败项后再统一判定。

cd "$(dirname "$0")/.." || exit 1

PY=".venv/bin/python"
[ -x "$PY" ] || PY="python3"

RUFF=".venv/bin/ruff"
[ -x "$RUFF" ] || RUFF="ruff"

FAILED=0

step() { printf '\n=== %s ===\n' "$1"; }
verdict() {
  if [ "$1" -eq 0 ]; then
    echo "$2: PASS"
  else
    echo "$2: FAIL"
    FAILED=1
  fi
}

step "1/4 静态检查（ruff check）"
"$RUFF" check . 2>&1 | tail -5
verdict "${PIPESTATUS[0]}" "ruff"

step "2/4 测试套件（pytest，串行执行）"
"$PY" -m pytest 2>&1 | tail -5
verdict "${PIPESTATUS[0]}" "pytest"

step "3/4 MCP stdio 冒烟（真实子进程 + 真实 JSON-RPC）"
"$PY" scripts/smoke_mcp_stdio.py 2>&1 | tail -8
verdict "${PIPESTATUS[0]}" "smoke"

step "4/4 HTTP 端到端（真实 uvicorn + 真实 curl）"
bash scripts/verify_stage8_http.sh 2>&1 | tail -6
verdict "${PIPESTATUS[0]}" "http-e2e"

printf '\n=== 汇总 ===\n'
if [ "$FAILED" -eq 0 ]; then
  echo "全部验证通过 ✅"
else
  echo "存在失败项 ❌"
fi
exit "$FAILED"