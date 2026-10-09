"""测试环境隔离（阶段 8 发现的真实缺陷的回归测试）。

背景：``Runtime.create()`` 会读取 ``MCPM_GITHUB_TOKEN`` / ``GITHUB_TOKEN``
环境变量并自动装配 GitHub 客户端。若测试夹具不屏蔽它们，以下用例
会随开发机 / CI 是否碰巧配了令牌而漂移：

- ``test_search_without_github_client_fails_loudly``
- ``test_search_without_client_raises``
- ``test_search_projects_fails_loudly_without_github``

这些用例的**前提**是「没有 GitHub 客户端」。前提不成立时它们会失败，
而失败原因与代码正确性无关——那样的测试结果不可信。

**验证方式**：本文件用 ``subprocess`` 起一个**真实带污染环境变量**的 pytest
子进程来跑那三个用例，断言退出码为 0。这是真实执行，不是自证。
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from app.runtime import Runtime

PROJECT_ROOT = Path(__file__).resolve().parent.parent

#: 必须与 ``tests/conftest.py`` 中的 ``GITHUB_ENV_VARS`` 保持一致。
GITHUB_ENV_VARS = ("MCPM_GITHUB_TOKEN", "GITHUB_TOKEN")

#: 前提是「没有 GitHub 客户端」的那三个用例。
DEPENDENT_TESTS = [
    "tests/test_plugin_service.py::test_search_without_github_client_fails_loudly",
    "tests/test_stage3_service.py::test_search_without_client_raises",
    "tests/test_stage7_mcp.py::test_search_projects_fails_loudly_without_github",
]


def test_conftest_declares_isolation_fixture():
    """conftest 必须声明屏蔽令牌环境变量的 autouse 夹具。"""
    source = (PROJECT_ROOT / "tests" / "conftest.py").read_text(encoding="utf-8")
    assert "autouse=True" in source, "conftest 缺少 autouse 夹具"
    for name in GITHUB_ENV_VARS:
        assert name in source, f"conftest 未屏蔽 {name}"


def test_dependent_tests_pass_with_polluted_env():
    """在**真实设置了令牌**的环境中，那三个用例必须依然通过。

    这是本缺陷的回归测试：修复前它们在污染环境下会失败，
    修复后（conftest 屏蔽环境变量）应全部通过。
    """
    env = dict(os.environ)
    for name in GITHUB_ENV_VARS:
        env[name] = "polluted-token-for-isolation-test"
    env["PYTHONPATH"] = str(PROJECT_ROOT)

    # 参数全部是硬编码常量 + 当前解释器，不接受任何外部输入。
    proc = subprocess.run(  # noqa: S603
        [sys.executable, "-m", "pytest", "-p", "no:cacheprovider", *DEPENDENT_TESTS],
        cwd=PROJECT_ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )
    assert proc.returncode == 0, (
        "在设置了令牌的环境下这些用例失败，说明测试隔离失效。\n"
        f"stdout:\n{proc.stdout[-3000:]}\n"
        f"stderr:\n{proc.stderr[-2000:]}"
    )
    # 必须真的跑了 3 个用例（而不是「一个都没收集到」也返回 0）
    assert "3 passed" in proc.stdout, proc.stdout[-2000:]


def test_runtime_has_no_github_client_by_default(runtime):
    """默认夹具装配的 Runtime 不得带 GitHub 客户端。"""
    assert runtime.plugins._github is None


def test_explicit_github_injection_still_works(settings):
    """需要 GitHub 客户端的测试必须能**显式**注入，而不是靠环境变量。"""
    from app.search.github_client import GitHubClient

    client = GitHubClient("explicit-token")
    rt = Runtime.create(settings, github=client)
    try:
        assert rt.plugins._github is client
    finally:
        rt.close()
