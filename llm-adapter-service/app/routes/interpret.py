from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from app.auth import verify_request_signature
from app.errors import AdapterError
from app.interpretation import InterpretationWorkflowService, validate_interpretation_request_payload
from app.settings import Settings, get_settings

router = APIRouter(tags=["interpretation"])


def get_interpretation_workflow_service(
    settings: Settings = Depends(get_settings),
) -> InterpretationWorkflowService:
    return InterpretationWorkflowService(settings=settings)


async def _decode_request_json(request: Request) -> object:
    try:
        return await request.json()
    except ValueError as exc:
        raise AdapterError(
            code="request_json_invalid",
            message="Interpretation request body must be valid JSON.",
            status_code=422,
            details={"error": exc.__class__.__name__},
            retryable=False,
        ) from exc


@router.post("/v1/interpret")
async def versioned_interpret(
    request: Request,
    response: Response,
    _: None = Depends(verify_request_signature),
    service: InterpretationWorkflowService = Depends(get_interpretation_workflow_service),
) -> dict[str, object]:
    raw_payload = await _decode_request_json(request)
    payload = validate_interpretation_request_payload(
        raw_payload,
        authenticated_generation_id=getattr(request.state, "authenticated_generation_id", None),
    )
    response_payload = await service.interpret(
        payload,
        request_id=str(getattr(request.state, "request_id", "")),
    )
    response.headers.update(service.response_headers)
    return response_payload
