from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.settings import clear_settings_cache


class _FakeCursor:
    def execute(self, query: str) -> None:
        self.query = query

    def fetchone(self) -> tuple[int]:
        return (1,)

    def __enter__(self) -> "_FakeCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


class _FakeConnection:
    def cursor(self) -> _FakeCursor:
        return _FakeCursor()

    def __enter__(self) -> "_FakeConnection":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


@pytest.fixture(autouse=True)
def configured_service(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv(
        "LLM_ADAPTER_DATABASE_URL",
        "postgresql://adapter:secret@db.example:5432/llm_adapter",
    )
    monkeypatch.setenv("LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS", "3")
    monkeypatch.setenv("LLM_ADAPTER_DATABASE_POOL_MIN_SIZE", "1")
    monkeypatch.setenv("LLM_ADAPTER_DATABASE_POOL_MAX_SIZE", "5")
    monkeypatch.setenv("LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS", "300")
    monkeypatch.setenv("LLM_ADAPTER_DATABASE_AUTO_MIGRATE", "false")
    monkeypatch.setenv("LLM_ADAPTER_SERVICE_NAME", "klass-llm-adapter")
    monkeypatch.setenv("LLM_ADAPTER_SERVICE_VERSION", "0.1.0")
    monkeypatch.setenv("LLM_ADAPTER_LOG_LEVEL", "info")
    monkeypatch.setenv("LLM_ADAPTER_SHARED_SECRET", "test-shared-secret")
    monkeypatch.setenv("LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS", "300")
    monkeypatch.setenv("LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS", "30")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER", "gemini")
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_API_KEY", "test-gemini-api-key")
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_BASE_URL", "https://generativelanguage.googleapis.com")
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_API_VERSION", "v1beta")
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_INTERPRET_MODEL", "gemini-2.0-flash")
    monkeypatch.setenv("LLM_ADAPTER_GEMINI_DELIVERY_MODEL", "gemini-2.0-flash")
    monkeypatch.delenv("LLM_ADAPTER_OPENAI_API_KEY", raising=False)
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_BASE_URL", "https://api.openai.com")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_INTERPRET_MODEL", "gpt-5.4")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_DELIVERY_MODEL", "gpt-5.4")
    monkeypatch.delenv("LLM_ADAPTER_OPENAI_ORGANIZATION", raising=False)
    monkeypatch.delenv("LLM_ADAPTER_OPENAI_PROJECT", raising=False)
    monkeypatch.setenv("LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE", "true")
    monkeypatch.delenv("LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER", raising=False)
    monkeypatch.delenv("LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER", raising=False)
    monkeypatch.delenv("LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES", raising=False)
    monkeypatch.setattr("app.database.psycopg.connect", lambda *args, **kwargs: _FakeConnection())
    clear_settings_cache()
    yield
    clear_settings_cache()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)
