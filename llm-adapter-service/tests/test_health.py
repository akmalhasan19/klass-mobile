from __future__ import annotations

from app.settings import clear_settings_cache


def test_health_endpoint_reports_ready_dependencies_and_auth(client) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.headers["X-Request-Id"] != ""

    payload = response.json()
    assert payload["schema_version"] == "llm_adapter_health.v1"
    assert payload["status"] == "ready"
    assert payload["ready"] is True
    assert payload["service_name"] == "klass-llm-adapter"
    assert payload["service_version"] == "0.1.0"
    assert payload["dependencies"]["postgres"]["configured"] is True
    assert payload["dependencies"]["postgres"]["ready"] is True
    assert payload["dependencies"]["postgres"]["driver"] == "postgresql"
    assert payload["dependencies"]["postgres"]["host"] == "db.example"
    assert payload["dependencies"]["providers"]["interpretation"]["provider"] == "gemini"
    assert payload["dependencies"]["providers"]["interpretation"]["ready"] is True
    assert payload["dependencies"]["providers"]["delivery"]["provider"] == "gemini"
    assert payload["dependencies"]["providers"]["delivery"]["ready"] is True
    assert payload["auth"]["configured"] is True
    assert payload["auth"]["ready"] is True
    assert payload["auth"]["signature_algorithm"] == "hmac-sha256"
    assert payload["governance"]["ready"] is True
    assert payload["governance"]["budget_warning_ratio"] == 0.8
    assert payload["governance"]["routes"][0]["route"] == "interpret"
    assert payload["governance"]["routes"][0]["request_limit_per_minute"] == 30
    assert payload["governance"]["routes"][0]["budget_status"] == "healthy"
    assert payload["governance"]["routes"][1]["route"] == "respond"
    assert payload["governance"]["routes"][1]["exhausted_action"] == "degrade"


def test_versioned_health_endpoint_reports_same_contract(client) -> None:
    response = client.get("/v1/health")

    assert response.status_code == 200

    payload = response.json()
    assert payload["schema_version"] == "llm_adapter_health.v1"
    assert payload["status"] == "ready"
    assert payload["ready"] is True
    assert payload["dependencies"]["providers"]["interpretation"]["route"] == "interpret"
    assert payload["dependencies"]["providers"]["delivery"]["route"] == "respond"
    assert payload["governance"]["routes"][1]["request_limit_per_hour"] == 1200


def test_health_endpoint_reports_rotation_state_when_previous_secret_is_configured(client, monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_SHARED_SECRET_PREVIOUS", "legacy-shared-secret")
    clear_settings_cache()

    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["auth"]["rotation_enabled"] is True
    assert payload["auth"]["accepted_secret_count"] == 2


def test_health_endpoint_returns_503_when_database_is_not_configured(client, monkeypatch) -> None:
    monkeypatch.delenv("LLM_ADAPTER_DATABASE_URL", raising=False)
    clear_settings_cache()

    response = client.get("/health")

    assert response.status_code == 503
    payload = response.json()
    assert payload["status"] == "degraded"
    assert payload["ready"] is False
    assert payload["dependencies"]["postgres"]["configured"] is False
    assert payload["dependencies"]["postgres"]["ready"] is False
    assert payload["dependencies"]["postgres"]["error"]["code"] == "database_url_missing"
    assert payload["governance"]["ready"] is False
    assert payload["governance"]["routes"][0]["budget_status"] == "unavailable"


def test_health_endpoint_returns_503_when_active_provider_is_missing_credentials(client, monkeypatch) -> None:
    monkeypatch.delenv("LLM_ADAPTER_GEMINI_API_KEY", raising=False)
    clear_settings_cache()

    response = client.get("/health")

    assert response.status_code == 503
    payload = response.json()
    assert payload["status"] == "degraded"
    assert payload["dependencies"]["providers"]["interpretation"]["ready"] is False
    assert payload["dependencies"]["providers"]["delivery"]["ready"] is False
    assert payload["dependencies"]["providers"]["interpretation"]["missing_settings"] == [
        "LLM_ADAPTER_GEMINI_API_KEY"
    ]


def test_health_endpoint_reports_openai_provider_ready_when_selected_via_active_route_config(client, monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER", "openai")
    monkeypatch.setenv("LLM_ADAPTER_OPENAI_API_KEY", "test-openai-key")
    clear_settings_cache()

    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["dependencies"]["providers"]["interpretation"]["provider"] == "openai"
    assert payload["dependencies"]["providers"]["interpretation"]["ready"] is True
    assert payload["dependencies"]["providers"]["delivery"]["provider"] == "openai"
    assert payload["dependencies"]["providers"]["delivery"]["ready"] is True


def test_health_endpoint_reports_delivery_route_disabled_for_operator_visibility(client, monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_ROUTE_ENABLED", "false")
    clear_settings_cache()

    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    delivery_route = payload["governance"]["routes"][1]
    assert delivery_route["route"] == "respond"
    assert delivery_route["enabled"] is False
    assert delivery_route["budget_status"] == "disabled"
