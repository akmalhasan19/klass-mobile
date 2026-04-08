from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request

from app.contracts import LOGGER_NAME
from app.logging import configure_logging
from app.routes import health_router
from app.settings import Settings, get_settings

logger = logging.getLogger(LOGGER_NAME)


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    configure_logging(settings)
    logger.info(
        "service_started",
        extra={
            "event_data": {
                "service_name": settings.service_name,
                "service_version": settings.service_version,
            }
        },
    )
    yield


app = FastAPI(
    title="Klass LLM Adapter",
    version=get_settings().service_version,
    lifespan=lifespan,
)

app.include_router(health_router)


@app.middleware("http")
async def attach_request_id(request: Request, call_next):
    request_id = (request.headers.get("X-Request-Id") or "").strip() or str(uuid4())
    request.state.request_id = request_id

    start = time.perf_counter()

    response = await call_next(request)

    duration_ms = round((time.perf_counter() - start) * 1000, 2)
    response.headers["X-Request-Id"] = request_id

    settings: Settings = get_settings()
    actor_metadata = getattr(request.state, "actor_metadata", {})
    logger.info(
        "request_completed",
        extra={
            "event_data": {
                "request_id": request_id,
                "service_name": settings.service_name,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "generation_id": actor_metadata.get("generation_id"),
                "route_type": actor_metadata.get("route_type"),
            }
        },
    )

    return response
