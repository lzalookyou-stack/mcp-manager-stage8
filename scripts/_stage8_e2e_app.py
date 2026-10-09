"""阶段 8 完整端到端验证用的应用工厂（**仅用于本地验证脚本**）。

与 ``app.runtime.Runtime.create`` 的唯一区别：把**安装执行器**与**适配器服务**
的文件来源都换成内存实现，从而在不依赖真实 GitHub 仓库的前提下，验证
「会话 → 计划 → 确认 → 执行 → 回滚 / 卸载」以及适配预览的**真实 HTTP 行为**。

生产装配仍然只使用 ``GitHubFileProvider``：未配置 GitHub 令牌时，
安装与适配预览都会**显式失败**（``install_unavailable``），不会伪造结果。
"""

from __future__ import annotations

import os

from app.config import load_settings
from app.install import Installer, InstallService, ManagedRoots
from app.install.provider import MemoryFileProvider
from app.models import Plugin
from app.runtime import Runtime
from app.services.adapter_service import AdapterService
from app.web.app import create_app as _create_app

_FILES = {
    "index.js": b"export const name = 'e2e-demo';\n",
    "package.json": b'{"name":"e2e-demo","version":"1.0.0"}\n',
    "lib/util.js": b"export const add = (a, b) => a + b;\n",
    "SKILL.md": (
        "---\n"
        "name: e2e-demo-skill\n"
        "description: 端到端验证用的演示 Skill\n"
        "---\n"
        "\n"
        "# 演示\n"
        "\n"
        "这是一个用于验证适配器预览的演示文件。\n"
    ).encode(),
}


def _memory_factory(plugin: Plugin) -> MemoryFileProvider:
    return MemoryFileProvider(dict(_FILES))


def create_app():  # type: ignore[no-untyped-def]
    settings = load_settings()
    runtime = Runtime.create(settings)

    roots = ManagedRoots.create(settings.data_dir)
    installer = Installer(runtime.conn, roots, provider_factory=_memory_factory)
    runtime.installs = InstallService(
        runtime.conn,
        installer,
        plugin_lookup=runtime.plugins.get,
        confirmation_ttl=settings.confirmation_ttl_seconds,
    )
    # 适配器预览也换成内存来源，否则会因缺少 GitHub 客户端而显式失败
    runtime.adapters = AdapterService(runtime.conn, provider_factory=_memory_factory)

    os.environ.setdefault("MCPM_E2E", "1")
    return _create_app(runtime)
