#!/usr/bin/env bash
# 阶段 7：创建独立仓库并推送（提交已存在，不重复提交）
cd /data/user/0/com.ai.assistance.operit/files/workspace/baa843f1-7d93-466b-93b5-647f4942442b/mcp-manager || exit 1
TOKEN=$(sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p' /root/.git-credentials | head -1)
[ -z "$TOKEN" ] && { echo "未找到令牌"; exit 1; }

REPO=mcp-manager-stage7
BASE=$(git rev-parse HEAD)
echo "本地 HEAD：$BASE"

# 1) 创建远端仓库（已存在则忽略）
CODE=$(curl -s -o .git/s7_create.json -w '%{http_code}' -X POST \
  -H "Authorization: token $TOKEN" \
  -H 'Accept: application/vnd.github+json' \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO\",\"private\":false,\"description\":\"mcp-manager 阶段7：MCP 集成（13 个工具，Agent 侧无授权能力）\"}")
echo "创建仓库 HTTP $CODE"
sed "s/${TOKEN}/***TOKEN***/g" .git/s7_create.json | head -3

# 2) 推送
git remote remove stage7 2>/dev/null
git remote add stage7 "https://lzalookyou-stack:${TOKEN}@github.com/lzalookyou-stack/${REPO}.git"
git push -q stage7 main 2>&1 | sed "s/${TOKEN}/***TOKEN***/g"
git remote set-url stage7 "https://github.com/lzalookyou-stack/${REPO}.git"

# 3) 回读远端 HEAD
REMOTE_HEAD=$(git ls-remote stage7 refs/heads/main 2>/dev/null | awk '{print $1}')
echo "远端 HEAD：$REMOTE_HEAD"
[ "$BASE" = "$REMOTE_HEAD" ] && echo "远端 HEAD 一致 ✅" || echo "远端 HEAD 不一致 ❌"

# 4) 远端文件树核验 + 与本地跟踪文件逐一比对
curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/lzalookyou-stack/${REPO}/git/trees/main?recursive=1" \
  > .git/s7_tree.json
.venv/bin/python - <<'PY'
import json
import subprocess

d = json.load(open('.git/s7_tree.json'))
if 'tree' not in d:
    print('远端文件树核验失败：', json.dumps(d)[:300])
    raise SystemExit(1)
blobs = [t for t in d['tree'] if t['type'] == 'blob']
trees = [t for t in d['tree'] if t['type'] == 'tree']
print(f"远端文件树：{len(blobs)} blob / {len(trees)} tree / truncated={d.get('truncated')}")
remote = sorted(t['path'] for t in blobs)
local = sorted(subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split())
print(f"本地跟踪文件：{len(local)}")
if remote == local:
    print("本地跟踪文件与远端文件树逐一比对：完全一致 ✅")
else:
    print("差异 ❌")
    print("  仅远端：", sorted(set(remote) - set(local))[:20])
    print("  仅本地：", sorted(set(local) - set(remote))[:20])
PY