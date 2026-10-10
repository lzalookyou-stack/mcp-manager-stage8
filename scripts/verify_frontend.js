/*
 * 前端写操作链路验证：**真实加载 web/assets/app.js 这个文件**，
 * 用最小 DOM stub 驱动它，观察它能否正确完成
 * 「会话 → 计划 → 确认 → 执行」整条写链路。
 *
 * 为什么不复刻逻辑：复刻出来的代码只能证明"我以为的前端是对的"；
 * 加载真实文件才能发现前端与后端契约之间的真实偏差。
 *
 * 通常由 scripts/verify_frontend.sh 调用（它会准备独立实例与测试数据）。
 * 也可单独运行：
 *   FE_BASE=http://127.0.0.1:8799 \
 *   FE_PLUGIN_ID=<plugin_id> \
 *   FE_APP_JS=/path/to/web/assets/app.js \
 *   node scripts/verify_frontend.js
 *
 * 依赖：Node 18+（内置 fetch 与 vm 模块）。
 */

"use strict";

const fs = require("fs");
const vm = require("vm");

const BASE = process.env.FE_BASE || "http://127.0.0.1:8799";
const PLUGIN_ID = process.env.FE_PLUGIN_ID || "";
const APP_JS = process.env.FE_APP_JS || "web/assets/app.js";

let passCount = 0;
let failCount = 0;
function ok(msg) {
  console.log("PASS  " + msg);
  passCount += 1;
}
function bad(msg) {
  console.log("FAIL  " + msg);
  failCount += 1;
}

/* ------------------------------------------------------------------ */
/* 最小 DOM stub                                                       */
/* ------------------------------------------------------------------ */

function makeEl(tag) {
  const node = {
    tagName: tag,
    className: "",
    textContent: "",
    hidden: false,
    dataset: {},
    style: {},
    _children: [],
    appendChild(child) {
      this._children.push(child);
      return child;
    },
    removeChild(child) {
      this._children = this._children.filter((x) => x !== child);
      return child;
    },
    insertBefore(child) {
      this._children.unshift(child);
      return child;
    },
    addEventListener() {},
    scrollIntoView() {},
    setAttribute() {},
    get firstChild() {
      return this._children[0] || null;
    },
    get lastChild() {
      return this._children[this._children.length - 1] || null;
    },
    get childNodes() {
      return this._children;
    },
    classList: { add() {}, remove() {} },
  };
  return node;
}

const elements = new Map();
function getEl(id) {
  if (!elements.has(id)) {
    elements.set(id, makeEl("div"));
  }
  return elements.get(id);
}

const documentStub = {
  createElement: makeEl,
  createTextNode: (t) => ({ textContent: String(t) }),
  getElementById: getEl,
  querySelectorAll: () => [],
  addEventListener: () => {},
};

function textOf(node) {
  if (!node) {
    return "";
  }
  let out = node.textContent ? String(node.textContent) : "";
  for (const child of node._children || []) {
    out += " " + textOf(child);
  }
  return out;
}

/* ------------------------------------------------------------------ */
/* fetch：补全相对路径，并模拟浏览器自动添加的 Origin 头                */
/* ------------------------------------------------------------------ */

const realFetch = globalThis.fetch;

/*
 * Node 的 fetch 不实现 Cookie 罐：这里手动保存 /api/session 下发的会话 Cookie，
 * 并在后续请求里带上，模拟浏览器的同源行为。
 */
let cookieJar = "";

function feFetch(url, opts) {
  const abs = String(url).startsWith("http") ? String(url) : BASE + url;
  const options = Object.assign({}, opts || {});
  const headers = Object.assign({}, options.headers || {});
  if (cookieJar) {
    headers["Cookie"] = cookieJar;
  }
  if (options.method && options.method !== "GET") {
    // 浏览器会自动带 Origin；Node 环境需手动模拟，否则会被中间件拒绝。
    headers["Origin"] = BASE;
  }
  options.headers = headers;
  return realFetch(abs, options).then((resp) => {
    const setCookies = resp.headers.getSetCookie ? resp.headers.getSetCookie() : [];
    for (const line of setCookies) {
      const pair = String(line).split(";")[0];
      if (pair) {
        cookieJar = pair;
      }
    }
    return resp;
  });
}

/* ------------------------------------------------------------------ */
/* 加载真实前端脚本                                                    */
/* ------------------------------------------------------------------ */

const sandbox = {
  document: documentStub,
  window: { setInterval: () => 0 },
  fetch: feFetch,
  console,
  setTimeout,
  clearTimeout,
  URLSearchParams,
  Object,
  JSON,
  String,
  Number,
  Array,
  Error,
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

const source = fs.readFileSync(APP_JS, "utf8");
vm.runInContext(source, sandbox, { filename: "app.js" });
ok("已加载真实前端脚本 app.js");

const required = ["ensureSession", "postJSON", "requestPlan", "confirmAndExecute", "cancelCurrent"];
const missing = required.filter((name) => typeof sandbox[name] !== "function");
if (missing.length) {
  bad("前端缺少预期函数：" + missing.join(", "));
} else {
  ok("前端导出预期函数：" + required.join(", "));
}

/*
 * 剥离注释后再做静态检查：本文件的注释里正好在**描述**这些约定
 * （例如"不使用 innerHTML"），直接全文正则会误报。
 * `//` 的匹配排除前一个字符是 `:` 的情况，避免破坏 http:// 这类 URL。
 */
function stripComments(src) {
  return String(src)
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/(^|[^:])\/\/[^\n]*/g, "$1 ");
}

/* ------------------------------------------------------------------ */
/* 驱动完整写链路                                                      */
/* ------------------------------------------------------------------ */

(async () => {
  // 1) 建立会话
  let csrf = null;
  try {
    csrf = await sandbox.ensureSession();
    if (csrf) {
      ok("ensureSession() 拿到 CSRF 令牌（长度 " + String(csrf).length + "）");
    } else {
      bad("ensureSession() 未返回令牌");
    }
  } catch (err) {
    bad("ensureSession() 失败：" + err.message);
  }

  // 2) 生成安装计划
  try {
    await sandbox.requestPlan("install", PLUGIN_ID);
    const panel = textOf(getEl("operation-panel"));
    if (panel.indexOf("awaiting_confirmation") >= 0) {
      ok("requestPlan('install') 生成计划，状态 awaiting_confirmation");
    } else {
      bad("计划面板未显示 awaiting_confirmation：" + panel.slice(0, 200));
    }
    if (panel.indexOf("文件变更") >= 0) {
      ok("计划面板渲染了文件变更区");
    } else {
      bad("计划面板缺少文件变更区");
    }
    if (panel.indexOf("确认并执行") >= 0) {
      ok("计划面板渲染了确认按钮文案");
    } else {
      bad("计划面板缺少确认按钮");
    }
  } catch (err) {
    bad("requestPlan() 抛错：" + err.message);
  }

  // 3) 确认并执行
  try {
    await sandbox.confirmAndExecute();
    const panel = textOf(getEl("operation-panel"));
    if (panel.indexOf("succeeded") >= 0) {
      ok("confirmAndExecute() 执行成功，状态 succeeded");
    } else {
      bad("执行后状态不是 succeeded：" + panel.slice(0, 300));
    }
  } catch (err) {
    bad("confirmAndExecute() 抛错：" + err.message);
  }

  // 4) 安全断言：页面文本中不得出现确认令牌
  const allText = textOf(getEl("operation-panel")) + textOf(getEl("audit-list"));
  if (allText.indexOf("confirmation_token") >= 0 || allText.indexOf("confirmationToken") >= 0) {
    bad("页面文本中出现了确认令牌字段名");
  } else {
    ok("页面文本中不含确认令牌字段名");
  }

  // 5) 静态安全：剥离注释后再检测真实用法，避免把注释里的约定说明误判为用法
  const code = stripComments(source);
  if (/localStorage|sessionStorage/.test(code)) {
    bad("app.js 使用了 localStorage / sessionStorage");
  } else {
    ok("app.js 未使用 localStorage / sessionStorage（令牌不落盘）");
  }
  if (/innerHTML|insertAdjacentHTML|eval\(|new Function/.test(code)) {
    bad("app.js 使用了 innerHTML / eval 一类危险 API");
  } else {
    ok("app.js 未使用 innerHTML / insertAdjacentHTML / eval / new Function");
  }

  console.log("");
  console.log("结果：" + (failCount === 0 ? "全部通过" : "存在失败"));
  console.log("通过 " + passCount + " 项，失败 " + failCount + " 项");
  process.exit(failCount === 0 ? 0 : 1);
})();
