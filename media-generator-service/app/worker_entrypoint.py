#!/usr/bin/env python3
"""Entry point for running the Arq background worker.

Usage:
    python -m app.worker_entrypoint

Or via the ``arq`` CLI (recommended for production):
    arq app.worker.WorkerSettings

This module provides a programmatic way to start the worker, which is useful
for development, testing, and Docker entrypoints.
"""

from __future__ import annotations

import logging

# pyrefly: ignore [missing-import]
from arq import run_worker

from app.settings import get_settings
from app.worker import WorkerSettings

logger = logging.getLogger("klass-media-generator.worker_entrypoint")


def main() -> None:
    """Run the Arq worker with settings from the application configuration."""
    settings = get_settings()

    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    configured_settings = WorkerSettings.from_settings(settings)

    logger.info(
        "Starting Arq worker (redis=%s, concurrency=%d, auto=%s, "
        "max=%d, memory_limit=%dMB, timeout=%ds)",
        settings.redis_url,
        settings.worker_concurrency,
        settings.worker_concurrency_auto,
        settings.worker_max_concurrency,
        settings.worker_memory_limit_mb,
        settings.worker_job_timeout_seconds,
    )

    # run_worker is synchronous — it blocks until the worker is shut down.
    # Do NOT wrap with asyncio.run(); that would treat the Worker incorrectly.
    run_worker(configured_settings)


if __name__ == "__main__":
    main()
