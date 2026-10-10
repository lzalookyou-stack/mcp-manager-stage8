#!/usr/bin/env bash
# 把 mcp-manager 注册为 Operit 的本地 MCP Server（stdio）。
#
# 做的事（全部幂等，可反复执行）：
#   1. 在 Linux 侧 ~/mcp_plugins/mcp_manager/ 生成**转发脚本** mcp_entry.sh，
#      真实代码始终只有工作区里这一份（与 memory-network 的部署约定一致）。
#   2. 在 Android 侧 /sdcard/Download/Operit/mcp_plugins/mcp_config.json 中
#      写入 mcpServers.mcp_manager 与 pluginMetadata.mcp_manager 两个条目。
#      写入前自动备份，写入后自校验 JSON，只增改本插件、不动其他条目。
#   3. 可选：若设置了 MCPM_GITHUB_TOKEN，则一并写入该插件的 env。
#
# 安全说明（重要）：
#   - autoApprove 只包含**只读**工具。request_install / request_operation
#     会创建操作计划，**不**列入自动批准，Agent 每次调用仍需用户批准。
#   - 本脚本默认**不**写任何令牌。mcp_config.json 位于共享存储且为明文，
#     是否把令牌写进去由使用者自行决定（见下方 --with-token 说明）。
#
# 用法：
#   bash scripts/install_mcp_plugin.sh              # 注册，不写令牌
#   MCPM_GITHUB_TOKEN=ghp_xxx bash scripts/install_mcp_plugin.sh --with-token
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ID="mcp_manager"
MCP_ROOT="/sdcard/Download/Operit/mcp_plugins"
CONFIG_PATH="${MCP_ROOT}/mcp_config.json"
LINUX_PLUGIN_DIR="${HOME}/mcp_plugins/${PLUGIN_ID}"

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
    printf '找不到可用的 Python 解释器（请设置 MCPM_PYTHON）\n' >&2
    exit 127
}

WITH_TOKEN=0
[ "${1:-}" = "--with-token" ] && WITH_TOKEN=1

# ---- 1) Linux 侧转发脚本 ------------------------------------------------
mkdir -p "${LINUX_PLUGIN_DIR}"
cat >"${LINUX_PLUGIN_DIR}/mcp_entry.sh" <<EOF
#!/usr/bin/env bash
# 由 mcp-manager/scripts/install_mcp_plugin.sh 生成，请勿手改。
#
# 本文件是 Operit 要求的「插件运行目录」入口，只做转发：
# 真实代码始终只有一份（${PROJECT_DIR}）。
#
# 注意：MCP 的 stdio 传输独占 stdout，本脚本不得写 stdout。
set -euo pipefail
exec /bin/bash "${PROJECT_DIR}/scripts/mcp_entry.sh" "\$@"
EOF
chmod +x "${LINUX_PLUGIN_DIR}/mcp_entry.sh"
printf '已生成转发脚本：%s\n' "${LINUX_PLUGIN_DIR}/mcp_entry.sh"

# ---- 2) 注册到 mcp_config.json -----------------------------------------
PROJECT_DIR="${PROJECT_DIR}" \
PLUGIN_ID="${PLUGIN_ID}" \
CONFIG_PATH="${CONFIG_PATH}" \
WITH_TOKEN="${WITH_TOKEN}" \
"${PY}" - <<'PY'
import json
import os
import pathlib
import shutil
import time

project_dir = os.environ["PROJECT_DIR"]
plugin_id = os.environ["PLUGIN_ID"]
config_path = pathlib.Path(os.environ["CONFIG_PATH"])
with_token = os.environ["WITH_TOKEN"] == "1"

# 只读工具才自动批准。request_install / request_operation 会创建操作计划，
# 必须由用户逐次批准，因此**不**列入。
READ_ONLY_TOOLS = [
    "list_plugins",
    "get_plugin",
    "get_stats",
    "list_installed",
    "search_projects",
    "inspect_project",
    "compare_projects",
    "inspect_plugin",
    "get_install_plan",
    "get_operation_status",
    "list_operation_history",
]

config_path.parent.mkdir(parents=True, exist_ok=True)

if config_path.exists():
    raw = config_path.read_text(encoding="utf-8")
    data = json.loads(raw)
    stamp = time.strftime("%Y%m%d%H%M%S")
    backup = config_path.with_name(f"{config_path.name}.bak-{stamp}")
    shutil.copy2(config_path, backup)
    print(f"已备份原配置：{backup.name}")
else:
    data = {}
    print("配置文件不存在，将新建。")

data.setdefault("mcpServers", {})
data.setdefault("pluginMetadata", {})

existing_server = data["mcpServers"].get(plugin_id) or {}
existing_meta = data["pluginMetadata"].get(plugin_id) or {}

env = dict(existing_server.get("env") or {})
token = os.environ.get("MCPM_GITHUB_TOKEN", "").strip()
if with_token:
    if token:
        env["MCPM_GITHUB_TOKEN"] = token
        print("已把 MCPM_GITHUB_TOKEN 写入插件 env（注意：该文件为共享存储上的明文）。")
    else:
        print("警告：指定了 --with-token 但 MCPM_GITHUB_TOKEN 为空，未写入令牌。")

data["mcpServers"][plugin_id] = {
    "command": "/bin/bash",
    "args": ["mcp_entry.sh"],
    "disabled": False,
    "env": env,
    "autoApprove": READ_ONLY_TOOLS,
}

data["pluginMetadata"][plugin_id] = {
    "id": plugin_id,
    "name": "MCP Manager",
    "author": "lzalookyou-stack",
    "version": "0.2.0",
    "description": (
        "本地优先的 MCP / Agent 插件管理器（Python stdio）。提供插件发现"
        "（搜索 / 检查 / 对比）与操作申请能力；安装、回滚、卸载必须由用户在"
        "受信任网页上确认后才会执行。"
    ),
    "longDescription": (
        "运行目录 ~/mcp_plugins/mcp_manager，入口 mcp_entry.sh 转发到仓库 "
        f"{project_dir}/scripts/mcp_entry.sh。13 个工具，刻意**不**暴露任何 "
        "confirm / execute 工具，Agent 无法自行完成授权或执行安装，也不会收到"
        "任何确认令牌。可视化管理控制台：bash scripts/start_web_console.sh"
    ),
    "repoUrl": "https://github.com/lzalookyou-stack/mcp-manager-stage8",
    "connectionType": "stdio",
    "type": "local",
    "isInstalled": True,
    "disabled": False,
    "installedTime": existing_meta.get("installedTime", int(time.time() * 1000)),
    "updatedAt": time.strftime("%Y-%m-%d"),
}

# 原子写：先写临时文件，自校验通过后再替换，避免写坏用户配置。
tmp = config_path.with_name(config_path.name + ".tmp")
tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
reloaded = json.loads(tmp.read_text(encoding="utf-8"))
assert plugin_id in reloaded["mcpServers"], "自校验失败：mcpServers 条目缺失"
assert plugin_id in reloaded["pluginMetadata"], "自校验失败：pluginMetadata 条目缺失"
os.replace(tmp, config_path)

print(f"已注册 mcpServers.{plugin_id}（disabled=false，autoApprove {len(READ_ONLY_TOOLS)} 个只读工具）")
print(f"已注册 pluginMetadata.{plugin_id}")
print("当前 mcpServers：", sorted(reloaded["mcpServers"].keys()))
PY

printf '\n完成。下一步：\n'
printf '  1) 在 Operit 的 MCP 管理页刷新/重启，应能看到 MCP Manager 且为启用状态。\n'
printf '  2) 可视化管理控制台：bash scripts/start_web_console.sh\n'