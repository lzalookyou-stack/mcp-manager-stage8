# PROJECT_STATUS — mcp-manager

> 跨对话 / 跨阶段的权威状态快照。**所有「已完成/未实现」的判断以本文件为准。**
> 最后更新：2026-10-10（阶段 8 收口 · 全部 8 个阶段完成）

---

## 基本信息

- 项目名：`mcp-manager`（本地优先的 MCP / Agent 插件管理器）
- 本地路径：`/data/user/0/com.ai.assistance.operit/files/workspace/baa843f1-7d93-466b-93b5-647f4942442b/mcp-manager`
- 技术栈：Python 3.12 + FastAPI + uvicorn + 官方 `mcp` SDK + SQLite + 原生 HTML/CSS/JS + asyncio + SSE
- 环境：Android proot Ubuntu 24.04 aarch64；无 systemd / 无 GPU；可用内存约 2.4 GB
- 目标仓库：**每个阶段一个独立 GitHub 仓库**（见下）

---

## 阶段进度

| 阶段 | 状态 | 仓库 | 备注 |
|---|---|---|---|
| 1 调研与技术选型 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage1 | 提交 `ec27ff3`，已推送 |
| 2 最小可运行骨架 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage2 | 77 项测试全绿；MCP stdio 冒烟 9 项通过；Web 实机验证通过 |
| 3 搜索/分析/评分/安全审查 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage3 | 154 项测试全绿；MCP stdio 冒烟 9 项通过；Web 实机验证通过 |
| 4 网页控制台交互 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage4 | 175 项测试全绿；SSE 端到端真实验证；Web 实机验证通过 |
| 5 安全安装闭环 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage5 | 202 项测试全绿；MCP 冒烟 10 项通过；真实 HTTP 授权链路 16 项通过 |
| 6 插件适配器 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage6 | 225 项测试全绿；3 类适配器；4 个客户端格式经官方文档正文核查 |
| 7 MCP 集成 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage7 | 246 项测试全绿；MCP stdio 冒烟 21 项通过；13 个工具，**不暴露任何确认/执行工具** |
| 8 完整测试与交付 | ✅ 已完成 | https://github.com/lzalookyou-stack/mcp-manager-stage8 | 静态检查 0 项；**252 项测试全绿**；冒烟 21 项通过；HTTP 端到端 47 项通过；README / ruff.toml / verify_all.sh |

### 阶段仓库

| 阶段 | 仓库地址 | 提交哈希 | 推送状态 |
|---|---|---|---|
| 1 | https://github.com/lzalookyou-stack/mcp-manager-stage1 | 交付提交 `ec27ff3eddf3458302746caefe1a5334ba78928e`；状态回填提交 `806c58c` | ✅ 已推送（远端 `refs/heads/main` 已回读核对） |
| 2 | https://github.com/lzalookyou-stack/mcp-manager-stage2 | 交付提交 `015fdcb521eea18abba32d940ba14fec9cc992ef`；状态回填提交 `b742dcb` | ✅ 已推送（远端 `refs/heads/main` 已回读核对，33 文件树经 API 核验） |
| 3 | https://github.com/lzalookyou-stack/mcp-manager-stage3 | 交付提交 `2d4522bece572ca836dde936d30d8da01f8e99c6`；状态回填提交 `2c8684c7b773ceb6781aabbe7009b7a86a457eb7` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，45 blob / 11 tree，`truncated: false`） |
| 4 | https://github.com/lzalookyou-stack/mcp-manager-stage4 | 交付提交 `ca56e1a4ec0de9e955d323b1899c2b22989e406a`；状态回填提交 `1b59dfdbc74fdf36844690ce25e1e4b11d3f1c94` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，48 blob，`truncated: false`） |
| 5 | https://github.com/lzalookyou-stack/mcp-manager-stage5 | 交付提交 `d4de5865e3d0246ae92810971a1e8136ba414bff`；状态回填提交 `161010c2f4f4583280e195b01c71868bbe6cba20` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，62 blob / 12 tree，`truncated: false`，本地跟踪文件与远端文件树逐一比对无差异） |
| 6 | https://github.com/lzalookyou-stack/mcp-manager-stage6 | 交付提交 `d0d927d6557617e34c65035de2fd1a9da018c217`；状态回填提交 `b9cfe500d7c2014c9e9d6fa526e706c3349a07c4` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，72 blob / 13 tree，`truncated: false`，本地跟踪文件与远端文件树逐一比对无差异） |
| 7 | https://github.com/lzalookyou-stack/mcp-manager-stage7 | 交付提交 `a8c387fed92b8b5aa9c50108ee6d543619e67860`；状态回填提交 `dade49a8cc6d36fe4a2a07756d9c27f4d16344ee` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，73 blob / 13 tree，`truncated: false`，本地跟踪文件与远端文件树逐一比对无差异；另在**干净 worktree 检出该提交**复跑 246 passed + 冒烟 21 项 PASS） |
| 8 | https://github.com/lzalookyou-stack/mcp-manager-stage8 | 交付提交 `1df69550a5ec33a6e249bd19d0a6daeb0bc179b8`；测试隔离修复提交 `fef1a06149d04e00c5ec5d28ff5f608254f2f534`；状态回填提交 `3d852ac1519912a52fc1a9aa1e670140ff7a0eeb` | ✅ 已推送（远端 `refs/heads/main` 已回读核对 = 本地 HEAD，80 blob / 13 tree，`truncated: false`，本地跟踪文件与远端文件树逐一比对无差异；另在**干净 worktree 检出该提交**复跑 248 passed + 冒烟全通过；此后修复测试隔离缺陷并新增回归测试，最终为 252 passed） |

---

## 阶段交付物

### 阶段 1（已完成）

- `docs/research.md`：6 个候选仓库的实测调研，结论按【已验证】/【推断】/【未检查】/【无法确定】分级。
- `docs/architecture.md`：分层架构、统一插件数据模型、可解释评分规则、安装事务状态机、威胁模型摘要、技术选型结论。
- `docs/plan.md`：阶段 1–8 实施计划与贯穿纪律。
- `scripts/research_github.py`：可复现的 GitHub 调研脚本（仅用标准库，不打印令牌，失败即记录不伪造）。
- `scripts/research_result.json`：本次调研的原始数据（2026-10-09 采集）。

### 阶段 2（已完成）

可运行骨架：**只读** Web 控制台 + **只读** MCP Server，共用同一 service 层。

应用代码：
- `app/config.py`：不可变 `Settings`；默认仅绑回环，非回环需 `MCPM_ALLOW_NON_LOOPBACK=1` 否则**启动即失败**。
- `app/models.py`：统一插件模型（7 种 kind）、四级证据枚举、五级风险枚举、可解释评分（security 权重 0.30，且安全一票否决时总分归零）、`pinned_ref` 强制为 40/64 位 commit（拒绝浮动引用）。
- `app/security.py`：安全标识符校验、`resolve_within`（防 `..` 穿越 / 绝对路径 / 符号链接逃逸）、常量时间比较、日志清洗。
- `app/db.py`：SQLite（stdlib，无 ORM），WAL、外键、`busy_timeout`、事务上下文管理器。
- `app/services/plugin_service.py`：注册 / 查询 / 列表 / 审计；**搜索、评分、审查、安装、回滚五个方法显式 `raise NotImplementedError`**。
- `app/web/app.py`：只读 API + Host 白名单 + Origin(CSRF) 校验 + 体积上限 + 统一安全响应头（严格 CSP，无 `unsafe-inline`）+ 关闭 docs/openapi。
- `app/mcp_server/server.py`：基于 `mcp.server.mcpserver.MCPServer`（**mcp 2.x 中 FastMCP 已改名**）注册 4 个工具；`request_install` 恒返回 `not_implemented` 并记 `denied` 审计。
- `web/index.html` + `web/assets/{style.css,app.js}`：原生前端，全程只用 `textContent`/`createElement` 写 DOM。
- `run_web.py` / `run_mcp.py`：启动入口。
- `scripts/smoke_mcp_stdio.py`：真实子进程 stdio JSON-RPC 冒烟测试。

测试：`tests/` 共 77 项（模型 / 安全 / 服务 / Web），含「无写接口」负向断言与「未实现能力必须抛异常」断言。

### 阶段 3（已完成）

**搜索 / 分析 / 评分 / 安全审查**，全部为本地可复现逻辑，不依赖在线模型。

新增模块：
- `app/search/github_client.py`：**仅用标准库 `urllib` 的只读** GitHub 客户端。`GitHubError` 带 `kind`（rate_limited / not_found / unauthorized / invalid / network / server / error）与限流元数据；`transport` 参数支持测试注入（不发真实请求）；令牌**只放 `Authorization` 头**，绝不写入日志或异常；单文件文本上限 `MAX_TEXT_BYTES = 512 KiB`，超限截断并标注。能力：`search_repositories` / `get_repository` / `get_latest_commit`（校验 40 位 SHA）/ `list_releases` / `list_directory` / `get_file`（base64 解码）。
- `app/search/query.py`：自然语言 → GitHub 检索式。含中英文停用词与同义扩展表（「长期记忆」→`memory`、「轻量」→`lightweight`、「依赖少」→`zero-dependencies`）；支持 `language` / `min_stars` / `pushed_after`（校验 `YYYY-MM-DD`）/ `topics` / `in_name`。**无有效关键词时显式报错**，绝不返回空检索式。`notes` 声明「检索式由本地规则生成，未使用任何在线模型」。模块头声明它**不是安全控制**。
- `app/analysis/security_review.py`：19 条静态检测规则（DL001–DL004 / SH001–SH003 / FS001–FS002 / CR001–CR002 / NET001–NET002 / AU001 / PS001 / DP001），输出带**文件 / 行号 / 片段 / 原因 / 证据等级**的 `Finding`；风险取最高严重度，存在 critical 即 `vetoed=True`。**报告始终携带 `SecurityReport.DISCLAIMER`**，且永不输出「绝对安全」类结论。
- `app/analysis/scoring.py`：可解释评分。维度权重 维护 20% / 质量 25% / 安全 30% / 兼容 15% / 社区 10%；维度内权重全部显式声明；安全维度**未审查时给 0 分并标【未检查】**（保守默认），已审查时按 `{NONE:0, LOW:15, MEDIUM:40, HIGH:70}` 扣分，`vetoed` 时总分归零；Star 仅影响社区维度 40% 以内；每条理由均带来源。
- `app/analysis/compare.py`：`compare_plugins` 输出 `{rows, highlights, notes}`，以**陈述性**方式点出证据缺口（存在 critical 被一票否决 / 未取得明确许可证 / 尚未锁定固定 commit / 存在未获取字段），**不做「最佳推荐」**。

改造：
- `app/models.py`：`Plugin` 增加 `fetched_at` / `missing_fields` / `security_report`；新增 `FindingCategory`、`Finding`、`SecurityReport`、`RepoMetrics`、`SearchQuery`、`CompareRow`。
- `app/services/plugin_service.py`：新增 `SearchUnavailable`（**未配置客户端时显式失败，绝不返回空列表**）；实现 `build_query` / `search_remote`（落库为 `review_status=pending` 候选并写 `search.remote` 审计）/ `inspect_remote`（固定 commit + README/测试/CI/依赖清单探测 + Release 数，失败项记入 `missing_fields`）/ `review`（**先确保有 `pinned_ref`，否则拒绝在浮动引用上给结论**；抓取失败记 `skipped_files`）/ `score` / `compare`；**校验顺序**：先做本地可判定的来源校验，再要求远程客户端可用。
- `app/runtime.py`：`Runtime.create(*, github=None)`，未显式传入时从 `MCPM_GITHUB_TOKEN` / `GITHUB_TOKEN` 构造客户端。

测试：新增 `tests/test_github_client.py`、`test_security_review.py`、`test_scoring.py`、`test_query.py`、`test_stage3_service.py`（全部用注入假 transport，**不发真实网络请求**）。累计 **154 项**。

### 阶段 4（已完成）

**本地网页控制台交互 + SSE 实时**。关键约束：在增加交互的同时，**仍然没有任何写接口**。

新增模块：
- `app/events.py`：进程内发布/订阅事件总线。单订阅队列上限 256（满则**保新弃旧**并计数）、并发订阅上限 32（超出 `subscribe()` 返回 `None` → 端点回 503）；`publish()` **绝不抛异常**（无事件循环 / 无订阅者 / 载荷不可序列化都只累加计数），避免通知故障拖垮主流程；支持 `bind_loop` + `call_soon_threadsafe` 跨线程投递。

改造：
- `app/services/plugin_service.py`：`__init__` 增加 `events` 参数；`audit()` 写库成功后广播 `audit` 事件；`search_remote` 广播 `search.started/finished/failed`；`review` 广播 `review.started/progress/finished`。**事件只含已脱敏的结构化字段**。
- `app/runtime.py`：`Runtime` 增加 `events: EventBus`；`Runtime.create(*, events=None)`。
- `app/web/app.py`：新增只读端点 `GET /api/query`（检索式预览，**不触网**）、`GET /api/search`、`GET /api/plugins/{id}/inspect`、`GET /api/plugins/{id}/review`、`GET /api/compare`、`GET /api/tasks`、`GET /api/events`（SSE）、`GET /api/events/stats`；新增异常映射：`SearchUnavailable` → **503**、`GitHubError` → **502（带 kind）**。SSE 含 15 秒心跳，断开即退订。
- `web/index.html`：四个标签页（总览 / 发现 / 安装 / 任务与历史）+ 搜索表单 + 候选表 + 详情面板。
- `web/assets/app.js`：全部用 `textContent`/`createElement`；所有请求均为 GET；搜索/检查/审查/对比按钮连接**真实后端**；SSE 用 `EventSource` 订阅并按事件类型渲染。
- `pytest.ini`：新增 `asyncio_mode = strict`；`requirements.txt` 锁定 `pytest-asyncio==1.3.0`。

测试：新增 `tests/test_events.py`（7 项）、`tests/test_web_stage4.py`（14 项）。累计 **175 项**。

**阶段 4 的 SSE 验证方式（重要）**：`TestClient` 的同步 `stream()` 在等待流式响应时无法再发第二个请求（会死锁，且连接永不结束）。因此 SSE 的推送验证改为：
1. 单元测试在 **ASGI 层**直接驱动（`app(scope, receive, send)`），真实验证 `event: audit` 与数据体；
2. 另有一次**真实 HTTP 端到端**验证（真实 uvicorn + 后台 `curl -N` 挂 SSE，同时触发搜索与审查），实际收到 19 条事件（含 `search.started` / `audit` / `search.finished` / `review.started` / `review.progress` / `review.finished`），且**未出现任何令牌或凭据**。

---

## 验证基线（阶段 8）

以下为**真实执行**得到的结果（非声称），全部由 `bash scripts/verify_all.sh` 一键复现：

- **静态检查** `ruff check .`：**All checks passed!**（0 项）。
  配置见 `ruff.toml`：`select = ["E","F","W","I","UP","B","S"]`，
  `ignore = ["E501","B008","S101"]`，**每条忽略都在配置文件里写明了理由**
  （中文注释宽度 / FastAPI 官方 `Body(...)` 用法 / 测试中 assert 是标准做法）。
  自动修正 129 项 + 手动修正 13 项，修正明细见本节末。
- **测试套件** `pytest`：**252 passed**（串行执行，未启用 xdist）。
- **MCP stdio 冒烟** `scripts/smoke_mcp_stdio.py`：**21 项 PASS，退出码 0**。
- **HTTP 端到端** `scripts/verify_stage8_http.sh`：**47 项 PASS**（真实 uvicorn + 真实 curl），
  覆盖 A 安全响应头 / B Host·Origin·体积 / C 会话与 CSRF 三重校验 / D 完整授权链路 /
  E 卸载·回滚·取消 / F 只读接口不泄露令牌 / G 适配器只读预览。

### 阶段 8 的静态检查修正明细（诚实留痕）

| 规则 | 数量 | 处理方式 |
|---|---|---|
| 自动修正（导入排序、行尾换行等） | 129 | `ruff check --fix` |
| `B017` 盲异常断言 | 多处 | 改为断言**具体异常类型**（`SecurityError` / `SessionError` / `InstallServiceError` / `InstallError`），比原来更严格 |
| `B904` 异常链 | 1 | `raise ... from exc` |
| `S608` SQL 字符串拼接 | 2 | 加 `# noqa: S608` 并注明「where 子句由硬编码固定片段拼接、取值全走占位符」 |
| `S310` URL 打开 | 1 | 加 `# noqa: S310` 并注明「URL 由固定 API 基址 + 已校验的 owner/repo/ref 拼成」 |
| `S110` 静默吞异常 | 2 | 生产代码 `app/runtime.py` 改为**记录 warning 日志**；测试清理路径改用 `contextlib.suppress` |
| `F401` 未使用导入 | 1 | 把 `PLAN_TTL_SECONDS` 加入 `app/install/__init__.py` 的 `__all__` |
| `F821` 未定义名称 | 2 | 补 `SecurityError` / `InstallError` 导入（原本测试引用了未导入的异常类，属**真实缺陷**） |
| `UP042` `str + Enum` | 8 | 改为 `StrEnum`（Python 3.11+ 标准做法），改后全量测试仍 246 passed |

**没有为了通过检查而删除任何安全检查或降低任何断言强度。**
`B017` 的修正方向是**加强**断言（从 `pytest.raises(Exception)` 收紧到具体异常类型）；
`S110` 的修正方向是**让异常不再被静默吞掉**。

### 阶段 8 发现并修复的真实缺陷（端到端验证的产出）

端到端验证不是走过场，它发现了 **1 个真实缺陷**，已修复并补测试固化：

**缺陷：卸载后未清理归属台账（`file_ownership`）。**

- 现象：执行卸载后文件确实被删除，但台账行仍在；于是同一个插件可以**无限次**
  重复生成卸载计划（因为卸载计划的准入条件是「台账非空」），
  「已卸载」这个状态在系统里**根本无法表达**。
- 对照证据：同文件的 `revert()`（回滚）**有**清理台账的语句，`remove_owned_files()` 没有——
  属实现遗漏，不是设计选择。
- 修复：`app/install/fsguard.py` 的 `remove_owned_files()` 在删除后清理台账行。
  越界路径（不在受管根目录内）**依然绝不删除**，但其台账行同样清理，
  并通过新增的 `skipped` 出参交由 `Installer._audit_skipped()` 写入审计
  （`action=install.uninstall_skipped`、`outcome=denied`），保证「拒绝删除」这件事可追查。
- 新增测试：`test_uninstall_clears_ledger_so_second_plan_is_rejected`、
  `test_uninstall_out_of_scope_path_is_audited`；
  并在 `test_uninstall_removes_only_owned` 中补上「台账之外的文件也不能被删」断言。
- 附带修正：把 e2e 脚本里「未验证 profile 应被拒绝」的错误断言纠正为符合实际设计的断言
  （未验证格式**仍可**输出片段供人工核对，但必须显式标记 `writable=false` +
  `evidence=unchecked`；真正需要拒绝的是**写入**，由 `ClientProfile.assert_writable()` 负责）。
  同时新增「未知 profile 必须 400」断言。

**缺陷 2：测试结果依赖开发机环境变量（测试隔离失效）。**

- 现象：把 `MCPM_GITHUB_TOKEN` 导出到 shell 后跑 `pytest`，**3 个用例失败**：
  `test_search_without_github_client_fails_loudly`、`test_search_without_client_raises`、
  `test_search_projects_fails_loudly_without_github`。清除该变量后全部通过。
- 根因：`tests/conftest.py` 的 `runtime` 夹具直接调 `Runtime.create(settings)`，
  而后者会读 `MCPM_GITHUB_TOKEN` / `GITHUB_TOKEN` 并自动装配 GitHub 客户端。
  那三个用例的**前提**是「没有 GitHub 客户端」，前提被环境破坏后即失败。
- 为什么必须修：这使测试结果**取决于开发机/CI 是否碰巧配了令牌**，
  与本项目「不得伪造测试结果」的纪律直接冲突。
- 修复：`tests/conftest.py` 新增 `autouse` 夹具 `_isolate_env`，
  对每个测试 `monkeypatch.delenv` 掉两个令牌变量；`runtime` 夹具加断言
  `rt.plugins._github is None`，防止将来夹具被改回时静默退化。
  需要 GitHub 客户端的测试仍可**显式**通过 `github=` 参数注入。
- 新增回归测试 `tests/test_env_isolation.py`（4 项），其中关键一项用
  `subprocess` 起一个**真实带污染环境变量**的 pytest 子进程跑那三个用例，
  断言退出码为 0 且输出 `3 passed`——这是真实执行，不是自证。
- 验证：在 `MCPM_GITHUB_TOKEN=polluted_env_token` 下 **252 passed**；
  清除后同样 **252 passed**。两种环境结果一致。

**流程教训（诚实留痕）**：这个缺陷最初是我用
`pytest ... | tail -3 && git commit ...` 这种写法时暴露的——
管道让 `tail` 的退出码覆盖了 pytest 的退出码，导致**测试失败但提交仍然成功**。
`scripts/verify_all.sh` 已用 `PIPESTATUS` 正确处理，手动跑时也应用同样方式。

### 阶段 8 交付物

- `README.md`：完整交付文档（是什么 / 快速开始 / 配置表 / 架构图 / 目录说明 /
  MCP 工具清单 / 安全边界表 / **未实现与明确限制** / 文档索引 / 免责声明）。
- `ruff.toml`：静态检查配置，每条忽略均带理由。
- `scripts/verify_all.sh`：一键跑「静态检查 + 测试 + 冒烟」，退出码可判定。
- `scripts/smoke_mcp_stdio.py`：解释器解析改为 `MCPM_PYTHON` > `.venv/bin/python` > 当前解释器，
  使脚本在只读检出（如 CI 干净 checkout）中也能运行。
- `requirements.txt`：新增 `ruff==0.16.10`（仅开发/验证用，运行应用本身不需要）。

---

## 验证基线（阶段 7）

以下为**真实执行**得到的结果（非声称）：

- `pytest`（串行，`-q -p no:cacheprovider --tb=short`）：**246 passed in 13.00s**
  （阶段 7 新增 21 项，`tests/test_stage7_mcp.py`）。
- MCP stdio 冒烟 `scripts/smoke_mcp_stdio.py`：**21 项 PASS，退出码 0**。
- `tools/list` 实测返回 **13 个工具**（`compare_projects` / `get_install_plan` /
  `get_operation_status` / `get_plugin` / `get_stats` / `inspect_plugin` /
  `inspect_project` / `list_installed` / `list_operation_history` / `list_plugins` /
  `request_install` / `request_operation` / `search_projects`）。
- **关键安全断言**：不存在任何名字含 `confirm` / `execute` 的工具（实测 `forbidden == []`）。
  即 Agent 侧**没有**任何可以自行完成授权或执行安装的工具。
- Agent 侧行为实测：`request_install` 对未知条目返回 `{"ok": false, "error": "not_found"}`；
  响应字段集合为 `['detail', 'error', 'ok']`，**不含任何确认令牌**。
- `search_projects` 在未配置 GitHub 令牌时显式返回 `search_unavailable`，**不伪造搜索结果**。
- MCP 与网页共用同一个 `InstallService` 实例（`test_mcp_and_web_share_state`）：
  Agent 提交的申请会真实出现在网页待确认列表中，但**授权仍只能由用户在网页完成**。

**关于本仓库包含的静态检查修正（诚实留痕）**：阶段 7 的推送动作实际在阶段 8 的
ruff 静态检查之后才执行，因此本仓库中 `app/mcp_server/server.py`、
`scripts/smoke_mcp_stdio.py` 两个文件包含 ruff 的格式化修正（导入排序、行尾换行）。
这些修正**不改变任何语义**，上表所有测试与冒烟结果均在该状态下取得。
阶段 8 仓库将提交剩余的静态检查修正与 `ruff.toml`。

---

## 验证基线（阶段 6）

- `pytest -q -p no:cacheprovider`：**225 passed**（阶段 6 新增 23 项，`tests/test_stage6_adapters.py`）。
- 客户端格式核查（抓取官方文档正文）：4 个 profile 标为【已验证】并记录来源 URL；
  1 个（Cursor）标为【未检查】，`writable=False`，**禁止写入**。
- 关键断言：不同客户端顶层键名**确实不同**（VS Code 工作区 `servers` vs 其余 `mcpServers`）；
  未验证 profile 调 `assert_writable()` 抛异常；MCP 片段拒绝在无 `command` 时生成；
  适配预览**不产生任何文件变更**。

详细核查记录见 `docs/adapters.md`。

---

## 验证基线（阶段 5）

以下为**真实执行**得到的结果（非声称）：

1. `pytest -q -p no:cacheprovider`：**202 passed**（阶段 5 新增 26 项，位于 `tests/test_stage5_install.py`）。
2. `scripts/smoke_mcp_stdio.py`：**10 项 PASS，退出码 0**；其中包含关键安全断言「Agent 响应中不含任何确认令牌」。
3. `scripts/verify_stage5_http.sh`（真实 uvicorn + curl）：**16 项 PASS**，覆盖：
   - `GET /` 200 且 CSP 不含 `unsafe-inline`；
   - 无会话写请求 → 403 `session_rejected`；
   - 错误 CSRF → 403；无 Origin 的 POST → 403 `csrf_origin_rejected`；
   - 完整授权链路：会话 → 计划（`awaiting_confirmation`）→ 确认（拿到一次性令牌）→ 执行（`succeeded`）；
   - 已用令牌复用 → 409；
   - 只读接口不泄露令牌明文，且含步骤日志。

关键安全性质（已在测试中断言）：

- 计划生成**不产生任何文件写入**；
- 无固定 commit → 拒绝生成计划；安全审查 `vetoed` → 拒绝生成计划；
- 确认令牌：一次性、常量时间比较、有 TTL、绑定计划摘要（计划变化即失效）；
- 执行前**重新验证**令牌与当前计划一致；
- 失败即 `failed` 并回滚，绝不残留半成品；
- 崩溃遗留的 `running` / `rolling_back` 事务标记为 `interrupted`，**绝不视为成功**；
- 卸载只删除归属台账中登记且位于受管根目录内的文件（越界路径绝不删除）；
- `run_command` 拒绝字符串命令、拒绝越界 cwd、`shell=False` 下 `;` 不被解释为命令分隔符、超时可控。

---

## 未实现（**严禁声称已实现**）

以下能力在阶段 5 **确实不存在**，调用会显式失败（`NotImplementedError` / `SearchUnavailable` / `InstallUnavailable` 或返回 `not_found` / `plan_rejected`）：

- `PluginService` **不再提供** `install` / `rollback` / `uninstall`（阶段 5 已移除占位方法）。
  写操作的唯一入口是 `app.install.service.InstallService`，必须走「生成计划 → 用户通过受信任网页确认 → 校验令牌 → 执行」。
  没有任何代码路径可以绕过用户授权直接写入文件系统（`tests/test_plugin_service.py::test_write_methods_absent_from_plugin_service` 断言这些方法**不存在**）。
- `PluginService.search_remote` / `inspect_remote` / `review` / `score` / `compare`：**已在阶段 3 实现**；但在**未配置 GitHub 令牌**时 `search_remote` 会抛 `SearchUnavailable`（显式失败，**不会**返回空列表被误读为「没有结果」）。
- Web 层**已有写接口**（阶段 5 引入），但全部要求「同源 Origin + 会话 Cookie（HttpOnly/SameSite=Strict）+ CSRF 令牌」三件套；
  未授权访问一律 403（`session_rejected` / `csrf_origin_rejected`）。负向断言**已同步更新而非删除**：
  `tests/test_web.py::test_write_endpoints_require_authorization` 与 `tests/test_web_stage4.py::test_no_write_endpoints_still_true`。
- Web 层现有独立**操作表**（`operations` / `operation_logs` / `confirmations` / `snapshots` / `file_ownership`）：
  `/api/operations`（列表）与 `/api/operations/{id}`（详情 + 确认状态 + 步骤日志）为只读；`/api/tasks` 仍读取审计日志。
- MCP 工具 `request_install` **不产生任何安装行为**：它只生成「等待用户确认」的安装计划（`ok: true, status: awaiting_confirmation`）；
  未知条目返回 `not_found`，计划被拒返回 `plan_rejected`。Agent **无法**确认或执行，响应中**不含**任何确认令牌。
- 插件适配器已支持 `skill` / `rules_instructions` / `mcp_server` 三类；
  `agent_plugin` / `command` / `hook` / `adapter_extension` **仍无适配器**（`get_adapter` 显式抛 `AdapterError`）。
- 客户端配置的**写入**尚未接入界面：阶段 6 只提供只读预览与配置片段，实际写入需走阶段 5 的安装闭环。
- 计划中的 `commands` 恒为空：本系统**默认禁止**自动执行仓库内安装脚本。
- 本项目自身**尚无 LICENSE**：README 与本节均明确写为「默认保留所有权利」。
  **不会替使用者做法律决策**——需要开源时由项目所有者显式选择许可证后再添加 `LICENSE` 文件。
- **无法检测本机已注册 / 已安装的第三方 MCP Server**：`list_installed` 只返回
  **由本系统自己安装成功**的条目（`install_status = succeeded` 的库内记录），
  它**不会读取**任何客户端配置文件，也不会扫描本机已注册的 MCP 服务。
  具体地说，以下路径**从未被读取**：`claude_desktop_config.json`、`.vscode/mcp.json`、
  `.mcp.json`、`$COPILOT_HOME/mcp-config.json`、`.cursor/mcp.json`。
  `ClientProfile.config_path_hint` 只是**展示用的路径提示字符串**，不是可执行的读取逻辑。
  （本机实测：全新数据目录下 `list_installed` 返回 `[]`、`stats.total = 0`，
  即使机器上已存在其他 MCP 客户端配置也返回空。）
- 安全审查为**静态模式匹配**：必然存在漏报，未命中**不代表**安全。

---

## 已知缺口 / 风险

见 `docs/research.md` 第 3 节。摘要：
- agentbridge 的 scanner 实现与检出率：**未检查**。
- MCP Registry API 的破坏性变更时间表：**无法确定**（官方声明 preview + v0.1 freeze）。
- `tamb/simple-mcp-manager` 的真实许可证：**无法确定**（README 称 MIT，API 为 null）。

---

## 验证基线

阶段 1（可复跑）：

```bash
cd mcp-manager
python3 scripts/research_github.py --out scripts/research_result.json   # 应输出 6 个仓库的真实字段
```

阶段 2（可复跑，必须先建好 `.venv`）：

```bash
cd mcp-manager
.venv/bin/python -m pytest                                   # 期望 77 passed
.venv/bin/python scripts/smoke_mcp_stdio.py                  # 期望 SMOKE_EXIT=0，9 项 PASS
.venv/bin/python run_web.py &                                # 真实启动
curl -s http://127.0.0.1:8765/api/health                     # {"status":"ok",...}
```

阶段 2 的实测结果（2026-10-09）：

- `pytest`：**77 passed in 2.29s**。
- `smoke_mcp_stdio.py`：**9 项 PASS，退出码 0**；`tools/list` 返回 4 个工具；`request_install` 被拒绝（`not_implemented`）。
- Web 实机：`GET /` 200（含完整安全头与严格 CSP）、`/api/health` 200、`/api/stats` 200、`/api/plugins` 200、`/assets/app.js` 200、无 Origin 的 `POST /api/plugins` **403**、非法 Host **400**、`/docs` **404**。

> 环境说明：系统 Python 受 PEP 668 保护，**必须使用项目内 `.venv`**；依赖走清华镜像安装。
> `mcp 2.3.0` 实测：`FastMCP` 已改名为 `MCPServer`（`from mcp.server.mcpserver import MCPServer`），旧 `mcp.server.fastmcp` 导入会失败。

阶段 3（可复跑，必须先建好 `.venv`）：

```bash
cd mcp-manager
.venv/bin/python -m pytest                                   # 期望 154 passed
.venv/bin/python scripts/smoke_mcp_stdio.py                  # 期望 SMOKE_EXIT=0，9 项 PASS
.venv/bin/python run_web.py &                                # 真实启动
curl -s http://127.0.0.1:8765/api/stats                      # {"total":0,...}
```

阶段 3 的实测结果（2026-10-09）：

- `pytest`：**154 passed in 5.36s**。
- `smoke_mcp_stdio.py`：**9 项 PASS，退出码 0**（与阶段 2 一致；`request_install` 仍被拒绝为 `not_implemented`）。
- Web 实机（真实 uvicorn + 真实 curl）：`GET /` **200** 且携带严格 CSP（`default-src 'none'; script-src 'self'; …`，**不含 `unsafe-inline`**）与 `nosniff` / `DENY` / `no-referrer` / `same-origin`；无 Origin 的 `POST /api/plugins` **403 `csrf_origin_rejected`**；非法 Host **400 `invalid_host`**；`/docs` 与 `/openapi.json` 均 **404**；`/api/stats`、`/api/plugins` 均 **200**。
- 阶段 3 首轮曾出现 11 项失败，已全部定位并修复（见「阶段 3 修复记录」）。

### 阶段 3 修复记录（诚实留痕）

首轮 `pytest` 为 **11 failed / 140 passed**，逐项定位后确认：

1. **实现缺陷 1（免责声明未落地）**：`review_files` 从未把 `SecurityReport.DISCLAIMER` 写入 `notes`，与模块契约（「报告始终携带免责声明」）不符，测试因此在 `notes[-1]` 上 `IndexError`。→ 修实现：无论是否命中，均追加免责声明；未命中时额外说明「未命中不代表不存在风险」。
2. **实现缺陷 2（校验顺序错误）**：`inspect_remote` / `review` 先取远程客户端、后校验来源，导致「非 GitHub 源」被误报成 `SearchUnavailable`，掩盖真正根因。→ 修实现：先做本地可判定的来源校验，再要求客户端可用。
3. **测试数据缺陷（10 项）**：测试用单字符查询 `"x"`，被关键词过滤器（长度 < 2）丢弃后触发「检索式为空必须报错」这一**合理约束**。→ 修测试数据（改为 `"memory mcp"`），**未**放宽 `build_search_query` 的空检索式报错约束；并**新增**测试把该约束固化下来。
4. **测试断言过弱**：免责声明用例的 `assert A or B` 使其形同虚设。→ 改为强断言 `SecurityReport.DISCLAIMER in report.notes`。

> 全部修复均**未删除任何安全检查、未降低任何断言**；新增强断言与新增用例后，总数由 140 增至 154。

阶段 4（可复跑，必须先建好 `.venv`）：

```bash
cd mcp-manager
.venv/bin/python -m pytest                                   # 期望 175 passed
.venv/bin/python scripts/smoke_mcp_stdio.py                  # 期望 SMOKE_EXIT=0，9 项 PASS
.venv/bin/python run_web.py &                                # 真实启动
curl -s http://127.0.0.1:8765/api/events/stats               # {"subscribers":0,...}
curl -sN http://127.0.0.1:8765/api/events                    # 应收到 ": connected"
```

阶段 4 的实测结果（2026-10-09）：

- `pytest`：**175 passed in 6.94s**。
- `smoke_mcp_stdio.py`：**9 项 PASS，退出码 0**（与阶段 2/3 一致）。
- Web 实机（真实 uvicorn + 真实 curl）：`GET /` **200** 且含阶段 4 面板与严格 CSP（**不含 `unsafe-inline`**）；`GET /api/query` **200**（返回真实检索式与「未使用任何在线模型」声明）；`GET /api/search`（无令牌）**503 `search_unavailable`**；`GET /api/events/stats` **200**；`GET /api/events` 真实收到 `: connected`；无 Origin 的 `POST /api/search` **403**；`/docs` **404**。
- **SSE 端到端（真实 HTTP）**：后台 `curl -N` 挂 SSE 的同时触发真实搜索与审查，收到 **19 条真实事件**（`search.started` / `audit` / `search.finished` / `review.started` / `review.progress` ×6 / `review.finished`），事件体中**不含任何令牌或凭据**；`/api/events/stats` 在订阅挂起时显示 `subscribers: 1`。

> 说明：SSE 的单元测试**不能**用 `TestClient.stream()`（同步客户端在等流式响应时无法再发第二个请求，会死锁），因此改用 ASGI 层直接驱动 `app(scope, receive, send)`，并用上述真实 HTTP 端到端做补充验证。

---

## 纪律（不可违反）

1. **不伪造**仓库数据、测试结果、执行状态、安全结论。
2. 所有结论标注证据等级（`EvidenceLevel`：verified / inferred / unchecked / undetermined）。
3. **不以正则或提示词作为安全控制**；不为通过测试而删除安全检查或降低断言。
4. **Agent 只能提交操作申请，授权必须来自用户通过受信任网页的明确确认**（禁止 Agent 自造授权）。
5. 每阶段成果提交并推送到**新的独立 Git 仓库**。
6. 测试串行执行，避免 OOM（本机可用内存约 2.4 GB）。