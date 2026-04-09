from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.cache import (
    AdapterCacheService,
    DELIVERY_CACHE_TABLE_NAME,
    INTERPRETATION_CACHE_TABLE_NAME,
    CacheEntry,
    build_cache_lock_id,
    build_cache_upsert_params,
    build_interpretation_cache_key,
    get_cache_route_config,
    wait_for_inflight_cache_result,
)
from app.models import InterpretationRequest
from app.settings import clear_settings_cache, get_settings


def interpretation_payload(generation_id: str) -> dict[str, object]:
    return {
        "request_type": "media_prompt_interpretation",
        "generation_id": generation_id,
        "model": "llm-gateway",
        "instruction": "Return exactly one JSON object.",
        "input": {
            "teacher_prompt": "Buatkan handout pecahan untuk kelas 5.",
            "preferred_output_type": "pdf",
            "subject_context": {
                "id": 10,
                "name": "Matematika",
                "slug": "matematika",
            },
            "sub_subject_context": {
                "id": 11,
                "name": "Pecahan",
                "slug": "pecahan",
            },
        },
    }


class _FakeCacheCursor:
    def __init__(self, connection: "_FakeCacheConnection") -> None:
        self.connection = connection
        self._rows: list[object] = []

    def execute(self, query: str, params: object | None = None) -> None:
        normalized_query = " ".join(query.split())
        self.connection.executed_queries.append((normalized_query, params))

        if "SELECT pg_try_advisory_lock" in normalized_query:
            lock_id = params[0]
            self._rows = [{"acquired": self.connection.try_lock(int(lock_id))}]
            return

        if "SELECT pg_advisory_unlock" in normalized_query:
            lock_id = params[0]
            self._rows = [{"released": self.connection.release_lock(int(lock_id))}]
            return

        table_name = self._resolve_table_name(normalized_query)

        if normalized_query.startswith("DELETE FROM") and "cache_key = %(cache_key)s" in normalized_query:
            deleted_rows = self.connection.delete_expired_by_key(
                table_name,
                str(params["cache_key"]),
                params["now"],
            )
            self._rows = deleted_rows
            return

        if normalized_query.startswith("UPDATE") and "SET hit_count = hit_count + 1" in normalized_query:
            row = self.connection.touch_active_entry(
                table_name,
                str(params["cache_key"]),
                params["now"],
            )
            self._rows = [row] if row is not None else []
            return

        if normalized_query.startswith("SELECT cache_key"):
            row = self.connection.select_active_entry(
                table_name,
                str(params["cache_key"]),
                params["now"],
            )
            self._rows = [row] if row is not None else []
            return

        if normalized_query.startswith("INSERT INTO"):
            self._rows = [self.connection.upsert_entry(table_name, params)]
            return

        if normalized_query.startswith("WITH expired AS"):
            self._rows = self.connection.cleanup_expired(
                table_name,
                params["now"],
                int(params["limit"]),
            )
            return

        raise AssertionError(f"Unhandled query: {normalized_query}")

    def fetchone(self) -> object | None:
        return self._rows[0] if self._rows else None

    def fetchall(self) -> list[object]:
        return list(self._rows)

    def __enter__(self) -> "_FakeCacheCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False

    def _resolve_table_name(self, normalized_query: str) -> str:
        if INTERPRETATION_CACHE_TABLE_NAME in normalized_query:
            return INTERPRETATION_CACHE_TABLE_NAME

        if DELIVERY_CACHE_TABLE_NAME in normalized_query:
            return DELIVERY_CACHE_TABLE_NAME

        raise AssertionError(f"Could not resolve table name from query: {normalized_query}")


class _FakeCacheConnection:
    def __init__(self) -> None:
        self.executed_queries: list[tuple[str, object | None]] = []
        self.tables = {
            INTERPRETATION_CACHE_TABLE_NAME: {},
            DELIVERY_CACHE_TABLE_NAME: {},
        }
        self.locked_ids: set[int] = set()
        self._next_id = 1

    def cursor(self, *args, **kwargs) -> _FakeCacheCursor:
        return _FakeCacheCursor(self)

    def seed_entry(
        self,
        table_name: str,
        *,
        cache_key: str,
        request_payload: dict[str, object],
        response_payload: dict[str, object],
        created_at: datetime,
        expires_at: datetime,
        hit_count: int = 0,
        last_hit_at: datetime | None = None,
    ) -> None:
        self.tables[table_name][cache_key] = {
            "id": self._allocate_id(),
            "cache_key": cache_key,
            "request_payload": dict(request_payload),
            "response_payload": dict(response_payload),
            "created_at": created_at,
            "expires_at": expires_at,
            "hit_count": hit_count,
            "last_hit_at": last_hit_at,
        }

    def upsert_entry(self, table_name: str, params: dict[str, object]) -> dict[str, object]:
        cache_key = str(params["cache_key"])
        existing = self.tables[table_name].get(cache_key)
        entry_id = existing["id"] if existing is not None else self._allocate_id()
        row = {
            "id": entry_id,
            "cache_key": cache_key,
            "request_payload": dict(params["request_payload"]),
            "response_payload": dict(params["response_payload"]),
            "created_at": params["created_at"],
            "expires_at": params["expires_at"],
            "hit_count": 0,
            "last_hit_at": None,
        }
        self.tables[table_name][cache_key] = row
        return self._copy_row(row)

    def select_active_entry(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> dict[str, object] | None:
        row = self.tables[table_name].get(cache_key)
        if row is None or row["expires_at"] <= now:
            return None

        return self._copy_row(row)

    def touch_active_entry(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> dict[str, object] | None:
        row = self.tables[table_name].get(cache_key)
        if row is None or row["expires_at"] <= now:
            return None

        row["hit_count"] += 1
        row["last_hit_at"] = now
        return self._copy_row(row)

    def delete_expired_by_key(
        self,
        table_name: str,
        cache_key: str,
        now: datetime,
    ) -> list[dict[str, int]]:
        row = self.tables[table_name].get(cache_key)
        if row is None or row["expires_at"] > now:
            return []

        del self.tables[table_name][cache_key]
        return [{"id": int(row["id"])}]

    def cleanup_expired(
        self,
        table_name: str,
        now: datetime,
        limit: int,
    ) -> list[dict[str, int]]:
        expired_rows = sorted(
            [
                row
                for row in self.tables[table_name].values()
                if row["expires_at"] <= now
            ],
            key=lambda item: item["expires_at"],
        )[:limit]

        deleted_rows: list[dict[str, int]] = []
        for row in expired_rows:
            del self.tables[table_name][row["cache_key"]]
            deleted_rows.append({"id": int(row["id"])})

        return deleted_rows

    def try_lock(self, lock_id: int) -> bool:
        if lock_id in self.locked_ids:
            return False

        self.locked_ids.add(lock_id)
        return True

    def release_lock(self, lock_id: int) -> bool:
        if lock_id not in self.locked_ids:
            return False

        self.locked_ids.remove(lock_id)
        return True

    def _allocate_id(self) -> int:
        current_id = self._next_id
        self._next_id += 1
        return current_id

    def _copy_row(self, row: dict[str, object]) -> dict[str, object]:
        return {
            "cache_key": row["cache_key"],
            "request_payload": dict(row["request_payload"]),
            "response_payload": dict(row["response_payload"]),
            "created_at": row["created_at"],
            "expires_at": row["expires_at"],
            "hit_count": row["hit_count"],
            "last_hit_at": row["last_hit_at"],
        }


def test_cache_key_changes_when_schema_version_changes() -> None:
    payload = InterpretationRequest.model_validate(interpretation_payload("gen-1"))

    first_key = build_interpretation_cache_key(
        payload,
        provider="gemini",
        model="gemini-2.0-flash",
        schema_version="llm_adapter_cache.v1",
    )
    second_key = build_interpretation_cache_key(
        payload,
        provider="gemini",
        model="gemini-2.0-flash",
        schema_version="llm_adapter_cache.v2",
    )

    assert first_key != second_key


def test_cache_key_changes_when_provider_or_model_changes() -> None:
    payload = InterpretationRequest.model_validate(interpretation_payload("gen-2"))

    base_key = build_interpretation_cache_key(
        payload,
        provider="gemini",
        model="gemini-2.0-flash",
    )
    provider_key = build_interpretation_cache_key(
        payload,
        provider="openai",
        model="gemini-2.0-flash",
    )
    model_key = build_interpretation_cache_key(
        payload,
        provider="gemini",
        model="gemini-2.5-flash",
    )

    assert base_key != provider_key
    assert base_key != model_key


def test_cache_route_config_uses_distinct_ttls(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS", "7200")
    monkeypatch.setenv("LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS", "900")
    clear_settings_cache()
    settings = get_settings()

    interpretation_config = get_cache_route_config("interpret", settings)
    delivery_config = get_cache_route_config("respond", settings)

    assert interpretation_config.ttl_seconds == 7200
    assert delivery_config.ttl_seconds == 900


def test_build_cache_upsert_params_uses_route_specific_expiration(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS", "1800")
    clear_settings_cache()
    settings = get_settings()
    created_at = datetime(2026, 4, 9, 8, 0, 0, tzinfo=timezone.utc)

    params = build_cache_upsert_params(
        "interpret",
        cache_key="a" * 64,
        request_payload={"request": 1},
        response_payload={"response": 1},
        created_at=created_at,
        settings=settings,
    )

    assert params["created_at"] == created_at
    assert params["expires_at"] == created_at + timedelta(seconds=1800)


def test_cache_service_store_and_lookup_entry_updates_hit_count(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS", "600")
    monkeypatch.setenv("LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS", "0")
    clear_settings_cache()
    settings = get_settings()
    connection = _FakeCacheConnection()
    service = AdapterCacheService(settings=settings, monotonic=lambda: 1.0)
    now = datetime(2026, 4, 9, 8, 30, 0, tzinfo=timezone.utc)

    stored_entry = service.store_entry(
        "interpret",
        "k" * 64,
        request_payload={"request": 1},
        response_payload={"response": 1},
        now=now,
        connection=connection,
    )
    loaded_entry = service.lookup_entry(
        "interpret",
        "k" * 64,
        now=now + timedelta(seconds=5),
        connection=connection,
    )

    assert stored_entry.expires_at == now + timedelta(seconds=600)
    assert loaded_entry is not None
    assert loaded_entry.hit_count == 1
    assert loaded_entry.last_hit_at == now + timedelta(seconds=5)


def test_cache_service_lookup_deletes_expired_entry_before_returning(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS", "0")
    clear_settings_cache()
    settings = get_settings()
    connection = _FakeCacheConnection()
    service = AdapterCacheService(settings=settings, monotonic=lambda: 1.0)
    now = datetime(2026, 4, 9, 9, 0, 0, tzinfo=timezone.utc)
    connection.seed_entry(
        INTERPRETATION_CACHE_TABLE_NAME,
        cache_key="e" * 64,
        request_payload={"request": 1},
        response_payload={"response": 1},
        created_at=now - timedelta(minutes=20),
        expires_at=now - timedelta(minutes=1),
    )

    loaded_entry = service.lookup_entry(
        "interpret",
        "e" * 64,
        now=now,
        connection=connection,
    )

    assert loaded_entry is None
    assert "e" * 64 not in connection.tables[INTERPRETATION_CACHE_TABLE_NAME]


def test_cache_service_cleanup_expired_entries_limits_each_route(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE", "1")
    clear_settings_cache()
    settings = get_settings()
    connection = _FakeCacheConnection()
    service = AdapterCacheService(settings=settings, monotonic=lambda: 10.0)
    now = datetime(2026, 4, 9, 10, 0, 0, tzinfo=timezone.utc)

    for index in range(2):
        connection.seed_entry(
            INTERPRETATION_CACHE_TABLE_NAME,
            cache_key=f"i{index}".ljust(64, "i"),
            request_payload={"request": index},
            response_payload={"response": index},
            created_at=now - timedelta(hours=1),
            expires_at=now - timedelta(minutes=index + 1),
        )
        connection.seed_entry(
            DELIVERY_CACHE_TABLE_NAME,
            cache_key=f"d{index}".ljust(64, "d"),
            request_payload={"request": index},
            response_payload={"response": index},
            created_at=now - timedelta(hours=1),
            expires_at=now - timedelta(minutes=index + 1),
        )

    results = service.cleanup_expired_entries(now=now, connection=connection)

    assert tuple((result.route, result.deleted_count) for result in results) == (
        ("interpret", 1),
        ("respond", 1),
    )
    assert len(connection.tables[INTERPRETATION_CACHE_TABLE_NAME]) == 1
    assert len(connection.tables[DELIVERY_CACHE_TABLE_NAME]) == 1


def test_cache_service_lazy_cleanup_is_throttled(monkeypatch) -> None:
    monkeypatch.setenv("LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE", "10")
    monkeypatch.setenv("LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS", "60")
    clear_settings_cache()
    settings = get_settings()
    connection = _FakeCacheConnection()
    monotonic_clock = {"value": 100.0}
    service = AdapterCacheService(
        settings=settings,
        monotonic=lambda: monotonic_clock["value"],
    )
    now = datetime(2026, 4, 9, 11, 0, 0, tzinfo=timezone.utc)
    connection.seed_entry(
        INTERPRETATION_CACHE_TABLE_NAME,
        cache_key="z" * 64,
        request_payload={"request": 1},
        response_payload={"response": 1},
        created_at=now - timedelta(hours=1),
        expires_at=now - timedelta(minutes=1),
    )

    first_result = service.run_lazy_cleanup_if_due(now=now, connection=connection)
    first_query_count = len(connection.executed_queries)
    second_result = service.run_lazy_cleanup_if_due(now=now, connection=connection)

    assert tuple((result.route, result.deleted_count) for result in first_result) == (
        ("interpret", 1),
        ("respond", 0),
    )
    assert second_result == ()
    assert len(connection.executed_queries) == first_query_count


def test_wait_for_inflight_cache_result_returns_when_lookup_eventually_hits() -> None:
    state = {
        "calls": 0,
        "time": 0.0,
    }
    expected_entry = CacheEntry(
        cache_key="w" * 64,
        request_payload={"request": 1},
        response_payload={"response": 1},
        created_at=datetime(2026, 4, 9, 12, 0, 0, tzinfo=timezone.utc),
        expires_at=datetime(2026, 4, 9, 13, 0, 0, tzinfo=timezone.utc),
        hit_count=1,
        last_hit_at=datetime(2026, 4, 9, 12, 0, 1, tzinfo=timezone.utc),
    )

    def lookup_entry() -> CacheEntry | None:
        state["calls"] += 1
        if state["calls"] < 3:
            return None

        return expected_entry

    def monotonic() -> float:
        return state["time"]

    def sleep(seconds: float) -> None:
        state["time"] += seconds

    entry = wait_for_inflight_cache_result(
        lookup_entry,
        timeout_ms=500,
        poll_interval_ms=100,
        monotonic=monotonic,
        sleep=sleep,
    )

    assert entry == expected_entry
    assert state["calls"] == 3


def test_cache_lock_id_is_stable_and_route_specific() -> None:
    first_lock_id = build_cache_lock_id("interpret", "x" * 64)
    second_lock_id = build_cache_lock_id("interpret", "x" * 64)
    other_route_lock_id = build_cache_lock_id("respond", "x" * 64)

    assert first_lock_id == second_lock_id
    assert first_lock_id != other_route_lock_id


def test_cache_service_advisory_lock_round_trip() -> None:
    connection = _FakeCacheConnection()
    service = AdapterCacheService(settings=get_settings(), monotonic=lambda: 1.0)

    lock = service.try_acquire_inflight_lock(
        "interpret",
        "l" * 64,
        connection=connection,
    )
    released = service.release_inflight_lock(lock, connection=connection)

    assert lock.acquired is True
    assert released is True
