from __future__ import annotations

import pytest

from app.database import MIGRATIONS_TABLE_NAME, discover_migrations, run_pending_migrations
from app.settings import get_settings


class _FakeMigrationCursor:
    def __init__(self, connection: "_FakeMigrationConnection") -> None:
        self.connection = connection
        self._rows: list[object] = []

    def execute(self, query: str, params: object | None = None) -> None:
        normalized_query = " ".join(query.split())
        self.connection.executed_queries.append((normalized_query, params))

        if "SELECT pg_advisory_lock" in normalized_query:
            self._rows = [(1,)]
            return

        if "SELECT pg_advisory_unlock" in normalized_query:
            self._rows = [(1,)]
            return

        if f"SELECT version, checksum FROM {MIGRATIONS_TABLE_NAME}" in normalized_query:
            self._rows = [
                {"version": version, "checksum": checksum}
                for version, checksum in self.connection.applied_checksums.items()
            ]
            return

        if normalized_query.startswith(f"INSERT INTO {MIGRATIONS_TABLE_NAME}"):
            version, name, checksum = params
            self.connection.applied_checksums[str(version)] = str(checksum)
            self.connection.inserted_rows.append((str(version), str(name), str(checksum)))
            self._rows = []
            return

        self.connection.executed_sql_blocks.append(query.strip())
        self._rows = []

    def fetchall(self) -> list[object]:
        return list(self._rows)

    def fetchone(self) -> object:
        return self._rows[0] if self._rows else (1,)

    def __enter__(self) -> "_FakeMigrationCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


class _FakeMigrationTransaction:
    def __init__(self, connection: "_FakeMigrationConnection") -> None:
        self.connection = connection

    def __enter__(self) -> "_FakeMigrationTransaction":
        self.connection.transaction_entries += 1
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


class _FakeMigrationConnection:
    def __init__(self, applied_checksums: dict[str, str] | None = None) -> None:
        self.applied_checksums = applied_checksums or {}
        self.executed_queries: list[tuple[str, object | None]] = []
        self.executed_sql_blocks: list[str] = []
        self.inserted_rows: list[tuple[str, str, str]] = []
        self.transaction_entries = 0

    def cursor(self, *args, **kwargs) -> _FakeMigrationCursor:
        return _FakeMigrationCursor(self)

    def transaction(self) -> _FakeMigrationTransaction:
        return _FakeMigrationTransaction(self)

    def __enter__(self) -> "_FakeMigrationConnection":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False


def test_discover_migrations_returns_state_schemas() -> None:
    migrations = discover_migrations()

    assert [migration.version for migration in migrations] == ["0001", "0002"]
    assert migrations[0].name == "0001_adapter_state"
    assert len(migrations[0].checksum) == 64
    assert "CREATE TABLE IF NOT EXISTS interpretation_cache_entries" in migrations[0].sql
    assert "CREATE TABLE IF NOT EXISTS delivery_cache_entries" in migrations[0].sql
    assert migrations[1].name == "0002_governance_state"
    assert "CREATE TABLE IF NOT EXISTS rate_limit_policies" in migrations[1].sql
    assert "CREATE TABLE IF NOT EXISTS llm_request_ledger" in migrations[1].sql
    assert "CREATE TABLE IF NOT EXISTS price_catalog_entries" in migrations[1].sql
    assert "CREATE OR REPLACE VIEW llm_request_daily_aggregates AS" in migrations[1].sql


def test_run_pending_migrations_applies_adapter_state_schemas(monkeypatch) -> None:
    fake_connection = _FakeMigrationConnection()
    monkeypatch.setattr("app.database.psycopg.connect", lambda *args, **kwargs: fake_connection)
    settings = get_settings()

    applied = run_pending_migrations(settings)

    assert [migration.name for migration in applied] == [
        "0001_adapter_state",
        "0002_governance_state",
    ]
    assert fake_connection.transaction_entries == 1
    assert fake_connection.inserted_rows[0][0] == "0001"
    assert fake_connection.inserted_rows[1][0] == "0002"
    assert any(
        "CREATE TABLE IF NOT EXISTS interpretation_cache_entries" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE TABLE IF NOT EXISTS delivery_cache_entries" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_interpretation_cache_entries_cache_key" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE INDEX IF NOT EXISTS idx_delivery_cache_entries_expires_at" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE TABLE IF NOT EXISTS rate_limit_policies" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE TABLE IF NOT EXISTS rate_limit_buckets" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE TABLE IF NOT EXISTS llm_request_ledger" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE TABLE IF NOT EXISTS price_catalog_entries" in sql
        for sql in fake_connection.executed_sql_blocks
    )
    assert any(
        "CREATE OR REPLACE VIEW llm_request_daily_route_aggregates AS" in sql
        for sql in fake_connection.executed_sql_blocks
    )


def test_run_pending_migrations_skips_matching_applied_migration(monkeypatch) -> None:
    migrations = discover_migrations()
    fake_connection = _FakeMigrationConnection(
        applied_checksums={
            migration.version: migration.checksum
            for migration in migrations
        }
    )
    monkeypatch.setattr("app.database.psycopg.connect", lambda *args, **kwargs: fake_connection)
    settings = get_settings()

    applied = run_pending_migrations(settings)

    assert applied == ()
    assert fake_connection.inserted_rows == []


def test_run_pending_migrations_rejects_checksum_drift(monkeypatch) -> None:
    fake_connection = _FakeMigrationConnection(applied_checksums={"0001": "0" * 64})
    monkeypatch.setattr("app.database.psycopg.connect", lambda *args, **kwargs: fake_connection)
    settings = get_settings()

    with pytest.raises(RuntimeError, match="checksum mismatch"):
        run_pending_migrations(settings)