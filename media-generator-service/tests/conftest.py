from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.settings import clear_settings_cache


@pytest.fixture(autouse=True)
def configured_service(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("MEDIA_GENERATION_PYTHON_SHARED_SECRET", "test-shared-secret")
    monkeypatch.setenv("MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS", "300")
    monkeypatch.setenv("MEDIA_GENERATION_PYTHON_SERVICE_NAME", "klass-media-generator")
    monkeypatch.setenv("MEDIA_GENERATION_PYTHON_SERVICE_VERSION", "0.1.0")
    clear_settings_cache()
    yield
    clear_settings_cache()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def running_client() -> TestClient:
    """``TestClient`` whose lifespan (and warm Marp/Chromium sidecar) is active.

    The default ``client`` fixture deliberately does **not** enter the app
    lifespan, so the sidecar stays ``None`` and the "without sidecar" graceful
    paths can be exercised.  PDF/preview integration tests need the real
    rendering pipeline, so they use this fixture instead — it runs the startup
    sequence (which spawns and warms the sidecar) and tears it down on exit.
    """
    with TestClient(app) as client:
        yield client
