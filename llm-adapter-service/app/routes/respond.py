from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from app.auth import verify_request_signature
from app.delivery import DeliveryWorkflowService, validate_delivery_request_payload
from app.errors import AdapterError
from app.settings import Settings, get_settings

router = APIRouter(tags=["delivery"])


def get_delivery_workflow_service(
    settings: Settings = Depends(get_settings),
) -> DeliveryWorkflowService:
    return DeliveryWorkflowService(settings=settings)


async def _decode_request_json(request: Request) -> object:
    try:
        return await request.json()
    except ValueError as exc:
        raise AdapterError(
            code="request_json_invalid",
            message="Delivery request body must be valid JSON.",
            status_code=422,
            details={"error": exc.__class__.__name__},
            retryable=False,
        ) from exc


@router.post("/v1/respond")
async def versioned_respond(
    request: Request,
    response: Response,
    _: None = Depends(verify_request_signature),
    service: DeliveryWorkflowService = Depends(get_delivery_workflow_service),
) -> dict[str, object]:
    raw_payload = await _decode_request_json(request)
    payload = validate_delivery_request_payload(
        raw_payload,
        authenticated_generation_id=getattr(request.state, "authenticated_generation_id", None),
    )
    response_payload = await service.respond(
        payload,
        request_id=str(getattr(request.state, "request_id", "")),
    )
    response.headers.update(service.response_headers)
    return response_payload