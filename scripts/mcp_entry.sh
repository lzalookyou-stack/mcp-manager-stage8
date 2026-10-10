#!/usr/bin/env bash
# mcp-manager 的 MCP stdio 入口（供 Operit 的 mcp_config.json 调用）。
#
# 约定（与 memory-network 保持一致）：
#   - Operit 在 cwd=~/mcp_plugins/<shortName> 下执行本脚本；
#     该目录里的 mcp_entry.sh 只是转发器，真实代码始终只有这一份。
#   - stdio 传输独占 stdout：本脚本及其子进程**不得**向 stdout 写任何
#     非协议内容（调试信息一律走 stderr 或日志文件）。
#   - 解释器优先级：MCPM_PYTHON 环境变量 > 项目内 .venv/bin/python > 系统 python3。
#     前两者可保证依赖（fastapi / mcp / pydantic）齐全，是本项目的推荐路径。
#
# 用法：
#   bash scripts/mcp_entry.sh              # 正常 stdio 服务
#   MCPM_PYTHON=/path/to/python bash scripts/mcp_entry.sh
set -euo pipefail

# 本脚本位于 <项目根>/scripts/，因此项目根是它的上一级目录。
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_python() {
    if [ -n "${MCPM_PYTHON:-}" ] && [ -x "${MCPM_PYTHON}" ]; then
        printf '%s' "${MCPM_PYTHON}"
        return 0
    fi
    if [ -x "${PROJECT_DIR}/.venv/bin/python" ]; then
        printf '%s' "${PROJECT_DIR}/.venv/bin/python"
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi
    return 1
}

PY="$(resolve_python)" || {
    printf 'mcp-manager: 找不到可用的 Python 解释器（请设置 MCPM_PYTHON）\n' >&2
    exit 127
}

# run_mcp.py 依赖项目根作为 cwd 才能 import app 包。
cd "${PROJECT_DIR}" || exit 1

exec "${PY}" run_mcp.py "$@"
