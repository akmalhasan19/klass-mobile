from __future__ import annotations

import argparse
import hashlib
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.settings import Settings, get_settings

MIGRATIONS_TABLE_NAME = "schema_migrations"
MIGRATION_LOCK_ID = 947215031
MIGRATIONS_DIR = Path(__file__).with_name("migrations")


@dataclass(frozen=True)
class DatabasePoolConfig:
    min_size: int
    max_size: int
    max_idle_seconds: int


@dataclass(frozen=True)
class MigrationDefinition:
    version: str
    name: str
    checksum: str
    sql: str
    path: Path


_database_pool: ConnectionPool | None = None


def get_database_pool_config(settings: Settings) -> DatabasePoolConfig:
    min_size = max(1, settings.database_pool_min_size)
    max_size = max(min_size, settings.database_pool_max_size)
    max_idle_seconds = max(1, settings.database_pool_max_idle_seconds)

    return DatabasePoolConfig(
        min_size=min_size,
        max_size=max_size,
        max_idle_seconds=max_idle_seconds,
    )


def get_database_pool(settings: Settings) -> ConnectionPool:
    global _database_pool

    if settings.database_url == "":
        raise RuntimeError("LLM_ADAPTER_DATABASE_URL is not configured.")

    if _database_pool is None:
        pool_config = get_database_pool_config(settings)
        _database_pool = ConnectionPool(
            conninfo=settings.database_url,
            min_size=pool_config.min_size,
            max_size=pool_config.max_size,
            max_idle=float(pool_config.max_idle_seconds),
            kwargs=_build_connection_kwargs(settings),
        )

    return _database_pool


def close_database_pool() -> None:
    global _database_pool

    if _database_pool is not None:
        _database_pool.close()
        _database_pool = None


def discover_migrations() -> tuple[MigrationDefinition, ...]:
    migrations: list[MigrationDefinition] = []
    seen_versions: set[str] = set()

    for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
        sql = path.read_text(encoding="utf-8").strip()

        if sql == "":
            continue

        version, separator, _ = path.stem.partition("_")
        if version == "" or separator == "":
            raise RuntimeError(f"Invalid migration file name: {path.name}")

        if version in seen_versions:
            raise RuntimeError(f"Duplicate migration version detected: {version}")

        seen_versions.add(version)
        migrations.append(
            MigrationDefinition(
                version=version,
                name=path.stem,
                checksum=hashlib.sha256(sql.encode("utf-8")).hexdigest(),
                sql=sql,
                path=path,
            )
        )

    return tuple(migrations)


def run_pending_migrations(settings: Settings) -> tuple[MigrationDefinition, ...]:
    if settings.database_url == "":
        raise RuntimeError("LLM_ADAPTER_DATABASE_URL is not configured.")

    with _connect(settings) as connection:
        _acquire_migration_lock(connection)

        try:
            with connection.transaction():
                ensure_schema_migrations_table(connection)
                applied_checksums = fetch_applied_migration_checksums(connection)
                applied_migrations: list[MigrationDefinition] = []

                for migration in discover_migrations():
                    existing_checksum = applied_checksums.get(migration.version)

                    if existing_checksum is not None:
                        if existing_checksum != migration.checksum:
                            raise RuntimeError(
                                f"Migration checksum mismatch for {migration.name}."
                            )

                        continue

                    with connection.cursor() as cursor:
                        cursor.execute(migration.sql)
                        cursor.execute(
                            f"""
                            INSERT INTO {MIGRATIONS_TABLE_NAME} (version, name, checksum)
                            VALUES (%s, %s, %s)
                            """,
                            (migration.version, migration.name, migration.checksum),
                        )

                    applied_migrations.append(migration)

                return tuple(applied_migrations)
        finally:
            _release_migration_lock(connection)


def list_pending_migrations(settings: Settings) -> tuple[MigrationDefinition, ...]:
    if settings.database_url == "":
        raise RuntimeError("LLM_ADAPTER_DATABASE_URL is not configured.")

    with _connect(settings) as connection:
        ensure_schema_migrations_table(connection)
        applied_checksums = fetch_applied_migration_checksums(connection)

    return tuple(
        migration
        for migration in discover_migrations()
        if migration.version not in applied_checksums
    )


def ensure_schema_migrations_table(connection: psycopg.Connection) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {MIGRATIONS_TABLE_NAME} (
                version VARCHAR(255) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                checksum CHAR(64) NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )


def fetch_applied_migration_checksums(connection: psycopg.Connection) -> dict[str, str]:
    with connection.cursor(row_factory=dict_row) as cursor:
        cursor.execute(
            f"""
            SELECT version, checksum
            FROM {MIGRATIONS_TABLE_NAME}
            ORDER BY version ASC
            """
        )
        rows = cursor.fetchall()

    return {
        str(row["version"]): str(row["checksum"])
        for row in rows
    }


def get_database_readiness(settings: Settings) -> dict[str, object]:
    if settings.database_url == "":
        return {
            "configured": False,
            "ready": False,
            "driver": None,
            "host": None,
            "database": None,
            "error": {
                "code": "database_url_missing",
                "message": "LLM_ADAPTER_DATABASE_URL is not configured.",
                "detail": None,
            },
        }

    parsed = urlparse(settings.database_url)
    driver = parsed.scheme or None
    host = parsed.hostname or None
    database_name = parsed.path.lstrip("/") or None

    try:
        with _connect(settings) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
    except Exception as exc:
        return {
            "configured": True,
            "ready": False,
            "driver": driver,
            "host": host,
            "database": database_name,
            "error": {
                "code": "database_unreachable",
                "message": "Could not reach the adapter Postgres database.",
                "detail": exc.__class__.__name__,
            },
        }

    return {
        "configured": True,
        "ready": True,
        "driver": driver,
        "host": host,
        "database": database_name,
        "error": None,
    }


def _build_connection_kwargs(settings: Settings) -> dict[str, object]:
    return {
        "autocommit": False,
        "connect_timeout": settings.database_connect_timeout_seconds,
    }


def _connect(settings: Settings) -> psycopg.Connection:
    return psycopg.connect(settings.database_url, **_build_connection_kwargs(settings))


def _acquire_migration_lock(connection: psycopg.Connection) -> None:
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_lock(%s)", (MIGRATION_LOCK_ID,))
        cursor.fetchone()


def _release_migration_lock(connection: psycopg.Connection) -> None:
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_unlock(%s)", (MIGRATION_LOCK_ID,))
        cursor.fetchone()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Klass LLM Adapter database utilities")
    parser.add_argument("command", choices=("list", "migrate"))
    args = parser.parse_args(argv)
    settings = get_settings()

    if args.command == "list":
        pending = list_pending_migrations(settings)

        for migration in pending:
            print(migration.name)

        return 0

    applied = run_pending_migrations(settings)

    for migration in applied:
        print(migration.name)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
