#!/usr/bin/env bash
# 启动 mcp-manager 的**可视化管理控制台**（网页界面）。
#
# 与 mcp_entry.sh 的分工：
#   - mcp_entry.sh    : stdio 传输，供 MCP 客户端（Operit 等）拉起，给 Agent 用。
#   - start_web_console.sh : HTTP 服务，供**人**在浏览器里可视化查看与管理插件。
#
# 默认仅监听回环地址 127.0.0.1:8765（安全默认值）。
# 如需在别的设备上访问，请显式设置 MCPM_HOST=0.0.0.0，
# 但**必须同时**配置 MCPM_GITHUB_TOKEN 之外的访问控制，否则等于把控制台暴露给局域网。
#
# 用法：
#   bash scripts/start_web_console.sh          # 后台启动（幂等）
#   bash scripts/start_web_console.sh stop     # 停止
#   bash scripts/start_web_console.sh status   # 查看状态
#   bash scripts/start_web_console.sh fg       # 前台运行（调试用）
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAR_DIR="${PROJECT_DIR}/var"
PIDFILE="${VAR_DIR}/web-console.pid"
LOGFILE="${VAR_DIR}/web-console.log"

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

HOST="${MCPM_HOST:-127.0.0.1}"
PORT="${MCPM_PORT:-8765}"
URL="http://${HOST}:${PORT}/"

mkdir -p "${VAR_DIR}"

is_running() {
    [ -f "${PIDFILE}" ] || return 1
    local pid
    pid="$(cat "${PIDFILE}" 2>/dev/null || true)"
    [ -n "${pid}" ] || return 1
    kill -0 "${pid}" 2>/dev/null
}

case "${1:-start}" in
    start)
        if is_running; then
            printf '控制台已在运行：PID %s\n' "$(cat "${PIDFILE}")"
            printf '地址：%s\n' "${URL}"
            exit 0
        fi
        cd "${PROJECT_DIR}"
        # nohup + 重定向，避免服务随调用方终端会话结束而退出。
        nohup "${PY}" run_web.py >>"${LOGFILE}" 2>&1 &
        echo $! >"${PIDFILE}"
        printf '控制台已启动：PID %s\n' "$(cat "${PIDFILE}")"
        printf '地址：%s\n' "${URL}"
        printf '日志：%s\n' "${LOGFILE}"
        printf '提示：首次启动需等 1~3 秒；用 status 子命令确认就绪。\n'
        ;;
    stop)
        if is_running; then
            pid="$(cat "${PIDFILE}")"
            kill "${pid}" 2>/dev/null || true
            for _ in $(seq 1 20); do
                kill -0 "${pid}" 2>/dev/null || break
                sleep 0.25
            done
            kill -9 "${pid}" 2>/dev/null || true
            rm -f "${PIDFILE}"
            printf '控制台已停止（原 PID %s）。\n' "${pid}"
        else
            rm -f "${PIDFILE}"
            printf '控制台未在运行。\n'
        fi
        ;;
    status)
        if is_running; then
            printf '运行中：PID %s\n' "$(cat "${PIDFILE}")"
            printf '地址：%s\n' "${URL}"
        else
            printf '未运行。\n'
            exit 1
        fi
        ;;
    fg)
        cd "${PROJECT_DIR}"
        exec "${PY}" run_web.py
        ;;
    *)
        printf '用法：%s [start|stop|status|fg]\n' "$0" >&2
        exit 2
        ;;
esac