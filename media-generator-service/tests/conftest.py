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
