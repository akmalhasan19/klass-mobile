from __future__ import annotations

from urllib.parse import urlparse

import psycopg

from app.settings import Settings


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
        with psycopg.connect(
            settings.database_url,
            connect_timeout=settings.database_connect_timeout_seconds,
        ) as connection:
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
