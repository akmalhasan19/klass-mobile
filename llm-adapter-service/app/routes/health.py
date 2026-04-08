from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Response, status

from app.auth import auth_readiness_payload
from app.contracts import HEALTH_SCHEMA_VERSION
from app.database import get_database_readiness
from app.models import HealthResponse
from app.providers import get_provider_readiness
from app.settings import Settings, get_settings

router = APIRouter(tags=["health"])


def build_health_payload(settings: Settings) -> dict[str, object]:
    postgres = get_database_readiness(settings)
    providers = get_provider_readiness(settings)
    auth = auth_readiness_payload(settings)

    ready = (
        bool(postgres["ready"])
        and bool(providers["interpretation"]["ready"])
        and bool(providers["delivery"]["ready"])
        and bool(auth["ready"])
    )

    payload = HealthResponse.model_validate(
        {
            "schema_version": HEALTH_SCHEMA_VERSION,
            "status": "ready" if ready else "degraded",
            "ready": ready,
            "service_name": settings.service_name,
            "service_version": settings.service_version,
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "dependencies": {
                "postgres": postgres,
                "providers": providers,
            },
            "auth": auth,
        }
    )

    return payload.model_dump(mode="python")


def apply_health_status(response: Response, payload: dict[str, object]) -> dict[str, object]:
    response.status_code = status.HTTP_200_OK if payload["ready"] else status.HTTP_503_SERVICE_UNAVAILABLE
    return payload


@router.get("/health", response_model=HealthResponse)
def health(response: Response, settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return apply_health_status(response, build_health_payload(settings))


@router.get("/v1/health", response_model=HealthResponse)
def versioned_health(response: Response, settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return apply_health_status(response, build_health_payload(settings))
