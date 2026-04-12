from __future__ import annotations

import argparse
import hashlib
import json
import time
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Literal

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from app.contracts import (
    DEFAULT_CACHE_KEY_SCHEMA_VERSION,
    INTERPRET_ROUTE,
    RESPOND_ROUTE,
)
from app.database import close_database_pool, get_database_pool
from app.models import ContentDraftRequest, DeliveryRequest, InterpretationRequest
from app.settings import Settings, get_settings

CacheRoute = Literal["interpret", "respond"]

CACHE_KEY_SCHEMA_VERSION = DEFAULT_CACHE_KEY_SCHEMA_VERSION
INTERPRETATION_CACHE_TABLE_NAME = "interpretation_cache_entries"
DELIVERY_CACHE_TABLE_NAME = "delivery_cache_entries"
_CACHE_LOCK_PERSON = b"klasscch"


@dataclass(frozen=True)
class CacheRouteConfig:
    route: CacheRoute
    table_name: str
    ttl_seconds: int


@dataclass(frozen=True)
class CacheEntry:
    cache_key: str
    request_payload: dict[str, Any]
    response_payload: dict[str, Any]
    created_at: datetime
    expires_at: datetime
    hit_count: int
    last_hit_at: datetime | None


@dataclass(frozen=True)
class CacheCleanupResult:
    route: CacheRoute
    deleted_count: int


@dataclass(frozen=True)
class CacheInFlightLock:
    route: CacheRoute
    cache_key: str
    lock_id: int
    acquired: bool


def get_cache_route_config(route: CacheRoute, settings: Settings) -> CacheRouteConfig:
    if route == INTERPRET_ROUTE:
        return CacheRouteConfig(
            route=route,
            table_name=INTERPRETATION_CACHE_TABLE_NAME,
            ttl_seconds=max(1, settings.interpretation_cache_ttl_seconds),
        )

    if route == RESPOND_ROUTE:
        return CacheRouteConfig(
            route=route,
            table_name=DELIVERY_CACHE_TABLE_NAME,
            ttl_seconds=max(1, settings.delivery_cache_ttl_seconds),
        )

    raise ValueError(f"Unsupported cache route: {route}")


def build_interpretation_cache_document(
    payload: InterpretationRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> dict[str, Any]:
    return _build_cache_document(
        schema_version=schema_version,
        route=INTERPRET_ROUTE,
        request_type=payload.request_type,
        provider=provider,
        model=model,
        instruction=payload.instruction,
        input_payload=payload.input.model_dump(mode="python"),
    )


def build_delivery_cache_document(
    payload: DeliveryRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> dict[str, Any]:
    return _build_cache_document(
        schema_version=schema_version,
        route=RESPOND_ROUTE,
        request_type=payload.request_type,
        provider=provider,
        model=model,
        instruction=payload.instruction,
        input_payload=payload.input.model_dump(mode="python"),
    )


def build_content_draft_cache_document(
    payload: ContentDraftRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> dict[str, Any]:
    return _build_cache_document(
        schema_version=schema_version,
        route=RESPOND_ROUTE,
        request_type=payload.request_type,
        provider=provider,
        model=model,
        instruction=payload.instruction,
        input_payload=payload.input.model_dump(mode="python"),
    )


def build_interpretation_cache_key(
    payload: InterpretationRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> str:
    return _hash_cache_document(
        build_interpretation_cache_document(
            payload,
            provider=provider,
            model=model,
            schema_version=schema_version,
        )
    )


def build_delivery_cache_key(
    payload: DeliveryRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> str:
    return _hash_cache_document(
        build_delivery_cache_document(
            payload,
            provider=provider,
            model=model,
            schema_version=schema_version,
        )
    )


def build_content_draft_cache_key(
    payload: ContentDraftRequest,
    *,
    provider: str,
    model: str,
    schema_version: str = CACHE_KEY_SCHEMA_VERSION,
) -> str:
    return _hash_cache_document(
        build_content_draft_cache_document(
            payload,
            provider=provider,
            model=model,
            schema_version=schema_version,
        )
    )


def build_cache_expiration(
    route: CacheRoute,
    *,
    created_at: datetime,
    settings: Settings,
) -> datetime:
    route_config = get_cache_route_config(route, settings)
    normalized_created_at = _normalize_datetime(created_at)
    return normalized_created_at + timedelta(seconds=route_config.ttl_seconds)


def build_cache_upsert_params(
    route: CacheRoute,
    *,
    cache_key: str,
    request_payload: dict[str, Any],
    response_payload: dict[str, Any],
    created_at: datetime,
    settings: Settings,
) -> dict[str, object]:
    normalized_created_at = _normalize_datetime(created_at)

    return {
        "cache_key": cache_key.strip(),
        "request_payload": Jsonb(request_payload),
        "response_payload": Jsonb(response_payload),
        "created_at": normalized_created_at,
        "expires_at": build_cache_expiration(
            route,
            created_at=normalized_created_at,
            settings=settings,
        ),
    }


def build_cache_lock_id(route: CacheRoute, cache_key: str) -> int:
    payload = f"{route}:{cache_key.strip()}".encode("utf-8")
    digest = hashlib.blake2b(payload, digest_size=8, person=_CACHE_LOCK_PERSON).digest()
    lock_id = int.from_bytes(digest, "big", signed=False)

    if lock_id >= 2**63:
        lock_id -= 2**64

    return lock_id or 1


def wait_for_inflight_cache_result(
    lookup_entry: Callable[[], CacheEntry | None],
    *,
    timeout_ms: int,
    poll_interval_ms: int,
    monotonic: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> CacheEntry | None:
    normalized_timeout_ms = max(0, timeout_ms)
    normalized_poll_interval_ms = max(1, poll_interval_ms)

    if normalized_timeout_ms == 0:
        return lookup_entry()

    deadline = monotonic() + (normalized_timeout_ms / 1000)

    while True:
        entry = lookup_entry()
        if entry is not None:
            return entry

        now = monotonic()
        if now >= deadline:
            return None

        sleep(min(normalized_poll_interval_ms / 1000, max(0.0, deadline - now)))


class AdapterCacheService:
    def __init__(
        self,
        settings: Settings | None = None,
        pool: ConnectionPool | None = None,
        *,
        monotonic: Callable[[], float] | None = None,
        sleep: Callable[[float], None] | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.pool = pool
        self._monotonic = monotonic or time.monotonic
        self._sleep = sleep or time.sleep
        self._last_lazy_cleanup_monotonic: float | None = None

    def route_config(self, route: CacheRoute) -> CacheRouteConfig:
        return get_cache_route_config(route, self.settings)

    def build_interpretation_cache_key(
        self,
        payload: InterpretationRequest,
        *,
        provider: str,
        model: str,
    ) -> str:
        return build_interpretation_cache_key(
            payload,
            provider=provider,
            model=model,
            schema_version=self.settings.cache_key_schema_version,
        )

    def build_delivery_cache_key(
        self,
        payload: DeliveryRequest,
        *,
        provider: str,
        model: str,
    ) -> str:
        return build_delivery_cache_key(
            payload,
            provider=provider,
            model=model,
            schema_version=self.settings.cache_key_schema_version,
        )

    def build_content_draft_cache_key(
        self,
        payload: ContentDraftRequest,
        *,
        provider: str,
        model: str,
    ) -> str:
        return build_content_draft_cache_key(
            payload,
            provider=provider,
            model=model,
            schema_version=self.settings.cache_key_schema_version,
        )

    def lookup_interpretation(
        self,
        payload: InterpretationRequest,
        *,
        provider: str,
        model: str,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
        increment_hit_count: bool = True,
    ) -> CacheEntry | None:
        return self.lookup_entry(
            INTERPRET_ROUTE,
            self.build_interpretation_cache_key(payload, provider=provider, model=model),
            now=now,
            connection=connection,
            increment_hit_count=increment_hit_count,
        )

    def lookup_delivery(
        self,
        payload: DeliveryRequest,
        *,
        provider: str,
        model: str,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
        increment_hit_count: bool = True,
    ) -> CacheEntry | None:
        return self.lookup_entry(
            RESPOND_ROUTE,
            self.build_delivery_cache_key(payload, provider=provider, model=model),
            now=now,
            connection=connection,
            increment_hit_count=increment_hit_count,
        )

    def lookup_entry(
        self,
        route: CacheRoute,
        cache_key: str,
        *,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
        increment_hit_count: bool = True,
        run_lazy_cleanup: bool = True,
    ) -> CacheEntry | None:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))

        if run_lazy_cleanup:
            self.run_lazy_cleanup_if_due(route=route, now=current_time, connection=connection)

        route_config = self.route_config(route)
        params = {
            "cache_key": cache_key.strip(),
            "now": current_time,
        }

        with self._connection_scope(connection) as active_connection:
            self._delete_expired_entry_by_key(active_connection, route_config, params)

            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(
                    _cache_touch_sql(route_config.table_name)
                    if increment_hit_count
                    else _cache_select_sql(route_config.table_name),
                    params,
                )
                row = cursor.fetchone()

        return _build_cache_entry(row)

    def store_interpretation_response(
        self,
        payload: InterpretationRequest,
        *,
        provider: str,
        model: str,
        response_payload: dict[str, Any],
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> CacheEntry:
        cache_key = self.build_interpretation_cache_key(payload, provider=provider, model=model)
        request_payload = build_interpretation_cache_document(
            payload,
            provider=provider,
            model=model,
            schema_version=self.settings.cache_key_schema_version,
        )

        return self.store_entry(
            INTERPRET_ROUTE,
            cache_key,
            request_payload=request_payload,
            response_payload=response_payload,
            now=now,
            connection=connection,
        )

    def store_delivery_response(
        self,
        payload: DeliveryRequest,
        *,
        provider: str,
        model: str,
        response_payload: dict[str, Any],
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> CacheEntry:
        cache_key = self.build_delivery_cache_key(payload, provider=provider, model=model)
        request_payload = build_delivery_cache_document(
            payload,
            provider=provider,
            model=model,
            schema_version=self.settings.cache_key_schema_version,
        )

        return self.store_entry(
            RESPOND_ROUTE,
            cache_key,
            request_payload=request_payload,
            response_payload=response_payload,
            now=now,
            connection=connection,
        )

    def store_entry(
        self,
        route: CacheRoute,
        cache_key: str,
        *,
        request_payload: dict[str, Any],
        response_payload: dict[str, Any],
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
        run_lazy_cleanup: bool = True,
    ) -> CacheEntry:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))

        if run_lazy_cleanup:
            self.run_lazy_cleanup_if_due(route=route, now=current_time, connection=connection)

        route_config = self.route_config(route)
        params = build_cache_upsert_params(
            route,
            cache_key=cache_key,
            request_payload=request_payload,
            response_payload=response_payload,
            created_at=current_time,
            settings=self.settings,
        )

        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute(_cache_upsert_sql(route_config.table_name), params)
                row = cursor.fetchone()

        cache_entry = _build_cache_entry(row)
        if cache_entry is None:
            raise RuntimeError("Cache upsert did not return a row.")

        return cache_entry

    def try_acquire_inflight_lock(
        self,
        route: CacheRoute,
        cache_key: str,
        *,
        connection: psycopg.Connection | None = None,
    ) -> CacheInFlightLock:
        lock_id = build_cache_lock_id(route, cache_key)

        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute("SELECT pg_try_advisory_lock(%s) AS acquired", (lock_id,))
                row = cursor.fetchone()

        return CacheInFlightLock(
            route=route,
            cache_key=cache_key.strip(),
            lock_id=lock_id,
            acquired=_extract_bool(row, key="acquired"),
        )

    def release_inflight_lock(
        self,
        lock: CacheInFlightLock,
        *,
        connection: psycopg.Connection | None = None,
    ) -> bool:
        if not lock.acquired:
            return False

        with self._connection_scope(connection) as active_connection:
            with active_connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute("SELECT pg_advisory_unlock(%s) AS released", (lock.lock_id,))
                row = cursor.fetchone()

        return _extract_bool(row, key="released")

    def wait_for_inflight_entry(
        self,
        route: CacheRoute,
        cache_key: str,
        *,
        timeout_ms: int | None = None,
        poll_interval_ms: int | None = None,
        connection: psycopg.Connection | None = None,
    ) -> CacheEntry | None:
        return wait_for_inflight_cache_result(
            lambda: self.lookup_entry(
                route,
                cache_key,
                connection=connection,
                increment_hit_count=True,
                run_lazy_cleanup=False,
            ),
            timeout_ms=self.settings.cache_stampede_wait_timeout_ms
            if timeout_ms is None
            else max(0, timeout_ms),
            poll_interval_ms=self.settings.cache_stampede_poll_interval_ms
            if poll_interval_ms is None
            else max(1, poll_interval_ms),
            monotonic=self._monotonic,
            sleep=self._sleep,
        )

    def cleanup_expired_entries(
        self,
        *,
        route: CacheRoute | None = None,
        limit: int | None = None,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> tuple[CacheCleanupResult, ...]:
        current_time = _normalize_datetime(now or datetime.now(timezone.utc))
        cleanup_limit = max(1, limit or self.settings.cache_cleanup_batch_size)
        routes = [route] if route is not None else [INTERPRET_ROUTE, RESPOND_ROUTE]
        results: list[CacheCleanupResult] = []

        with self._connection_scope(connection) as active_connection:
            for current_route in routes:
                route_config = self.route_config(current_route)
                with active_connection.cursor(row_factory=dict_row) as cursor:
                    cursor.execute(
                        _cache_cleanup_sql(route_config.table_name),
                        {
                            "now": current_time,
                            "limit": cleanup_limit,
                        },
                    )
                    deleted_rows = cursor.fetchall()

                results.append(
                    CacheCleanupResult(
                        route=current_route,
                        deleted_count=len(deleted_rows),
                    )
                )

        return tuple(results)

    def run_lazy_cleanup_if_due(
        self,
        *,
        route: CacheRoute | None = None,
        now: datetime | None = None,
        connection: psycopg.Connection | None = None,
    ) -> tuple[CacheCleanupResult, ...]:
        interval_seconds = max(0, self.settings.cache_lazy_cleanup_interval_seconds)
        current_monotonic = self._monotonic()

        if (
            interval_seconds > 0
            and self._last_lazy_cleanup_monotonic is not None
            and (current_monotonic - self._last_lazy_cleanup_monotonic) < interval_seconds
        ):
            return ()

        results = self.cleanup_expired_entries(
            route=route,
            limit=self.settings.cache_cleanup_batch_size,
            now=now,
            connection=connection,
        )
        self._last_lazy_cleanup_monotonic = current_monotonic
        return results

    @contextmanager
    def _connection_scope(self, connection: psycopg.Connection | None):
        if connection is not None:
            yield connection
            return

        pool = self.pool or get_database_pool(self.settings)
        with pool.connection() as pooled_connection:
            yield pooled_connection

    def _delete_expired_entry_by_key(
        self,
        connection: psycopg.Connection,
        route_config: CacheRouteConfig,
        params: dict[str, object],
    ) -> None:
        with connection.cursor() as cursor:
            cursor.execute(_cache_delete_expired_by_key_sql(route_config.table_name), params)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Klass LLM Adapter cache utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)
    cleanup_parser = subparsers.add_parser("cleanup")
    cleanup_parser.add_argument(
        "--route",
        choices=("all", INTERPRET_ROUTE, RESPOND_ROUTE),
        default="all",
    )
    cleanup_parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args(argv)
    settings = get_settings()
    service = AdapterCacheService(settings)

    try:
        results = service.cleanup_expired_entries(
            route=None if args.route == "all" else args.route,
            limit=args.limit,
        )
    finally:
        close_database_pool()

    for result in results:
        print(f"{result.route}:{result.deleted_count}")

    return 0


def _build_cache_document(
    *,
    schema_version: str,
    route: str,
    request_type: str,
    provider: str,
    model: str,
    instruction: str,
    input_payload: dict[str, Any],
) -> dict[str, Any]:
    return _normalize_value(
        {
            "schema_version": schema_version.strip() or CACHE_KEY_SCHEMA_VERSION,
            "route": route.strip(),
            "request_type": request_type.strip(),
            "provider": provider.strip().lower(),
            "model": model.strip(),
            "instruction": instruction.strip(),
            "input": input_payload,
        }
    )


def _hash_cache_document(document: dict[str, Any]) -> str:
    payload = json.dumps(
        document,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )

    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _normalize_value(value: Any) -> Any:
    if isinstance(value, dict):
        normalized_dict: dict[str, Any] = {}

        for key, raw_item in value.items():
            normalized_item = _normalize_value(raw_item)

            if normalized_item is None:
                continue

            normalized_dict[key] = normalized_item

        return normalized_dict

    if isinstance(value, list):
        return [_normalize_value(item) for item in value]

    if isinstance(value, str):
        return value.strip()

    return value


def _cache_select_sql(table_name: str) -> str:
    return f"""
    SELECT cache_key, request_payload, response_payload, created_at, expires_at, hit_count, last_hit_at
    FROM {table_name}
    WHERE cache_key = %(cache_key)s AND expires_at > %(now)s
    """.strip()


def _cache_touch_sql(table_name: str) -> str:
    return f"""
    UPDATE {table_name}
    SET hit_count = hit_count + 1,
        last_hit_at = %(now)s
    WHERE cache_key = %(cache_key)s AND expires_at > %(now)s
    RETURNING cache_key, request_payload, response_payload, created_at, expires_at, hit_count, last_hit_at
    """.strip()


def _cache_upsert_sql(table_name: str) -> str:
    return f"""
    INSERT INTO {table_name} (
        cache_key,
        request_payload,
        response_payload,
        created_at,
        expires_at,
        hit_count,
        last_hit_at
    ) VALUES (
        %(cache_key)s,
        %(request_payload)s,
        %(response_payload)s,
        %(created_at)s,
        %(expires_at)s,
        0,
        NULL
    )
    ON CONFLICT (cache_key)
    DO UPDATE SET
        request_payload = EXCLUDED.request_payload,
        response_payload = EXCLUDED.response_payload,
        created_at = EXCLUDED.created_at,
        expires_at = EXCLUDED.expires_at,
        hit_count = 0,
        last_hit_at = NULL
    RETURNING cache_key, request_payload, response_payload, created_at, expires_at, hit_count, last_hit_at
    """.strip()


def _cache_delete_expired_by_key_sql(table_name: str) -> str:
    return f"""
    DELETE FROM {table_name}
    WHERE cache_key = %(cache_key)s AND expires_at <= %(now)s
    RETURNING id
    """.strip()


def _cache_cleanup_sql(table_name: str) -> str:
    return f"""
    WITH expired AS (
        SELECT id
        FROM {table_name}
        WHERE expires_at <= %(now)s
        ORDER BY expires_at ASC
        LIMIT %(limit)s
    )
    DELETE FROM {table_name}
    USING expired
    WHERE {table_name}.id = expired.id
    RETURNING {table_name}.id
    """.strip()


def _build_cache_entry(row: dict[str, Any] | None) -> CacheEntry | None:
    if row is None:
        return None

    return CacheEntry(
        cache_key=str(row["cache_key"]),
        request_payload=dict(row["request_payload"]),
        response_payload=dict(row["response_payload"]),
        created_at=_normalize_datetime(row["created_at"]),
        expires_at=_normalize_datetime(row["expires_at"]),
        hit_count=int(row["hit_count"]),
        last_hit_at=_normalize_datetime(row["last_hit_at"]) if row["last_hit_at"] is not None else None,
    )


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)


def _extract_bool(row: dict[str, Any] | tuple[object, ...] | None, *, key: str) -> bool:
    if row is None:
        return False

    if isinstance(row, dict):
        return bool(row.get(key))

    if isinstance(row, tuple):
        return bool(row[0]) if row else False

    return False


if __name__ == "__main__":
    raise SystemExit(main())