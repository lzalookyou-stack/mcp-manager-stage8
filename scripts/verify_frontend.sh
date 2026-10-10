#!/usr/bin/env bash
# 前端写操作链路验证：**真实执行** web/assets/app.js，而不是复刻它的逻辑。
#
# 步骤：
#   1. 启动一个独立实例（内存文件来源 + 独立数据目录 + 独立端口）
#   2. 注册一条测试插件
#   3. 用 Node 真实加载 web/assets/app.js，驱动「会话 → 计划 → 确认 → 执行」
#   4. 清理
#
# 依赖：Node 18+（用到内置 fetch 与 vm 模块）。Python 侧用项目内 .venv。
# 不使用 set -e：需要收集全部结果后再判定。

cd /data/user/0/com.ai.assistance.operit/files/workspace/baa843f1-7d93-466b-93b5-647f4942442b/mcp-manager || exit 1

PORT=8799
BASE="http://127.0.0.1:${PORT}"

export MCPM_DATA_DIR=/tmp/mcpm_fe_test
export MCPM_ALLOWED_HOSTS=127.0.0.1
export MCPM_ALLOWED_ORIGINS="$BASE"

pkill -f "uvicorn scripts._stage8_e2e_app" 2>/dev/null
sleep 1
rm -rf "$MCPM_DATA_DIR"
mkdir -p "$MCPM_DATA_DIR"

.venv/bin/python -m uvicorn scripts._stage8_e2e_app:create_app --factory \
  --host 127.0.0.1 --port "$PORT" --log-level warning > /tmp/mcpm_fe.log 2>&1 &
SRV=$!

for _ in $(seq 1 60); do
  sleep 0.5
  if curl -s -o /dev/null "$BASE/api/health"; then break; fi
done
echo "实例健康检查：$(curl -s "$BASE/api/health")"

PID=$(.venv/bin/python - <<'PY'
from app.config import load_settings
from app.models import Plugin, PluginKind
from app.runtime import Runtime

rt = Runtime.create(load_settings(host="127.0.0.1", port=8799))
p = rt.plugins.upsert(
    Plugin.new(
        source="github:acme/demo",
        slug="demo",
        name="acme/demo",
        kind=PluginKind.MCP_SERVER,
        pinned_ref="a" * 40,
    ),
    actor="user",
)
print(p.id)
rt.close()
PY
)
echo "已注册测试插件：$PID"

echo "--- 驱动真实前端代码 ---"
FE_BASE="$BASE" FE_PLUGIN_ID="$PID" FE_APP_JS="$PWD/web/assets/app.js" \
  node scripts/verify_frontend.js
NODE_EXIT=$?
echo "node_exit=$NODE_EXIT"

kill "$SRV" 2>/dev/null
wait "$SRV" 2>/dev/null
echo "--- 服务端日志（最后 3 行）---"
tail -3 /tmp/mcpm_fe.log

exit "$NODE_EXIT"