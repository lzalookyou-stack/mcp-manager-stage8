#!/usr/bin/env bash
# 阶段 8 完整端到端验证：真实 uvicorn + 真实 curl，覆盖全部 HTTP 表面。
#
# 覆盖范围：
#   A. 静态页面与安全响应头（CSP 不含 unsafe-inline、无 docs/openapi）
#   B. Host / Origin / 体积上限
#   C. 会话与 CSRF 的三重校验（无会话 / 错令牌 / 无 Origin 全部 403）
#   D. 完整授权链路：计划 → 确认 → 执行 → 成功；令牌一次性；令牌不外泄
#   E. 卸载与回滚链路
#   F. 只读接口（插件、操作历史、适配器）不泄露令牌
#   G. 适配器只读预览（含未验证客户端 profile 的处理）
#
# 本脚本不使用 set -e：需要收集全部失败项后再统一判定。
cd /data/user/0/com.ai.assistance.operit/files/workspace/baa843f1-7d93-466b-93b5-647f4942442b/mcp-manager || exit 1

export MCPM_DATA_DIR=/tmp/mcpm_stage8_e2e
export MCPM_ALLOWED_HOSTS=127.0.0.1
export MCPM_ALLOWED_ORIGINS=http://127.0.0.1:8792
rm -rf "$MCPM_DATA_DIR"
mkdir -p "$MCPM_DATA_DIR"

FAIL=0
ok()  { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; FAIL=$((FAIL+1)); }

B=http://127.0.0.1:8792
O=http://127.0.0.1:8792

# --- 启动真实 uvicorn ---
.venv/bin/python -m uvicorn scripts._stage8_e2e_app:create_app --factory \
  --host 127.0.0.1 --port 8792 --log-level warning > /tmp/mcpm_s8.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

for _ in $(seq 1 60); do
  sleep 0.5
  if curl -s -o /dev/null "$B/api/health"; then break; fi
done
curl -s -o /dev/null "$B/api/health" || { echo "服务未启动"; exit 1; }

echo "--- A. 静态页面与安全响应头 ---"
H=$(curl -s -D - -o /dev/null "$B/")
echo "$H" | grep -q "200" && ok "GET / 返回 200" || bad "GET / 状态码异常"
echo "$H" | grep -qi "content-security-policy" && ok "携带 CSP" || bad "缺少 CSP"
if echo "$H" | grep -qi "unsafe-inline"; then bad "CSP 含 unsafe-inline"; else ok "CSP 不含 unsafe-inline"; fi
for hdr in "x-content-type-options" "x-frame-options" "referrer-policy"; do
  echo "$H" | grep -qi "^$hdr" && ok "携带 $hdr" || bad "缺少 $hdr"
done
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$B/docs")
[ "$CODE" = "404" ] && ok "/docs 已关闭（404）" || bad "/docs 返回 $CODE（应关闭）"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$B/openapi.json")
[ "$CODE" = "404" ] && ok "/openapi.json 已关闭（404）" || bad "/openapi.json 返回 $CODE"

echo "--- B. Host / Origin / 体积 ---"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: evil.example.com' "$B/api/health")
[ "$CODE" = "400" ] && ok "非法 Host 被拒绝 400" || bad "非法 Host 返回 $CODE"
# 超限体积必须用文件发送：shell 变量传 2MB 会被截断，导致 curl 自身报错（非服务端问题）
.venv/bin/python -c "open('/tmp/s8_big.txt','w').write('x'*2000000)"
CODE=$(curl -s -o /tmp/s8_big.json -w '%{http_code}' -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H 'Content-Type: application/json' \
  --data-binary @/tmp/s8_big.txt)
[ "$CODE" = "413" ] && ok "超限请求体被拒绝 413" || bad "超限请求体返回 $CODE"
grep -q 'payload_too_large' /tmp/s8_big.json && ok "错误码 payload_too_large" || bad "错误码不符"

echo "--- C. 会话与 CSRF 三重校验 ---"
CODE=$(curl -s -o /tmp/s8_a.json -w '%{http_code}' -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H 'Content-Type: application/json' -d '{"plugin_id":"x"}')
[ "$CODE" = "403" ] && ok "无会话写请求 403" || bad "无会话写请求返回 $CODE"
grep -q "session_rejected" /tmp/s8_a.json && ok "错误码 session_rejected" || bad "错误码不符"

CSRF=$(curl -s -c /tmp/s8_cookie.txt -D /tmp/s8_hdr.txt -o /dev/null "$B/api/session" && \
  grep -i '^x-csrf-token:' /tmp/s8_hdr.txt | sed 's/.*: *//' | tr -d '\r')
[ -n "$CSRF" ] && ok "会话建立并下发 CSRF" || bad "未拿到 CSRF 令牌"
grep -qi 'httponly' /tmp/s8_hdr.txt && ok "会话 Cookie 为 HttpOnly" || bad "会话 Cookie 缺少 HttpOnly"

CODE=$(curl -s -b /tmp/s8_cookie.txt -o /dev/null -w '%{http_code}' -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H 'X-CSRF-Token: wrong' -H 'Content-Type: application/json' -d '{"plugin_id":"x"}')
[ "$CODE" = "403" ] && ok "错误 CSRF 被拒绝 403" || bad "错误 CSRF 返回 $CODE"

CODE=$(curl -s -b /tmp/s8_cookie.txt -o /dev/null -w '%{http_code}' -X POST "$B/api/install/plan" \
  -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' -d '{"plugin_id":"x"}')
[ "$CODE" = "403" ] && ok "无 Origin 被拒绝 403" || bad "无 Origin 返回 $CODE"

CODE=$(curl -s -b /tmp/s8_cookie.txt -o /dev/null -w '%{http_code}' -X POST "$B/api/install/plan" \
  -H "Origin: http://evil.example.com" -H "X-CSRF-Token: $CSRF" \
  -H 'Content-Type: application/json' -d '{"plugin_id":"x"}')
[ "$CODE" = "403" ] && ok "跨站 Origin 被拒绝 403" || bad "跨站 Origin 返回 $CODE"

echo "--- D. 完整授权链路 ---"
PID=$(.venv/bin/python - <<'PY'
from app.config import load_settings
from app.models import Plugin, PluginKind
from app.runtime import Runtime

rt = Runtime.create(load_settings(host="127.0.0.1", port=8792))
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
[ -n "$PID" ] && ok "已注册测试条目 $PID" || bad "注册条目失败"

PLAN=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
OPID=$(echo "$PLAN" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
[ -n "$OPID" ] && ok "生成安装计划 $OPID" || bad "生成计划失败：$PLAN"
STATUS=$(echo "$PLAN" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
[ "$STATUS" = "awaiting_confirmation" ] && ok "计划状态 awaiting_confirmation" || bad "计划状态 $STATUS"
if echo "$PLAN" | grep -q '"confirmation_token"'; then bad "计划响应泄露了确认令牌"; else ok "计划响应不含确认令牌"; fi

CONF=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$OPID/confirm" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF")
TOKEN=$(echo "$CONF" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("confirmation_token",""))' 2>/dev/null)
[ -n "$TOKEN" ] && ok "拿到一次性确认令牌" || bad "确认失败：$CONF"

EXEC=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$OPID/execute" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"confirmation_token\":\"$TOKEN\"}")
EXST=$(echo "$EXEC" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
[ "$EXST" = "succeeded" ] && ok "执行成功 succeeded" || bad "执行状态 $EXST：$EXEC"

CODE=$(curl -s -b /tmp/s8_cookie.txt -o /dev/null -w '%{http_code}' -X POST \
  "$B/api/operations/$OPID/execute" -H "Origin: $O" -H "X-CSRF-Token: $CSRF" \
  -H 'Content-Type: application/json' -d "{\"confirmation_token\":\"$TOKEN\"}")
[ "$CODE" = "409" ] && ok "已用令牌复用被拒绝 409" || bad "令牌复用返回 $CODE"

echo "--- E. 卸载与回滚链路 ---"
# 顺序很重要：卸载依赖「归属台账中有文件」，因此必须在安装之后、回滚之前。
UNP=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/uninstall/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
UNID=$(echo "$UNP" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
[ -n "$UNID" ] && ok "生成卸载计划 $UNID" || bad "生成卸载计划失败：$UNP"

UNT=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$UNID/confirm" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" | \
  .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("confirmation_token",""))' 2>/dev/null)
UNEX=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$UNID/execute" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"confirmation_token\":\"$UNT\"}")
UNST=$(echo "$UNEX" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
[ "$UNST" = "succeeded" ] && ok "卸载成功 succeeded" || bad "卸载状态 $UNST：$UNEX"

# 卸载后台账已清空 → 再次生成卸载计划必须被拒绝（不是静默成功）
UNP2=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/uninstall/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
if echo "$UNP2" | grep -q 'operation_rejected'; then
  ok "无归属文件时拒绝生成卸载计划"
else
  bad "空台账仍生成了卸载计划：$UNP2"
fi

# 重新安装后验证回滚
P2=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
P2ID=$(echo "$P2" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
P2T=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$P2ID/confirm" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" | \
  .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("confirmation_token",""))' 2>/dev/null)
curl -s -b /tmp/s8_cookie.txt -o /dev/null -X POST "$B/api/operations/$P2ID/execute" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"confirmation_token\":\"$P2T\"}"
ok "重新安装以验证回滚链路"

RBP=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/rollback/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
RBID=$(echo "$RBP" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
[ -n "$RBID" ] && ok "生成回滚计划 $RBID" || bad "生成回滚计划失败：$RBP"
RBT=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$RBID/confirm" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" | \
  .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("confirmation_token",""))' 2>/dev/null)
RBEX=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$RBID/execute" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"confirmation_token\":\"$RBT\"}")
RBST=$(echo "$RBEX" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
[ "$RBST" = "succeeded" ] && ok "回滚成功 succeeded" || bad "回滚状态 $RBST：$RBEX"

# 取消：生成一个计划后取消，验证状态机
CP=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/install/plan" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" -H 'Content-Type: application/json' \
  -d "{\"plugin_id\":\"$PID\"}")
CID=$(echo "$CP" | .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)
CANCEL=$(curl -s -b /tmp/s8_cookie.txt -X POST "$B/api/operations/$CID/cancel" \
  -H "Origin: $O" -H "X-CSRF-Token: $CSRF" | \
  .venv/bin/python -c 'import sys,json;print(json.load(sys.stdin).get("status",""))' 2>/dev/null)
[ "$CANCEL" = "cancelled" ] && ok "取消未执行的操作" || bad "取消失败，状态 $CANCEL"

echo "--- F. 只读接口不泄露令牌 ---"
DETAIL=$(curl -s "$B/api/operations/$OPID")
if echo "$DETAIL" | grep -q "$TOKEN"; then bad "操作详情泄露了令牌明文"; else ok "操作详情不泄露令牌"; fi
echo "$DETAIL" | grep -q '"logs"' && ok "操作详情含步骤日志" || bad "缺少步骤日志"
LIST=$(curl -s "$B/api/operations")
if echo "$LIST" | grep -q "$TOKEN"; then bad "操作列表泄露了令牌明文"; else ok "操作列表不泄露令牌"; fi
if echo "$LIST" | grep -q "$CSRF"; then bad "操作列表泄露了 CSRF"; else ok "操作列表不泄露 CSRF"; fi
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$B/api/plugins")
[ "$CODE" = "200" ] && ok "GET /api/plugins 只读可用" || bad "/api/plugins 返回 $CODE"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$B/api/stats")
[ "$CODE" = "200" ] && ok "GET /api/stats 只读可用" || bad "/api/stats 返回 $CODE"

echo "--- G. 适配器只读预览 ---"
AD=$(curl -s "$B/api/adapters")
echo "$AD" | grep -q '"adapters"' && ok "GET /api/adapters 返回适配器清单" || bad "适配器清单缺失：$AD"
echo "$AD" | grep -q '"clients"' && ok "GET /api/adapters 返回客户端格式" || bad "客户端格式缺失"
echo "$AD" | grep -q '"evidence"' && ok "客户端格式带证据等级" || bad "缺少证据等级字段"
echo "$AD" | grep -q 'servers' && ok "记录 VS Code 工作区的 servers 键名差异" || bad "缺少 servers 键名信息"

AP=$(curl -s "$B/api/plugins/$PID/adapt?profile=claude_desktop")
echo "$AP" | grep -q '"detected"' && ok "GET /api/plugins/{id}/adapt 返回检测结果" || bad "适配预览失败：$AP"
echo "$AP" | grep -q '"client"' && ok "适配预览带客户端格式信息" || bad "缺少客户端格式信息"
if echo "$AP" | grep -q '"client_config": *{'; then
  bad "未提供 command 却生成了配置片段"
else
  ok "未提供 command 时不生成配置片段"
fi

# 带 command 时才生成片段，且必须使用该客户端的顶层键名
AP2=$(curl -s "$B/api/plugins/$PID/adapt?profile=claude_desktop&command=node&args=index.js")
echo "$AP2" | grep -q '"client_config": *{' && ok "提供 command 时生成配置片段" || bad "提供 command 未生成片段：$AP2"
echo "$AP2" | grep -q 'mcpServers' && ok "Claude Desktop 片段使用 mcpServers 键名" || bad "键名不符"

# 未验证的客户端格式：设计上仍可输出片段供人工核对，
# 但必须显式标记 writable=false + evidence=unchecked，使调用方无法误当作可写。
AP3=$(curl -s -o /tmp/s8_ap3.json -w '%{http_code}' \
  "$B/api/plugins/$PID/adapt?profile=cursor_workspace&command=node")
[ "$AP3" = "200" ] && ok "未验证格式仍可输出片段（供人工核对）" || bad "未验证格式返回 $AP3"
if grep -q '"writable": *false' /tmp/s8_ap3.json && grep -q '"evidence": *"unchecked"' /tmp/s8_ap3.json; then
  ok "未验证格式显式标记 writable=false / evidence=unchecked"
else
  bad "未验证格式未标记不可写：$(cat /tmp/s8_ap3.json)"
fi

# 未知 profile 必须显式失败，不能回退到默认格式
CODE=$(curl -s -o /tmp/s8_ap4.json -w '%{http_code}' \
  "$B/api/plugins/$PID/adapt?profile=not_a_real_client&command=node")
[ "$CODE" = "400" ] && ok "未知客户端 profile 被拒绝 400" || bad "未知 profile 返回 $CODE"

# 适配端点是只读 GET：任何写方法在中间件层就被拒绝（未授权写请求 → 403）
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/plugins/$PID/adapt")
[ "$CODE" = "403" ] && ok "适配端点拒绝未授权写方法（403）" || bad "适配端点 POST 返回 $CODE"
# 即使带上合法会话与 CSRF，该路径也不存在 POST 路由 → 405
CODE=$(curl -s -b /tmp/s8_cookie.txt -o /dev/null -w '%{http_code}' -X POST \
  "$B/api/plugins/$PID/adapt" -H "Origin: $O" -H "X-CSRF-Token: $CSRF")
[ "$CODE" = "405" ] && ok "适配端点无 POST 路由（授权后仍 405）" || bad "授权后 POST 返回 $CODE"

echo
if [ "$FAIL" -gt 0 ]; then echo "结果：$FAIL 项失败"; exit 1; fi
echo "结果：全部通过"
exit 0