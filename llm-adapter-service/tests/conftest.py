from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from psycopg.types.json import Jsonb
from fastapi.testclient import TestClient

from app.cache import DELIVERY_CACHE_TABLE_NAME, INTERPRETATION_CACHE_TABLE_NAME
from app.main import app
from app.settings import clear_settings_cache


class _FakeCursor:
    def __init__(self, connection: "_FakeConnection") -> None:
        self.connection = connection
        self._rows: list[object] = []

    def execute_with_params(self, query: str, params: object | None) -> None:
        normalized_query = " ".join(query.split())
        self.connection.last_query = normalized_query

        if normalized_query.startswith("SELECT 1"):
            self._rows = [(1,)]
            return

        if normalized_query.startswith("SELECT pg_try_advisory_lock"):
            assert isinstance(params, tuple)
            self._rows = [{"acquired": self.connection.try_lock(int(params[0]))}]
            return

        if normalized_query.startswith("SELECT pg_advisory_unlock"):
            assert isinstance(params, tuple)
            self._rows = [{"released": self.connection.release_lock(int(params[0]))}]
            return

        if normalized_query.startswith("INSERT INTO rate_limit_policies"):
            assert isinstance(params, dict)
            now = datetime.now(timezone.utc)
            key = (
                str(params["scope_type"]),
                str(params["route"]),
                str(params["provider"]),
                str(params["model"]),
                str(params["window_unit"]),
            )
            row = self.connection.state.policies.get(key)

            if row is None:
                row = {
                    "id": self.connection.state.next_policy_id,
                    "created_at": now,
                }
                self.connection.state.next_policy_id += 1

            row.update(
                {
                    "scope_type": str(params["scope_type"]),
                    "strategy": str(params["strategy"]),
                    "route": str(params["route"]),
                    "provider": str(params["provider"]),
                    "model": str(params["model"]),
                    "window_unit": str(params["window_unit"]),
                    "max_requests": params["max_requests"],
                    "max_input_tokens": params["max_input_tokens"],
                    "max_output_tokens": params["max_output_tokens"],
                    "max_total_tokens": params["max_total_tokens"],
                    "max_estimated_cost_usd": params["max_estimated_cost_usd"],
                    "enabled": bool(params["enabled"]),
                    "updated_at": now,
                }
            )
            self.connection.state.policies[key] = row
            self._rows = [dict(row)]
            return

        if normalized_query.startswith("INSERT INTO price_catalog_entries"):
            assert isinstance(params, dict)
            now = datetime.now(timezone.utc)
            key = (
                str(params["provider"]),
                str(params["model"]),
                params["effective_from"],
            )
            row = self.connection.state.price_catalog_entries.get(key)

            if row is None:
                row = {
                    "id": self.connection.state.next_price_catalog_id,
                    "created_at": now,
                }
                self.connection.state.next_price_catalog_id += 1

            row.update(
                {
                    "provider": str(params["provider"]),
                    "model": str(params["model"]),
                    "currency_code": str(params["currency_code"]),
                    "cost_unit": str(params["cost_unit"]),
                    "input_cost_per_unit_usd": params["input_cost_per_unit_usd"],
                    "output_cost_per_unit_usd": params["output_cost_per_unit_usd"],
                    "request_cost_usd": params["request_cost_usd"],
                    "effective_from": params["effective_from"],
                    "effective_to": params["effective_to"],
                    "is_active": True,
                    "updated_at": now,
                }
            )
            self.connection.state.price_catalog_entries[key] = row
            self._rows = [dict(row)]
            return

        if "FROM rate_limit_policies" in normalized_query:
            assert isinstance(params, dict)
            route = str(params["route"])
            provider = str(params["provider"])
            model = str(params["model"])
            rows = []

            for row in self.connection.state.policies.values():
                if not bool(row["enabled"]):
                    continue
                if row["route"] not in {route, "all"}:
                    continue
                if row["provider"] not in {provider, "*"}:
                    continue
                if row["model"] not in {model, "*"}:
                    continue
                rows.append(dict(row))

            window_order = {"minute": 1, "hour": 2, "day": 3}
            scope_order = {"route": 1, "provider": 2, "model": 3, "global": 4}
            rows.sort(
                key=lambda row: (
                    window_order.get(str(row["window_unit"]), 99),
                    scope_order.get(str(row["scope_type"]), 99),
                    int(row["id"]),
                )
            )
            self._rows = rows
            return

        if "FROM price_catalog_entries" in normalized_query:
            assert isinstance(params, dict)
            provider = str(params["provider"])
            model = str(params["model"])
            as_of = params["as_of"]
            candidate_rows = []

            for row in self.connection.state.price_catalog_entries.values():
                if row["provider"] != provider or row["model"] != model:
                    continue
                if not bool(row.get("is_active", True)):
                    continue
                if row["effective_from"] > as_of:
                    continue
                if row.get("effective_to") is not None and row["effective_to"] <= as_of:
                    continue
                candidate_rows.append(dict(row))

            candidate_rows.sort(key=lambda row: row["effective_from"], reverse=True)
            self._rows = candidate_rows[:1]
            return

        if normalized_query.startswith("INSERT INTO rate_limit_buckets"):
            assert isinstance(params, dict)
            now = datetime.now(timezone.utc)
            key = (int(params["policy_id"]), params["window_started_at"])
            row = self.connection.state.buckets.get(key)

            if row is None:
                row = {
                    "id": self.connection.state.next_bucket_id,
                    "policy_id": int(params["policy_id"]),
                    "scope_type": str(params["scope_type"]),
                    "strategy": str(params["strategy"]),
                    "route": str(params["route"]),
                    "provider": str(params["provider"]),
                    "model": str(params["model"]),
                    "window_unit": str(params["window_unit"]),
                    "window_started_at": params["window_started_at"],
                    "window_ends_at": params["window_ends_at"],
                    "request_count": 0,
                    "input_tokens": 0,
                    "output_tokens": 0,
                    "total_tokens": 0,
                    "estimated_cost_usd": Decimal("0"),
                    "deny_count": 0,
                    "created_at": now,
                }
                self.connection.state.next_bucket_id += 1

            row["request_count"] += int(params["request_count"])
            row["input_tokens"] += int(params["input_tokens"])
            row["output_tokens"] += int(params["output_tokens"])
            row["total_tokens"] += int(params["total_tokens"])
            row["estimated_cost_usd"] += Decimal(str(params["estimated_cost_usd"]))
            row["deny_count"] += int(params["deny_count"])
            row["last_request_id"] = params["last_request_id"] or row.get("last_request_id")
            row["last_generation_id"] = params["last_generation_id"] or row.get("last_generation_id")
            row["last_seen_at"] = params["last_seen_at"]
            row["updated_at"] = now
            self.connection.state.buckets[key] = row
            self._rows = [dict(row)]
            return

        if normalized_query.startswith("INSERT INTO llm_request_ledger"):
            assert isinstance(params, dict)
            now = datetime.now(timezone.utc)
            request_id = str(params["request_id"])
            row = self.connection.state.ledger_rows.get(request_id)

            if row is None:
                row = {
                    "id": self.connection.state.next_ledger_id,
                    "created_at": params["created_at"],
                }
                self.connection.state.next_ledger_id += 1

            row.update(
                {
                    "request_id": request_id,
                    "generation_id": str(params["generation_id"]),
                    "route": str(params["route"]),
                    "request_type": str(params["request_type"]),
                    "provider": str(params["provider"]),
                    "primary_provider": str(params["primary_provider"]),
                    "model": str(params["model"]),
                    "requested_model": str(params["requested_model"]),
                    "latency_ms": params["latency_ms"],
                    "retry_count": int(params["retry_count"]),
                    "cache_status": str(params["cache_status"]),
                    "final_status": str(params["final_status"]),
                    "error_class": params["error_class"],
                    "error_code": params["error_code"],
                    "fallback_used": bool(params["fallback_used"]),
                    "fallback_reason": params["fallback_reason"],
                    "attempted_providers": json.loads(str(params["attempted_providers"])),
                    "upstream_request_id": params["upstream_request_id"],
                    "provider_response_id": params["provider_response_id"],
                    "provider_model_version": params["provider_model_version"],
                    "finish_reason": params["finish_reason"],
                    "candidate_index": params["candidate_index"],
                    "input_tokens": params["input_tokens"],
                    "output_tokens": params["output_tokens"],
                    "total_tokens": params["total_tokens"],
                    "estimated_cost_usd": params["estimated_cost_usd"],
                    "cache_key": params["cache_key"],
                    "metadata": json.loads(str(params["metadata"])),
                    "completed_at": params["completed_at"],
                }
            )
            self.connection.state.ledger_rows[request_id] = row
            self._rows = [dict(row)]
            return

        table_name = self.connection.resolve_cache_table_name(normalized_query)
        if table_name is not None:
            assert isinstance(params, dict)

            if normalized_query.startswith("DELETE FROM") and "cache_key = %(cache_key)s" in normalized_query:
                self._rows = self.connection.delete_expired_cache_entry_by_key(
                    table_name,
                    str(params["cache_key"]),
                    params["now"],
                )
                return

            if normalized_query.startswith("UPDATE") and "SET hit_count = hit_count + 1" in normalized_query:
                row = self.connection.touch_active_cache_entry(
                    table_name,
                    str(params["cache_key"]),
                    params["now"],
                )
                self._rows = [row] if row is not None else []
                return

            if normalized_query.startswith("SELECT cache_key"):
                row = self.connection.select_active_cache_entry(
                    table_name,
                    str(params["cache_key"]),
                    params["now"],
                )
                self._rows = [row] if row is not None else []
                return

            if normalized_query.startswith("INSERT INTO"):
                self._rows = [self.connection.upsert_cache_entry(table_name, params)]
                return

            if normalized_query.startswith("WITH expired AS"):
                self._rows = self.connection.cleanup_expired_cache_entries(
                    table_name,
                    params["now"],
                    int(params["limit"]),
                )
                return

        if "FROM llm_request_daily_aggregates" in normalized_query:
            assert isinstance(params, dict)
            self._rows = _build_daily_aggregate_rows(
                self.connection.state,
                from_date=params["from_date"],
                to_date=params["to_date"],
            )
            return

        if "FROM llm_request_daily_route_aggregates" in normalized_query:
            assert isinstance(params, dict)
            self._rows = _build_daily_route_aggregate_rows(
                self.connection.state,
                from_date=params["from_date"],
                to_date=params["to_date"],
            )
            return

        if "ROUND(AVG(latency_ms), 2) AS average_latency_ms" in normalized_query and "GROUP BY route, provider, model" in normalized_query:
            assert isinstance(params, dict)
            self._rows = _build_provider_model_latency_rows(
                self.connection.state,
                from_date=params["from_date"],
                to_date=params["to_date"],
            )
            return

        if "ROUND(AVG(latency_ms), 2) AS average_latency_ms" in normalized_query and "GROUP BY route" in normalized_query:
            assert isinstance(params, dict)
            self._rows = _build_route_latency_rows(
                self.connection.state,
                from_date=params["from_date"],
                to_date=params["to_date"],
            )
            return

        if "FROM rate_limit_buckets AS bucket" in normalized_query:
            assert isinstance(params, dict)
            self._rows = _build_route_deny_summary_rows(
                self.connection.state,
                from_date=params["from_date"],
                to_date=params["to_date"],
            )
            return

        if "FROM rate_limit_buckets" in normalized_query:
            assert isinstance(params, dict)
            row = self.connection.state.buckets.get(
                (int(params["policy_id"]), params["window_started_at"])
            )
            self._rows = [dict(row)] if row is not None else []
            return

        self._rows = []

    def execute(self, query: str, params: object | None = None) -> None:
        self.execute_with_params(query, params)

    def fetchone(self) -> tuple[int]:
        if not self._rows:
            return None

        return self._rows[0]

    def fetchall(self) -> list[object]:
        return list(self._rows)

    def __enter__(self) -> "_FakeCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


class _FakeConnection:
    def __init__(self, state: "_FakeDatabaseState") -> None:
        self.state = state
        self.last_query: str | None = None

    def cursor(self, *args, **kwargs) -> _FakeCursor:
        return _FakeCursor(self)

    def __enter__(self) -> "_FakeConnection":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False

    def resolve_cache_table_name(self, normalized_query: str) -> str | None:
        if INTERPRETATION_CACHE_TABLE_NAME in normalized_query:
            return INTERPRETATION_CACHE_TABLE_NAME

        if DELIVERY_CACHE_TABLE_NAME in normalized_query:
            return DELIVERY_CACHE_TABLE_NAME

        return None

    def try_lock(self, lock_id: int) -> bool:
        if lock_id in self.state.locked_ids:
            return False

        self.state.locked_ids.add(lock_id)
        return True

    def release_lock(self, lock_id: int) -> bool:
        if lock_id not in self.state.locked_ids:
            return False

        self.state.locked_ids.remove(lock_id)
        return True

    def upsert_cache_entry(self, table_name: str, params: dict[str, object]) -> dict[str, object]:
        cache_key = str(params["cache_key"])
        existing = self.state.cache_tables[table_name].get(cache_key)
        entry_id = int(existing["id"]) if existing is not None else self.state.allocate_cache_entry_id()
        row = {
            "id": entry_id,
            "cache_key": cache_key,
            "request_payload": _unwrap_json_payload(params["request_payload"]),
            "response_payload": _unwrap_json_payload(params["response_payload"]),
            "created_at": params["created_at"],
            "expires_at": params["expires_at"],
            "hit_count": 0,
            "last_hit_at": None,
        }
        self.state.cache_tables[table_name][cache_key] = row
        return self.copy_cache_row(row)

    def select_active_cache_entry(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> dict[str, object] | None:
        row = self.state.cache_tables[table_name].get(cache_key)
        if row is None or row["expires_at"] <= now:
            return None

        return self.copy_cache_row(row)

    def touch_active_cache_entry(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> dict[str, object] | None:
        row = self.state.cache_tables[table_name].get(cache_key)
        if row is None or row["expires_at"] <= now:
            return None

        row["hit_count"] += 1
        row["last_hit_at"] = now
        return self.copy_cache_row(row)

    def delete_expired_cache_entry_by_key(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> list[dict[str, int]]:
        row = self.state.cache_tables[table_name].get(cache_key)
        if row is None or row["expires_at"] > now:
            return []

        del self.state.cache_tables[table_name][cache_key]
        return [{"id": int(row["id"])}]

    def cleanup_expired_cache_entries(
        self,
        table_name: str,
        now: datetime,
        limit: int,
    ) -> list[dict[str, int]]:
        expired_rows = sorted(
            [
                row
                for row in self.state.cache_tables[table_name].values()
                if row["expires_at"] <= now
            ],
            key=lambda item: item["expires_at"],
        )[:limit]

        deleted_rows: list[dict[str, int]] = []
        for row in expired_rows:
            del self.state.cache_tables[table_name][row["cache_key"]]
            deleted_rows.append({"id": int(row["id"])})

        return deleted_rows

    def copy_cache_row(self, row: dict[str, object]) -> dict[str, object]:
        return {
            "cache_key": row["cache_key"],
            "request_payload": dict(row["request_payload"]),
            "response_payload": dict(row["response_payload"]),
            "created_at": row["created_at"],
            "expires_at": row["expires_at"],
            "hit_count": row["hit_count"],
            "last_hit_at": row["last_hit_at"],
        }


class _FakePool:
    def __init__(self, state: "_FakeDatabaseState") -> None:
        self.state = state

    def connection(self) -> _FakeConnection:
        return _FakeConnection(self.state)


class _FakeDatabaseState:
    def __init__(self) -> None:
        self.policies: dict[tuple[str, str, str, str, str], dict[str, object]] = {}
        self.buckets: dict[tuple[int, object], dict[str, object]] = {}
        self.price_catalog_entries: dict[tuple[str, str, object], dict[str, object]] = {}
        self.ledger_rows: dict[str, dict[str, object]] = {}
        self.cache_tables = {
            INTERPRETATION_CACHE_TABLE_NAME: {},
            DELIVERY_CACHE_TABLE_NAME: {},
        }
        self.locked_ids: set[int] = set()
        self.next_policy_id = 1
        self.next_bucket_id = 1
        self.next_price_catalog_id = 1
        self.next_ledger_id = 1
        self.next_cache_entry_id = 1

    def allocate_cache_entry_id(self) -> int:
        current_id = self.next_cache_entry_id
        self.next_cache_entry_id += 1
        return current_id


@pytest.fixture
def fake_database_state() -> _FakeDatabaseState:
    return _FakeDatabaseState()


@pytest.fixture(autouse=True)
def configured_service(monkeypatch: pytest.MonkeyPatch, fake_database_state: _FakeDatabaseState):
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
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE", "30")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_HOUR", "600")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD", "25.00")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_DEFAULT_ESTIMATED_COST_USD", "0.025")
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_EXHAUSTED_ACTION", "deny")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_ROUTE_ENABLED", "true")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_REQUESTS_PER_MINUTE", "60")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_REQUESTS_PER_HOUR", "1200")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD", "10.00")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD", "0.010")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_EXHAUSTED_ACTION", "degrade")
    monkeypatch.setenv("LLM_ADAPTER_BUDGET_WARNING_RATIO", "0.80")
    monkeypatch.setattr(
        "app.database.psycopg.connect",
        lambda *args, **kwargs: _FakeConnection(fake_database_state),
    )
    monkeypatch.setattr(
        "app.governance.psycopg.connect",
        lambda *args, **kwargs: _FakeConnection(fake_database_state),
    )
    monkeypatch.setattr(
        "app.database.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    monkeypatch.setattr(
        "app.interpretation.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    monkeypatch.setattr(
        "app.delivery.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    monkeypatch.setattr(
        "app.draft.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    monkeypatch.setattr(
        "app.costs.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    monkeypatch.setattr(
        "app.cache.get_database_pool",
        lambda settings: _FakePool(fake_database_state),
    )
    clear_settings_cache()
    yield
    clear_settings_cache()


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def _build_daily_aggregate_rows(
    state: _FakeDatabaseState,
    *,
    from_date,
    to_date,
) -> list[dict[str, object]]:
    grouped: dict[tuple[object, str, str, str], list[dict[str, object]]] = {}

    for row in state.ledger_rows.values():
        usage_date = row["created_at"].date()
        if usage_date < from_date or usage_date > to_date:
            continue
        grouped.setdefault((usage_date, row["route"], row["provider"], row["model"]), []).append(row)

    result = []
    for key, rows in grouped.items():
        usage_date, route, provider, model = key
        cache_hit_count = sum(1 for row in rows if row["cache_status"] == "hit")
        cache_miss_count = sum(1 for row in rows if row["cache_status"] == "miss")
        cache_bypass_count = sum(1 for row in rows if row["cache_status"] == "bypass")
        request_count = len(rows)
        result.append(
            {
                "usage_date": usage_date,
                "route": route,
                "provider": provider,
                "model": model,
                "request_count": request_count,
                "cache_hit_count": cache_hit_count,
                "cache_miss_count": cache_miss_count,
                "cache_bypass_count": cache_bypass_count,
                "cache_hit_ratio": _ratio_decimal(cache_hit_count, request_count),
                "retry_volume": sum(int(row["retry_count"]) for row in rows),
                "fallback_count": sum(1 for row in rows if bool(row["fallback_used"])),
                "error_count": sum(1 for row in rows if row["final_status"] != "success"),
                "input_tokens": sum(int(row["input_tokens"] or 0) for row in rows),
                "output_tokens": sum(int(row["output_tokens"] or 0) for row in rows),
                "total_tokens": sum(int(row["total_tokens"] or 0) for row in rows),
                "estimated_cost_usd": sum(
                    (Decimal(str(row["estimated_cost_usd"])) if row["estimated_cost_usd"] is not None else Decimal("0"))
                    for row in rows
                ),
                "last_request_at": max(row["created_at"] for row in rows),
            }
        )

    result.sort(key=lambda row: (row["usage_date"], row["route"], row["provider"], row["model"]), reverse=True)
    return result


def _build_daily_route_aggregate_rows(
    state: _FakeDatabaseState,
    *,
    from_date,
    to_date,
) -> list[dict[str, object]]:
    grouped: dict[tuple[object, str], list[dict[str, object]]] = {}

    for provider_row in _build_daily_aggregate_rows(state, from_date=from_date, to_date=to_date):
        grouped.setdefault((provider_row["usage_date"], provider_row["route"]), []).append(provider_row)

    result = []
    for key, rows in grouped.items():
        usage_date, route = key
        request_count = sum(int(row["request_count"]) for row in rows)
        cache_hit_count = sum(int(row["cache_hit_count"]) for row in rows)
        cache_miss_count = sum(int(row["cache_miss_count"]) for row in rows)
        cache_bypass_count = sum(int(row["cache_bypass_count"]) for row in rows)
        result.append(
            {
                "usage_date": usage_date,
                "route": route,
                "request_count": request_count,
                "cache_hit_count": cache_hit_count,
                "cache_miss_count": cache_miss_count,
                "cache_bypass_count": cache_bypass_count,
                "cache_hit_ratio": _ratio_decimal(cache_hit_count, request_count),
                "retry_volume": sum(int(row["retry_volume"]) for row in rows),
                "fallback_count": sum(int(row["fallback_count"]) for row in rows),
                "error_count": sum(int(row["error_count"]) for row in rows),
                "input_tokens": sum(int(row["input_tokens"]) for row in rows),
                "output_tokens": sum(int(row["output_tokens"]) for row in rows),
                "total_tokens": sum(int(row["total_tokens"]) for row in rows),
                "estimated_cost_usd": sum(Decimal(str(row["estimated_cost_usd"])) for row in rows),
                "last_request_at": max(row["last_request_at"] for row in rows),
            }
        )

    result.sort(key=lambda row: (row["usage_date"], row["route"]), reverse=True)
    return result


def _build_route_latency_rows(
    state: _FakeDatabaseState,
    *,
    from_date,
    to_date,
) -> list[dict[str, object]]:
    grouped: dict[str, list[Decimal]] = {}

    for row in state.ledger_rows.values():
        usage_date = row["created_at"].date()
        if usage_date < from_date or usage_date > to_date:
            continue
        if row["latency_ms"] is None:
            continue
        grouped.setdefault(row["route"], []).append(Decimal(str(row["latency_ms"])))

    result = []
    for route, latencies in grouped.items():
        result.append(
            {
                "route": route,
                "average_latency_ms": float((sum(latencies) / Decimal(len(latencies))).quantize(Decimal("0.01"))),
            }
        )

    result.sort(key=lambda row: row["route"])
    return result


def _build_provider_model_latency_rows(
    state: _FakeDatabaseState,
    *,
    from_date,
    to_date,
) -> list[dict[str, object]]:
    grouped: dict[tuple[str, str, str], list[Decimal]] = {}

    for row in state.ledger_rows.values():
        usage_date = row["created_at"].date()
        if usage_date < from_date or usage_date > to_date:
            continue
        if row["latency_ms"] is None:
            continue
        grouped.setdefault((row["route"], row["provider"], row["model"]), []).append(Decimal(str(row["latency_ms"])))

    result = []
    for key, latencies in grouped.items():
        route, provider, model = key
        result.append(
            {
                "route": route,
                "provider": provider,
                "model": model,
                "average_latency_ms": float((sum(latencies) / Decimal(len(latencies))).quantize(Decimal("0.01"))),
            }
        )

    result.sort(key=lambda row: (row["route"], row["provider"], row["model"]))
    return result


def _unwrap_json_payload(value: object) -> dict[str, object]:
    if isinstance(value, Jsonb):
        return dict(value.obj)

    return dict(value)


def _build_route_deny_summary_rows(
    state: _FakeDatabaseState,
    *,
    from_date,
    to_date,
) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = {}

    for bucket in state.buckets.values():
        usage_date = bucket["window_started_at"].date()
        if usage_date < from_date or usage_date > to_date:
            continue
        if bucket["window_unit"] != "day":
            continue
        policy = next((row for row in state.policies.values() if int(row["id"]) == int(bucket["policy_id"])), None)
        if policy is None:
            continue
        if policy["scope_type"] != "route":
            continue
        if policy["route"] not in {"interpret", "respond"}:
            continue
        grouped.setdefault(policy["route"], []).append(bucket)

    result = []
    for route, buckets in grouped.items():
        deny_count = sum(int(bucket["deny_count"]) for bucket in buckets)
        allowed_request_count = sum(int(bucket["request_count"]) for bucket in buckets)
        result.append(
            {
                "route": route,
                "deny_count": deny_count,
                "allowed_request_count": allowed_request_count,
                "deny_rate": _ratio_decimal(deny_count, deny_count + allowed_request_count),
                "last_denied_at": max(bucket["last_seen_at"] for bucket in buckets),
            }
        )

    result.sort(key=lambda row: row["route"])
    return result


def _ratio_decimal(numerator: int, denominator: int) -> Decimal:
    if denominator <= 0:
        return Decimal("0")

    return (Decimal(numerator) / Decimal(denominator)).quantize(Decimal("0.000001"))
