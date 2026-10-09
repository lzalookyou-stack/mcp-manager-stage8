"""pytest 公共夹具。"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.config import load_settings  # noqa: E402
from app.runtime import Runtime  # noqa: E402

#: 会让 ``Runtime.create`` 自动装配 GitHub 客户端的环境变量。
#: 测试必须显式屏蔽它们，否则「未配置客户端时应显式失败」这类用例
#: 会随开发机 / CI 是否碰巧配了令牌而漂移——那样的测试结果是不可信的。
GITHUB_ENV_VARS = ("MCPM_GITHUB_TOKEN", "GITHUB_TOKEN")


@pytest.fixture(autouse=True)
def _isolate_env(monkeypatch):
    """全局兜底：任何测试都不得依赖进程环境里的 GitHub 令牌。

    测试若要验证「有令牌」的行为，必须**显式**通过 ``github=`` 参数注入，
    不能靠环境变量碰运气。
    """
    for name in GITHUB_ENV_VARS:
        monkeypatch.delenv(name, raising=False)


@pytest.fixture()
def settings(tmp_path: Path):
    """每个测试用独立的临时数据目录，互不污染。"""
    return load_settings(
        host="127.0.0.1",
        port=8765,
        db_path=tmp_path / "test.db",
        data_dir=tmp_path / "data",
    )


@pytest.fixture()
def runtime(settings):
    rt = Runtime.create(settings)
    assert rt.plugins._github is None, (
        "测试环境必须没有 GitHub 客户端；若需要，请显式注入 github= 参数"
    )
    yield rt
    rt.close()


@pytest.fixture()
def service(runtime):
    return runtime.plugins
