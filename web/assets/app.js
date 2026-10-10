/*
 * mcp-manager 控制台脚本（发现 · 安装 · 卸载 · 回滚 + SSE）。
 *
 * 安全约定：
 * - **只使用 textContent / createElement 写入 DOM**，全程不使用
 *   innerHTML / insertAdjacentHTML / eval / new Function；
 * - 写操作（安装 / 卸载 / 回滚）必须依次经过：生成计划 → 人工确认 → 执行。
 *   会话 Cookie 由服务端下发（HttpOnly），CSRF 令牌只保存在**内存变量**中，
 *   不写入 localStorage / sessionStorage；
 * - 确认令牌由后端在确认时一次性下发，仅用于紧随其后的执行请求；
 * - 服务端错误如实展示（含 search_unavailable / github_error 的 kind），
 *   不把失败伪装成"没有结果"。
 */

"use strict";

/* ------------------------------------------------------------------ */
/* 基础工具                                                            */
/* ------------------------------------------------------------------ */

async function getJSON(url) {
  const resp = await fetch(url, {
    method: "GET",
    headers: { Accept: "application/json" },
    credentials: "same-origin",
    cache: "no-store",
  });
  let body = null;
  try {
    body = await resp.json();
  } catch (err) {
    body = null;
  }
  if (!resp.ok) {
    const detail = body && body.detail ? body.detail : "";
    const kind = body && body.kind ? " [" + body.kind + "]" : "";
    const code = body && body.error ? body.error : "HTTP " + resp.status;
    throw new Error(code + kind + (detail ? "：" + detail : ""));
  }
  return body;
}

/* ------------------------------------------------------------------ */
/* 会话与写请求                                                        */
/* ------------------------------------------------------------------ */

/*
 * CSRF 令牌只放内存：刷新页面即失效并重新建立会话，
 * 避免令牌被持久化后长期有效。
 */
let csrfToken = null;

async function ensureSession(force) {
  if (csrfToken && !force) {
    return csrfToken;
  }
  const resp = await fetch("/api/session", {
    method: "GET",
    headers: { Accept: "application/json" },
    credentials: "same-origin",
    cache: "no-store",
  });
  if (!resp.ok) {
    throw new Error("无法建立会话（HTTP " + resp.status + "）");
  }
  const token = resp.headers.get("X-CSRF-Token");
  if (!token) {
    throw new Error("服务端未下发 CSRF 令牌，写操作已被拒绝");
  }
  csrfToken = token;
  return token;
}

/*
 * 写请求统一入口：自动带上会话 Cookie（同源）与 CSRF 头。
 * Origin 头由浏览器自动添加，服务端会做校验。
 */
async function postJSON(url, body) {
  const token = await ensureSession();
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": token,
    },
    credentials: "same-origin",
    cache: "no-store",
    body: JSON.stringify(body || {}),
  });
  let data = null;
  try {
    data = await resp.json();
  } catch (err) {
    data = null;
  }
  if (resp.status === 403) {
    // 会话可能已过期：丢弃令牌，下次请求重新建立。
    csrfToken = null;
  }
  if (!resp.ok) {
    const code = data && data.error ? data.error : "HTTP " + resp.status;
    const detail = data && data.detail ? data.detail : "";
    throw new Error(code + (detail ? "：" + detail : ""));
  }
  return data;
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) {
    node.className = className;
  }
  if (text !== undefined && text !== null) {
    node.textContent = String(text);
  }
  return node;
}

function clear(node) {
  while (node && node.firstChild) {
    node.removeChild(node.firstChild);
  }
}

function setText(id, text) {
  const node = document.getElementById(id);
  if (node) {
    node.textContent = String(text);
  }
}

function show(id, visible) {
  const node = document.getElementById(id);
  if (node) {
    node.hidden = !visible;
  }
}

function fmtTime(value) {
  if (!value) {
    return "—";
  }
  return String(value).replace("T", " ").replace("Z", " UTC").slice(0, 25);
}

/* ------------------------------------------------------------------ */
/* 总览                                                                */
/* ------------------------------------------------------------------ */

async function refreshHealth() {
  const node = document.getElementById("health");
  try {
    const data = await getJSON("/api/health");
    node.textContent =
      "服务正常 · 版本 " + data.version +
      " · 仅回环：" + (data.loopback_only ? "是" : "否") +
      " · 条目 " + data.plugins;
    node.className = "health ok";
  } catch (err) {
    node.textContent = "服务异常：" + err.message;
    node.className = "health err";
  }
}

async function refreshStats() {
  try {
    const data = await getJSON("/api/stats");
    setText("stat-total", data.total);
    setText("stat-kind", JSON.stringify(data.by_kind));
    setText("stat-install", JSON.stringify(data.by_install_status));
  } catch (err) {
    setText("stat-total", "读取失败：" + err.message);
  }
  await refreshPending();
}

/*
 * 「待确认操作」与「失败任务」从操作历史统计，不使用占位数字：
 * 没有数据就显示 0，读取失败则显式说明失败，绝不假装是 0。
 */
async function refreshPending() {
  try {
    const data = await getJSON("/api/operations?limit=200");
    const items = data.items || [];
    const pendingStatuses = ["pending", "awaiting_confirmation", "approved"];
    const pending = items.filter((op) => pendingStatuses.indexOf(op.status) >= 0).length;
    const failed = items.filter((op) => op.status === "failed").length;
    setText("stat-pending", pending);
    setText("stat-failed", failed);
  } catch (err) {
    setText("stat-pending", "读取失败：" + err.message);
    setText("stat-failed", "读取失败：" + err.message);
  }
}

function renderPluginRows(items) {
  const tbody = document.getElementById("plugin-rows");
  const empty = document.getElementById("plugin-empty");
  clear(tbody);
  if (!items.length) {
    empty.hidden = false;
    return;
  }
  empty.hidden = true;
  for (const p of items) {
    const tr = document.createElement("tr");
    tr.appendChild(el("td", null, p.name));
    tr.appendChild(el("td", null, p.kind));
    tr.appendChild(el("td", "risk-" + p.risk_level, p.risk_level));
    tr.appendChild(el("td", null, p.review_status));
    tr.appendChild(el("td", null, p.install_status));
    const score = p.score && p.score.total !== undefined ? p.score.total : "—";
    tr.appendChild(el("td", null, score));
    tbody.appendChild(tr);
  }
}

async function refreshPlugins() {
  const tbody = document.getElementById("plugin-rows");
  const empty = document.getElementById("plugin-empty");
  try {
    const data = await getJSON("/api/plugins?limit=100");
    renderPluginRows(data.items);
    // 同时刷新"已安装"页
    renderInstalled(data.items);
    // 最近变更：取最后更新的一条
    if (data.items.length) {
      const latest = data.items
        .slice()
        .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)))[0];
      setText("stat-recent", latest.name + " @ " + fmtTime(latest.updated_at));
    } else {
      setText("stat-recent", "—");
    }
  } catch (err) {
    clear(tbody);
    empty.hidden = false;
    empty.textContent = "读取失败：" + err.message;
  }
}

function renderInstalled(items) {
  const tbody = document.getElementById("installed-rows");
  const empty = document.getElementById("installed-empty");
  clear(tbody);
  if (!items.length) {
    empty.hidden = false;
    return;
  }
  empty.hidden = true;
  for (const p of items) {
    const tr = document.createElement("tr");
    tr.appendChild(el("td", null, p.name));
    tr.appendChild(el("td", null, p.install_status));
    tr.appendChild(el("td", null, p.pinned_ref || "未固定"));
    tr.appendChild(el("td", null, p.installed_path || "—"));
    tr.appendChild(el("td", null, fmtTime(p.updated_at)));
    const actionCell = document.createElement("td");
    if (p.install_status === "succeeded") {
      actionCell.appendChild(actionButton("卸载", () => requestPlan("uninstall", p.id)));
      if (p.rollback_available) {
        actionCell.appendChild(actionButton("回滚", () => requestPlan("rollback", p.id)));
      }
    } else {
      actionCell.appendChild(actionButton("安装", () => requestPlan("install", p.id)));
    }
    tr.appendChild(actionCell);
    tbody.appendChild(tr);
  }
}

async function refreshAudit() {
  const list = document.getElementById("audit-list");
  if (!list) {
    return;
  }
  clear(list);
  try {
    const data = await getJSON("/api/audit?limit=20");
    for (const row of data.items) {
      list.appendChild(auditItem(row));
    }
  } catch (err) {
    list.appendChild(el("li", null, "读取失败：" + err.message));
  }
}

function auditItem(row) {
  const li = document.createElement("li");
  li.appendChild(el("span", "actor", row.actor));
  li.appendChild(document.createTextNode(" · " + row.action + " · "));
  li.appendChild(el("span", row.outcome, row.outcome));
  li.appendChild(document.createTextNode(" · " + (row.target || "-")));
  if (row.detail) {
    li.appendChild(document.createTextNode(" · " + row.detail));
  }
  return li;
}

async function refreshTasks() {
  const list = document.getElementById("task-list");
  if (!list) {
    return;
  }
  clear(list);
  try {
    const data = await getJSON("/api/tasks?limit=50");
    if (!data.items.length) {
      list.appendChild(el("li", null, "暂无操作历史。"));
      return;
    }
    for (const row of data.items) {
      list.appendChild(auditItem(row));
    }
  } catch (err) {
    list.appendChild(el("li", null, "读取失败：" + err.message));
  }
}

/* ------------------------------------------------------------------ */
/* 发现：搜索 / 检查 / 审查 / 对比                                      */
/* ------------------------------------------------------------------ */

let candidates = [];
const selected = new Set();

function buildSearchParams() {
  const params = new URLSearchParams();
  params.set("q", document.getElementById("q").value.trim());
  const language = document.getElementById("language").value.trim();
  if (language) {
    params.set("language", language);
  }
  const minStars = document.getElementById("min_stars").value.trim();
  if (minStars !== "") {
    params.set("min_stars", minStars);
  }
  const pushedAfter = document.getElementById("pushed_after").value.trim();
  if (pushedAfter) {
    params.set("pushed_after", pushedAfter);
  }
  const topic = document.getElementById("topic").value.trim();
  if (topic) {
    params.set("topic", topic);
  }
  const limit = document.getElementById("limit").value.trim();
  params.set("limit", limit || "10");
  return params;
}

async function previewQuery() {
  const status = document.getElementById("search-status");
  const preview = document.getElementById("query-preview");
  try {
    const data = await getJSON("/api/query?" + buildSearchParams().toString());
    preview.hidden = false;
    clear(preview);
    preview.appendChild(el("span", "label", "检索式："));
    preview.appendChild(el("code", null, data.github_query));
    if (data.keywords && data.keywords.length) {
      preview.appendChild(document.createTextNode(" · 关键词：" + data.keywords.join(", ")));
    }
    for (const note of data.notes || []) {
      preview.appendChild(el("span", "note-line", note));
    }
    status.hidden = true;
  } catch (err) {
    status.hidden = false;
    status.textContent = "预览失败：" + err.message;
  }
}

async function doSearch(event) {
  if (event) {
    event.preventDefault();
  }
  const status = document.getElementById("search-status");
  status.hidden = false;
  status.textContent = "搜索中…";
  try {
    const data = await getJSON("/api/search?" + buildSearchParams().toString());
    candidates = data.items || [];
    selected.clear();
    updateSelectedCount();
    renderCandidates();
    status.textContent = "检索式：" + data.query + " · 命中 " + data.count + " 个候选（均为待审查）。";
  } catch (err) {
    status.textContent = "搜索失败：" + err.message;
  }
}

function updateSelectedCount() {
  setText("selected-count", "已选 " + selected.size + " 项");
  const btn = document.getElementById("btn-compare");
  btn.disabled = selected.size < 2;
}

function renderCandidates() {
  const tbody = document.getElementById("candidate-rows");
  const empty = document.getElementById("candidate-empty");
  clear(tbody);
  if (!candidates.length) {
    empty.hidden = false;
    return;
  }
  empty.hidden = true;
  for (const p of candidates) {
    const tr = document.createElement("tr");

    const checkCell = document.createElement("td");
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = selected.has(p.id);
    box.addEventListener("change", () => {
      if (box.checked) {
        selected.add(p.id);
      } else {
        selected.delete(p.id);
      }
      updateSelectedCount();
    });
    checkCell.appendChild(box);
    tr.appendChild(checkCell);

    tr.appendChild(el("td", null, p.name));

    const repoCell = document.createElement("td");
    if (p.repository) {
      const a = document.createElement("a");
      a.href = p.repository;
      a.textContent = p.repository;
      a.rel = "noopener noreferrer";
      a.target = "_blank";
      repoCell.appendChild(a);
    } else {
      repoCell.textContent = "—";
    }
    tr.appendChild(repoCell);

    tr.appendChild(el("td", null, p.kind));
    tr.appendChild(el("td", null, fmtTime(p.updated_at)));
    tr.appendChild(el("td", null, p.license && p.license.spdx_id ? p.license.spdx_id : "未知"));
    tr.appendChild(el("td", null, p.pinned_ref ? p.pinned_ref.slice(0, 10) : "未固定"));
    const score = p.score && p.score.total !== undefined ? p.score.total : "—";
    tr.appendChild(el("td", null, score));
    tr.appendChild(el("td", "risk-" + p.risk_level, p.risk_level));
    tr.appendChild(el("td", null, p.review_status));
    tr.appendChild(el("td", null, p.install_status));

    const actionCell = document.createElement("td");
    actionCell.appendChild(actionButton("检查", () => inspectPlugin(p.id)));
    actionCell.appendChild(actionButton("审查", () => reviewPlugin(p.id)));
    actionCell.appendChild(actionButton("详情", () => showDetail(p.id)));
    if (p.install_status === "succeeded") {
      actionCell.appendChild(actionButton("卸载", () => requestPlan("uninstall", p.id)));
      if (p.rollback_available) {
        actionCell.appendChild(actionButton("回滚", () => requestPlan("rollback", p.id)));
      }
    } else {
      actionCell.appendChild(actionButton("申请安装", () => requestPlan("install", p.id)));
    }
    tr.appendChild(actionCell);

    tbody.appendChild(tr);
  }
}

function actionButton(label, handler) {
  const btn = el("button", "mini", label);
  btn.type = "button";
  btn.addEventListener("click", handler);
  return btn;
}

function findCandidate(id) {
  return candidates.find((p) => p.id === id) || null;
}

async function inspectPlugin(id) {
  const status = document.getElementById("search-status");
  status.hidden = false;
  status.textContent = "检查中（获取固定 commit 与仓库结构）…";
  try {
    const updated = await getJSON("/api/plugins/" + encodeURIComponent(id) + "/inspect");
    replaceCandidate(updated);
    status.textContent =
      "检查完成 · 固定 commit：" + (updated.pinned_ref || "未能确定") +
      " · 缺失字段：" + ((updated.missing_fields || []).join("、") || "无");
  } catch (err) {
    status.textContent = "检查失败：" + err.message;
  }
}

async function reviewPlugin(id) {
  const status = document.getElementById("search-status");
  status.hidden = false;
  status.textContent = "审查中（仅读取固定 commit 下的文件做静态扫描，不执行任何代码）…";
  try {
    const updated = await getJSON("/api/plugins/" + encodeURIComponent(id) + "/review");
    replaceCandidate(updated);
    const report = updated.security_report || {};
    status.textContent =
      "审查完成 · 覆盖 " + (report.coverage || "none") +
      " · 风险 " + updated.risk_level +
      " · 发现 " + ((report.findings || []).length) + " 条" +
      (report.vetoed ? " · 已被一票否决" : "");
    showDetail(id);
  } catch (err) {
    status.textContent = "审查失败：" + err.message;
  }
}

function replaceCandidate(updated) {
  const index = candidates.findIndex((p) => p.id === updated.id);
  if (index >= 0) {
    candidates[index] = updated;
  } else {
    candidates.push(updated);
  }
  renderCandidates();
  refreshPlugins();
}

async function compareSelected() {
  const box = document.getElementById("compare-result");
  box.hidden = false;
  clear(box);
  box.appendChild(el("p", "note", "对比中…"));
  try {
    const ids = Array.from(selected).join(",");
    const data = await getJSON("/api/compare?ids=" + encodeURIComponent(ids));
    clear(box);
    box.appendChild(el("h3", null, "对比结果（陈述性证据，不做最佳推荐）"));

    const table = document.createElement("table");
    const thead = document.createElement("thead");
    const headRow = document.createElement("tr");
    for (const name of ["名称", "评分", "风险", "许可证", "固定 commit", "缺失字段"]) {
      headRow.appendChild(el("th", null, name));
    }
    thead.appendChild(headRow);
    table.appendChild(thead);

    const tbody = document.createElement("tbody");
    for (const row of data.rows || []) {
      const tr = document.createElement("tr");
      tr.appendChild(el("td", null, row.name));
      tr.appendChild(el("td", null, row.score_total));
      tr.appendChild(el("td", "risk-" + row.risk_level, row.risk_level));
      tr.appendChild(el("td", null, row.license || "未知"));
      tr.appendChild(el("td", null, row.pinned_ref ? row.pinned_ref.slice(0, 10) : "未固定"));
      tr.appendChild(el("td", null, (row.missing_fields || []).join("、") || "无"));
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    box.appendChild(table);

    if ((data.highlights || []).length) {
      const ul = document.createElement("ul");
      ul.className = "audit";
      for (const line of data.highlights) {
        ul.appendChild(el("li", null, line));
      }
      box.appendChild(ul);
    }
    for (const note of data.notes || []) {
      box.appendChild(el("p", "note", note));
    }
  } catch (err) {
    clear(box);
    box.appendChild(el("p", "note", "对比失败：" + err.message));
  }
}

/* ------------------------------------------------------------------ */
/* 详情                                                                */
/* ------------------------------------------------------------------ */

function showDetail(id) {
  const panel = document.getElementById("detail-panel");
  const p = findCandidate(id);
  if (!p) {
    return;
  }
  panel.hidden = false;
  clear(panel);

  panel.appendChild(el("h3", null, "详情：" + p.name));

  const meta = document.createElement("dl");
  meta.className = "stats";
  const rows = [
    ["来源", p.source],
    ["类型", p.kind],
    ["仓库", p.repository || "—"],
    ["许可证", (p.license && p.license.spdx_id) || "未知"],
    ["许可证来源", (p.license && p.license.source) || "—"],
    ["固定 commit", p.pinned_ref || "未固定（审查前必须固定）"],
    ["最近更新", fmtTime(p.updated_at)],
    ["数据获取时间", fmtTime(p.fetched_at)],
    ["评分", (p.score && p.score.total !== undefined) ? p.score.total : "—"],
    ["风险", p.risk_level],
    ["审查状态", p.review_status],
    ["缺失字段", (p.missing_fields || []).join("、") || "无"],
  ];
  for (const [key, value] of rows) {
    meta.appendChild(el("dt", null, key));
    meta.appendChild(el("dd", null, value));
  }
  panel.appendChild(meta);

  if (p.score && (p.score.reasons || []).length) {
    panel.appendChild(el("h4", null, "评分依据"));
    const ul = document.createElement("ul");
    ul.className = "audit";
    for (const reason of p.score.reasons) {
      ul.appendChild(el("li", null, reason));
    }
    panel.appendChild(ul);
  }

  const report = p.security_report;
  if (!report) {
    panel.appendChild(el("p", "note", "尚未做安全审查。未审查不代表安全。"));
    return;
  }

  panel.appendChild(el("h4", null, "安全审查报告"));
  panel.appendChild(el("p", "note",
    "覆盖范围：" + report.coverage +
    " · 风险：" + report.risk_level +
    (report.vetoed ? " · 已被一票否决" : "") +
    " · 扫描文件 " + (report.scanned_files || []).length +
    " · 跳过 " + (report.skipped_files || []).length));

  if ((report.findings || []).length) {
    const table = document.createElement("table");
    const thead = document.createElement("thead");
    const headRow = document.createElement("tr");
    for (const name of ["规则", "严重度", "文件", "行", "原因", "证据等级"]) {
      headRow.appendChild(el("th", null, name));
    }
    thead.appendChild(headRow);
    table.appendChild(thead);
    const tbody = document.createElement("tbody");
    for (const f of report.findings) {
      const tr = document.createElement("tr");
      tr.appendChild(el("td", null, f.rule_id));
      tr.appendChild(el("td", "risk-" + f.severity, f.severity));
      tr.appendChild(el("td", null, f.file));
      tr.appendChild(el("td", null, f.line === null || f.line === undefined ? "—" : f.line));
      tr.appendChild(el("td", null, f.reason));
      tr.appendChild(el("td", null, f.evidence));
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    panel.appendChild(table);
  } else {
    panel.appendChild(el("p", "note", "未命中任何已知模式——这仅说明未命中，不代表不存在风险。"));
  }

  for (const note of report.notes || []) {
    panel.appendChild(el("p", "note", note));
  }
}

/* ------------------------------------------------------------------ */
/* 操作：生成计划 → 人工确认 → 执行                                    */
/* ------------------------------------------------------------------ */

const ACTION_LABELS = {
  install: "安装",
  uninstall: "卸载",
  rollback: "回滚",
};

/* 当前正在处理的操作（计划 → 确认 → 执行） */
let currentOperation = null;
/* 确认后由服务端一次性下发的令牌；仅内存持有，用于紧随其后的执行。 */
let confirmationToken = null;

function actionLabel(action) {
  return ACTION_LABELS[action] || action;
}

function showOperationPanel() {
  activateTab("overview");
  show("operation-title", true);
  show("operation-panel", true);
  const panel = document.getElementById("operation-panel");
  if (panel) {
    panel.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function operationMessage(text) {
  const panel = document.getElementById("operation-panel");
  showOperationPanel();
  clear(panel);
  panel.appendChild(el("p", "note", text));
}

function definitionRows(container, rows) {
  const dl = document.createElement("dl");
  dl.className = "stats";
  for (const [key, value] of rows) {
    dl.appendChild(el("dt", null, key));
    dl.appendChild(el("dd", null, value));
  }
  container.appendChild(dl);
}

function bulletList(container, lines) {
  if (!lines.length) {
    return;
  }
  const ul = document.createElement("ul");
  ul.className = "audit";
  for (const line of lines) {
    ul.appendChild(el("li", null, line));
  }
  container.appendChild(ul);
}

function simpleTable(container, headers, rows) {
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");
  for (const name of headers) {
    headRow.appendChild(el("th", null, name));
  }
  thead.appendChild(headRow);
  table.appendChild(thead);
  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const cell of row) {
      tr.appendChild(el("td", null, cell));
    }
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);
  container.appendChild(table);
}

async function requestPlan(action, pluginId) {
  currentOperation = null;
  confirmationToken = null;
  operationMessage("正在生成" + actionLabel(action) + "计划…");
  try {
    const op = await postJSON("/api/" + action + "/plan", { plugin_id: pluginId });
    currentOperation = op;
    renderOperation();
  } catch (err) {
    operationMessage(actionLabel(action) + "计划生成失败：" + err.message);
  }
}

function renderOperation() {
  const op = currentOperation;
  const panel = document.getElementById("operation-panel");
  showOperationPanel();
  clear(panel);
  if (!op) {
    return;
  }

  const plan = op.plan || {};
  panel.appendChild(el("h3", null,
    actionLabel(op.action) + "计划 · " + (plan.plugin_name || op.plugin_id)));

  definitionRows(panel, [
    ["操作 ID", op.id],
    ["插件 ID", op.plugin_id],
    ["动作", actionLabel(op.action)],
    ["状态", op.status],
    ["发起人", op.actor],
    ["创建时间", fmtTime(op.created_at)],
  ]);

  if (op.plan) {
    definitionRows(panel, [
      ["类型", plan.kind],
      ["来源", plan.source],
      ["固定 commit", plan.pinned_ref ? String(plan.pinned_ref).slice(0, 12) : "未固定"],
      ["目标目录", plan.target_dir],
      ["配置路径", plan.config_path || "—"],
      ["需要网络", plan.network_required ? "是" : "否"],
      ["会启动进程", plan.spawns_process ? "是" : "否"],
      ["计划摘要", plan.plan_digest ? String(plan.plan_digest).slice(0, 16) : "—"],
    ]);

    const files = plan.files || [];
    panel.appendChild(el("h4", null, "文件变更（" + files.length + " 个）"));
    if (files.length) {
      simpleTable(
        panel,
        ["相对路径", "动作", "大小", "sha256"],
        files.map((f) => [
          f.path,
          f.action,
          f.size,
          f.sha256 ? String(f.sha256).slice(0, 12) : "—",
        ])
      );
    } else {
      panel.appendChild(el("p", "note", "本计划不含文件变更。"));
    }

    const commands = plan.commands || [];
    panel.appendChild(el("h4", null, "将执行的命令（" + commands.length + " 条）"));
    if (commands.length) {
      bulletList(panel, commands.map((c) => c.argv.join(" ") + " —— " + c.purpose));
    } else {
      panel.appendChild(el("p", "note",
        "本计划不含任何命令：本系统默认禁止自动执行仓库里的安装脚本。"));
    }

    const perms = plan.permissions || [];
    const runtime = plan.runtime_requirements || [];
    if (perms.length || runtime.length) {
      panel.appendChild(el("h4", null, "权限与运行时要求"));
      bulletList(
        panel,
        perms.map((p) => "权限：" + p).concat(runtime.map((r) => "运行时：" + r))
      );
    }

    const review = plan.review || {};
    if (Object.keys(review).length) {
      panel.appendChild(el("h4", null, "安全审查摘要"));
      bulletList(
        panel,
        Object.entries(review).map(([key, value]) => [
          key,
          typeof value === "object" ? JSON.stringify(value) : String(value),
        ].join("："))
      );
    }

    if (plan.rollback_plan) {
      panel.appendChild(el("h4", null, "回滚方式"));
      panel.appendChild(el("p", "note", plan.rollback_plan));
    }
    if (plan.failure_handling) {
      panel.appendChild(el("h4", null, "失败处理"));
      panel.appendChild(el("p", "note", plan.failure_handling));
    }
    for (const note of plan.notes || []) {
      panel.appendChild(el("p", "note", note));
    }
  }

  if (op.result) {
    panel.appendChild(el("h4", null, "执行结果"));
    panel.appendChild(el("p", "note", JSON.stringify(op.result)));
  }
  if (op.error) {
    panel.appendChild(el("h4", null, "错误"));
    panel.appendChild(el("p", "note", op.error));
  }

  const actions = el("div", "actions", null);
  if (op.status === "awaiting_confirmation" || op.status === "pending") {
    if (confirmationToken) {
      actions.appendChild(opButton("执行（已确认）", "primary", executeCurrent));
    } else {
      actions.appendChild(opButton("确认并执行", "primary", confirmAndExecute));
      actions.appendChild(opButton("仅确认（不执行）", "ghost", confirmOnly));
    }
    actions.appendChild(opButton("取消此操作", "ghost", cancelCurrent));
  } else if (op.status === "approved") {
    actions.appendChild(opButton("执行", "primary", executeCurrent));
    actions.appendChild(opButton("取消此操作", "ghost", cancelCurrent));
  }
  panel.appendChild(actions);

  panel.appendChild(el("p", "note",
    "确认令牌绑定当前计划摘要：计划一旦变化（例如重新生成），原令牌立即失效。"));
}

function opButton(label, className, handler) {
  const btn = el("button", className || "mini", label);
  btn.type = "button";
  btn.addEventListener("click", handler);
  return btn;
}

async function confirmOnly() {
  const op = currentOperation;
  if (!op) {
    return;
  }
  operationMessage("正在确认计划…");
  try {
    const data = await postJSON(
      "/api/operations/" + encodeURIComponent(op.id) + "/confirm", {}
    );
    confirmationToken = data.confirmation_token;
    currentOperation = Object.assign({}, op, { status: "approved" });
    renderOperation();
    const panel = document.getElementById("operation-panel");
    panel.appendChild(el("p", "note",
      "已确认（令牌已下发，仅保存在本页内存中）。点击「执行」才会真正落地变更。"));
  } catch (err) {
    operationMessage("确认失败：" + err.message);
  }
}

async function confirmAndExecute() {
  await confirmOnly();
  if (confirmationToken) {
    await executeCurrent();
  }
}

async function executeCurrent() {
  const op = currentOperation;
  if (!op || !confirmationToken) {
    operationMessage("缺少确认令牌，无法执行。请重新生成计划并确认。");
    return;
  }
  operationMessage("正在执行…");
  try {
    const updated = await postJSON(
      "/api/operations/" + encodeURIComponent(op.id) + "/execute",
      { confirmation_token: confirmationToken }
    );
    currentOperation = updated;
    confirmationToken = null;
    renderOperation();
    refreshAll();
  } catch (err) {
    // 令牌是一次性的：执行失败后必须重新生成计划并重新确认。
    confirmationToken = null;
    currentOperation = Object.assign({}, op, { error: err.message });
    renderOperation();
  }
}

async function cancelCurrent() {
  const op = currentOperation;
  if (!op) {
    return;
  }
  operationMessage("正在取消…");
  try {
    const updated = await postJSON(
      "/api/operations/" + encodeURIComponent(op.id) + "/cancel", {}
    );
    currentOperation = updated;
    confirmationToken = null;
    renderOperation();
    refreshAll();
  } catch (err) {
    operationMessage("取消失败：" + err.message);
  }
}

/* ------------------------------------------------------------------ */
/* SSE 实时事件                                                        */
/* ------------------------------------------------------------------ */

let eventSource = null;

function appendEvent(event) {
  const list = document.getElementById("event-log");
  if (!list) {
    return;
  }
  const li = el("li", null, null);
  li.appendChild(el("span", "actor", event.type));
  li.appendChild(document.createTextNode(" · " + fmtTime(event.ts)));
  const data = event.data || {};
  const parts = [];
  for (const key of ["action", "actor", "outcome", "target", "detail", "query", "count",
                     "plugin_id", "path", "index", "total", "risk", "vetoed", "error"]) {
    if (data[key] !== undefined && data[key] !== null) {
      parts.push(key + "=" + data[key]);
    }
  }
  if (parts.length) {
    li.appendChild(document.createTextNode(" · " + parts.join(" ")));
  }
  list.insertBefore(li, list.firstChild);
  while (list.childNodes.length > 200) {
    list.removeChild(list.lastChild);
  }
}

function connectSSE() {
  const status = document.getElementById("sse-status");
  if (!window.EventSource) {
    status.textContent = "实时事件：当前浏览器不支持 EventSource";
    return;
  }
  try {
    eventSource = new EventSource("/api/events");
  } catch (err) {
    status.textContent = "实时事件：连接失败（" + err.message + "）";
    return;
  }
  eventSource.onopen = () => {
    status.textContent = "实时事件：已连接";
    status.className = "health ok";
  };
  eventSource.onerror = () => {
    status.textContent = "实时事件：连接中断，浏览器将自动重连";
    status.className = "health err";
  };
  const types = [
    "audit", "search.started", "search.finished", "search.failed",
    "review.started", "review.progress", "review.finished",
  ];
  for (const type of types) {
    eventSource.addEventListener(type, (msg) => {
      try {
        appendEvent(JSON.parse(msg.data));
      } catch (err) {
        appendEvent({ type: type, ts: new Date().toISOString(), data: { raw: msg.data } });
      }
    });
  }
}

/* ------------------------------------------------------------------ */
/* Tab 与初始化                                                        */
/* ------------------------------------------------------------------ */

const PANELS = {
  overview: "panel-overview",
  discover: "panel-discover",
  installed: "panel-installed",
  tasks: "panel-tasks",
};

function activateTab(name) {
  for (const [key, id] of Object.entries(PANELS)) {
    show(id, key === name);
  }
  const tabs = document.querySelectorAll("#tabs .tab");
  tabs.forEach((tab) => {
    if (tab.dataset.tab === name) {
      tab.classList.add("active");
    } else {
      tab.classList.remove("active");
    }
  });
  if (name === "tasks") {
    refreshTasks();
  }
}

async function refreshAll() {
  await refreshHealth();
  await refreshStats();
  await refreshPlugins();
  await refreshAudit();
}

document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("tabs").addEventListener("click", (event) => {
    const tab = event.target.closest(".tab");
    if (tab) {
      activateTab(tab.dataset.tab);
    }
  });

  const form = document.getElementById("search-form");
  form.addEventListener("submit", doSearch);
  document.getElementById("btn-preview").addEventListener("click", previewQuery);
  document.getElementById("btn-compare").addEventListener("click", compareSelected);

  refreshAll();
  connectSSE();
  window.setInterval(refreshAll, 15000);
});