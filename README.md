# mcp-manager

本地优先的 **MCP / Agent 插件管理器**：发现 → 审查 → 评分 → 确认 → 安装 → 回滚，
并把同一套能力通过 MCP 暴露给 AI Agent——但 **Agent 永远不能自行授权**。

> 当前状态：**阶段 1–8 全部完成**。
> 各阶段进度、仓库地址、提交哈希与「未实现项」以 [`PROJECT_STATUS.md`](PROJECT_STATUS.md) 为准。

---

## 这是什么

AI 编程助手生态正在快速膨胀：每个助手都有自己的「插件」概念（Skill、MCP Server、Rules、Command、Hook），
来源、版本、安装位置、配置格式、权限各不相同。结果是：

- 同一个插件要在多个客户端里用不同格式各装一遍；
- 从 Git 仓库安装时**装的是哪个 commit 说不清**；
- **一个 Markdown 文件（Skill）就是可执行指令**，直接进模型上下文，却几乎没有东西去审查它。

`mcp-manager` 要解决的就是这条「**Agent 扩展的供应链**」：

1. **发现**：从 GitHub 搜索候选项目；
2. **审查**：分析项目质量并给出**可解释评分**，对安装脚本做**静态安全审查**；
3. **确认**：安装前把「将执行什么命令、改哪些文件、要哪些权限、如何回滚」摊开给用户确认；
4. **安装**：固定 commit、快照、原子应用、失败回滚、崩溃可恢复；
5. **暴露**：通过 MCP 把上述能力给到 Agent，但 **Agent 不能自行授权**。

### 一句话安全模型

> **Agent 只能提交「操作申请」，授权必须由用户在受信任的网页控制台完成。**

MCP 工具面里**故意不存在** `confirm_operation` / `execute_operation` / `install_plugin` /
`uninstall_plugin` / `rollback_plugin`。这不是遗漏，是设计。
`tools/list` 的返回里，任何名字含 `confirm` 或 `execute` 的工具都会让冒烟测试直接失败。

---

## 快速开始

### 环境要求

| 项 | 版本 / 说明 |
|---|---|
| Python | 3.12（开发环境实测 3.12.3） |
| 操作系统 | Linux（开发环境：Android proot Ubuntu 24.04 aarch64） |
| 内存 | 约 2.4 GB 可用（**测试必须串行**，见下） |

### 安装

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

依赖全部**精确锁定**（`==`），避免环境漂移。`requirements.txt` 里每条依赖都写了用途。

### 运行网页控制台

```bash
.venv/bin/python run_web.py
# 打开 http://127.0.0.1:8765/
```

默认**只监听 `127.0.0.1`**。若显式改绑非回环地址，必须同时设置
`MCPM_ALLOW_NON_LOOPBACK=1`，否则进程启动即失败——这是刻意的防误配。

### 运行 MCP Server（stdio）

```bash
.venv/bin/python run_mcp.py
```

stdio 模式下 **stdout 只允许协议内容**，因此该脚本不打印任何日志。

### 跑全部验证

```bash
bash scripts/verify_all.sh
```

依次执行：`ruff check` → `pytest` → MCP stdio 冒烟。退出码 0 表示全部通过。

也可单独执行：

```bash
.venv/bin/ruff check .                    # 静态检查
.venv/bin/python -m pytest                # 测试套件（246 项）
.venv/bin/python scripts/smoke_mcp_stdio.py   # 冒烟（21 项，真实子进程）
```

> **不要并发跑测试。** `pytest.ini` 已禁用 xdist 并注释了原因：本机可用内存约 2.4 GB，
> 并发会导致 OOM。

---

## 配置

所有配置都可以通过环境变量覆盖，全部以 `MCPM_` 开头。

| 变量 | 默认值 | 说明 |
|---|---|---|
| `MCPM_HOST` | `127.0.0.1` | 监听地址 |
| `MCPM_PORT` | `8765` | 监听端口 |
| `MCPM_ALLOW_NON_LOOPBACK` | `0` | 允许监听非回环地址（显式风险自担） |
| `MCPM_DATA_DIR` | 项目内 `var/` | 数据目录（SQLite、快照、配置根） |
| `MCPM_ALLOWED_HOSTS` | 空 | 追加 Host 头白名单（逗号分隔） |
| `MCPM_ALLOWED_ORIGINS` | 空 | 追加 Origin 白名单（逗号分隔） |
| `MCPM_MAX_REQUEST_BYTES` | `1048576` | 请求体积上限（1 MB） |
| `MCPM_ENABLE_INSTALL` | `1` | 是否启用安装能力；关闭后写接口一律 403 |
| `MCPM_CONFIRMATION_TTL` | `1800` | 确认令牌有效期（秒） |
| `MCPM_SESSION_TTL` | `3600` | 会话有效期（秒） |
| `GITHUB_TOKEN` | 无 | GitHub 只读访问令牌；未配置时搜索能力**显式不可用** |
| `MCPM_PYTHON` | 无 | 冒烟脚本使用的解释器（默认 `.venv/bin/python`） |

`GITHUB_TOKEN` 也可以由 `/root/.git-credentials`（`credential.helper=store`）提供。
**令牌不会出现在任何输出、日志或响应中。**

---

## 架构

```
┌──────────────────────────┐        ┌──────────────────────────┐
│  Web 控制台（受信任）      │        │  MCP Server（不可信 Agent）│
│  web/  + app/web/         │        │  app/mcp_server/          │
│  · 会话 + CSRF            │        │  · 13 个工具              │
│  · 确认 / 执行 / 回滚      │        │  · 无 confirm / execute   │
└────────────┬─────────────┘        └────────────┬─────────────┘
             │                                    │
             │  写操作需要授权                      │  只能提交申请
             ▼                                    ▼
      ┌──────────────────────────────────────────────────┐
      │           服务层 app/services/ + app/install/      │
      │  PluginService（读写插件、评分、审查）              │
      │  InstallService（计划 / 确认 / 执行 / 回滚编排）     │
      │  AdapterService（只读适配预览）                     │
      └───────────────────────┬──────────────────────────┘
                              ▼
      ┌──────────────────────────────────────────────────┐
      │  app/install/  事务内核                            │
      │  plan → confirmation → installer → fsguard        │
      │  固定 commit · 快照 · 原子应用 · 失败回滚 · 崩溃恢复 │
      └───────────────────────┬──────────────────────────┘
                              ▼
                   SQLite（app/db.py）+ 文件系统
```

### 目录

| 路径 | 内容 |
|---|---|
| `app/models.py` | 统一插件数据模型；所有结论必须带**证据等级** |
| `app/config.py` | 配置加载与校验（含 `data_dir` 覆盖，便于测试隔离） |
| `app/db.py` | SQLite schema 与迁移 |
| `app/security.py` | 来源校验、常量时间比较、日志脱敏 |
| `app/session.py` | 会话 + CSRF（只存哈希，带 TTL） |
| `app/search/` | GitHub 只读客户端与查询构造 |
| `app/analysis/` | 评分、对比、静态安全审查 |
| `app/install/` | 事务内核（计划、确认、执行、文件守卫、操作状态机） |
| `app/adapters/` | Skill / Rules / MCP Server 三类适配器 + 客户端格式注册表 |
| `app/services/` | 服务层（插件、安装编排、适配预览） |
| `app/web/` | FastAPI 应用（端点、安全中间件、异常映射） |
| `app/mcp_server/` | MCP 工具面 |
| `app/events.py` | 事件总线（SSE 推送） |
| `web/` | 原生 HTML/CSS/JS 控制台（无构建步骤） |

### 证据分级（贯穿全项目的硬性纪律）

任何结论都必须归入四级之一，代码中以 `EvidenceLevel` 枚举固化：

| 等级 | 含义 |
|---|---|
| `verified` | 【已验证事实】有可复现的实测证据 |
| `inferred` | 【有依据的推断】有间接证据支撑 |
| `unchecked` | 【未检查信息】尚未核实 |
| `undetermined` | 【无法确定结论】当前手段无法判定 |

---

## MCP 工具清单（13 个）

| 分类 | 工具 |
|---|---|
| 读取 | `list_plugins` · `get_plugin` · `get_stats` · `list_installed` |
| 发现 | `search_projects` · `inspect_project` · `compare_projects` · `inspect_plugin` |
| 操作申请 | `request_install` · `request_operation` |
| 计划与状态 | `get_install_plan` · `get_operation_status` · `list_operation_history` |

**不存在**：`confirm_operation` · `execute_operation` · `install_plugin` ·
`uninstall_plugin` · `rollback_plugin`。

Agent 侧行为约束（均有测试固化）：

- 能力不可用时**显式失败**，绝不伪造结果。例如未配置 GitHub 令牌时
  `search_projects` 返回 `search_unavailable`。
- 操作申请只生成**待确认计划**，响应里**不含任何确认令牌**。
- MCP 与网页共用同一个 `InstallService` 实例：Agent 提交的申请会真实出现在
  网页待确认列表中，但**确认令牌只下发到网页会话**。

---

## 安全边界

| 项 | 做法 |
|---|---|
| 网络 | 默认只绑回环；非回环需显式开关 |
| Host | Host 头白名单校验 |
| Origin | 非安全方法强制 Origin 校验 |
| CSRF | 写端点要求会话 Cookie **且** `X-CSRF-Token` 头 |
| 体积 | 请求体上限 1 MB |
| 响应头 | 统一安全头；CSP 严格，**不含 `unsafe-inline`** |
| 文档端点 | OpenAPI / docs / redoc 全部关闭 |
| 错误信息 | 异常 detail 统一经 `sanitize_for_log` 脱敏 |
| 前端 | 只用 `textContent` / `createElement`，不拼 HTML |
| 路径 | `resolve_within` 防路径穿越与符号链接逃逸 |
| 令牌比较 | 常量时间比较 |
| 命令执行 | 结构化参数 + `shell=False`；拒绝字符串命令；越界 cwd 拒绝 |
| 审计 | 记录 `actor`（仅 `user`/`agent`/`system`）、`action`、`target`、`outcome`、`detail` |
| GitHub | 客户端**只读**，令牌不外泄 |
| SSE | 订阅并发上限；只推脱敏字段 |

**不以正则或提示词作为安全控制。** 静态安全审查必然存在漏报，见下。

---

## 未实现 / 明确的限制

> 这一节是**诚实清单**。本项目的纪律之一是：未实现的能力必须显式失败，严禁声称已实现。

- **静态安全审查存在漏报**。它是模式匹配，只能发现「已知形态」的可疑代码，
  **不构成「安全」或「无恶意代码」的结论**。安装第三方插件前请自行核实。
- **适配器识别是启发式的**，必然存在漏识别与误识别。
- **Cursor 客户端配置格式未经官方文档核查**（标为【未检查】），代码中
  `writable=False`，**禁止写入**。
- **GitHub 匿名 API 有严格限流**，因此所有调用都必须带令牌；
  未配置令牌时搜索能力直接不可用，而不是降级成匿名请求。
- **agentbridge 的 scanner 实现与检出率**：未检查。
- **MCP Registry API 的破坏性变更时间表**：无法确定。
- **本项目自身尚未添加许可证文件**，因此默认保留所有权利。
  如需开源，请由项目所有者显式选择许可证后再添加 `LICENSE`。
  （本工具不会替使用者做法律决策。）

---

## 文档

| 文档 | 内容 |
|---|---|
| [`PROJECT_STATUS.md`](PROJECT_STATUS.md) | 跨阶段权威状态快照：进度、仓库、哈希、验证基线、未实现项、纪律 |
| [`docs/research.md`](docs/research.md) | 阶段 1：候选仓库实测调研（含证据分级） |
| [`docs/architecture.md`](docs/architecture.md) | 阶段 1：分层架构、统一插件模型、评分规则、事务状态机、威胁模型 |
| [`docs/plan.md`](docs/plan.md) | 阶段 1：分阶段实施计划 |
| [`docs/adapters.md`](docs/adapters.md) | 阶段 6：客户端配置格式的官方文档核查记录 |

---

## 免责声明

本工具提供的评分、风险级别与安全审查结论，都只是**基于当时可见静态证据的判断**，
不构成对任何第三方插件的安全担保。请自行核实后再安装。
