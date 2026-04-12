from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from app.auth import verify_request_signature
from app.draft import ContentDraftWorkflowService, validate_content_draft_request_payload
from app.errors import AdapterError
from app.settings import Settings, get_settings

router = APIRouter(tags=["drafting"])


def get_content_draft_workflow_service(
    settings: Settings = Depends(get_settings),
) -> ContentDraftWorkflowService:
    return ContentDraftWorkflowService(settings=settings)


async def _decode_request_json(request: Request) -> object:
    try:
        return await request.json()
    except ValueError as exc:
        raise AdapterError(
            code="request_json_invalid",
            message="Content draft request body must be valid JSON.",
            status_code=422,
            details={"error": exc.__class__.__name__},
            retryable=False,
        ) from exc


@router.post("/v1/draft")
async def versioned_draft(
    request: Request,
    response: Response,
    _: None = Depends(verify_request_signature),
    service: ContentDraftWorkflowService = Depends(get_content_draft_workflow_service),
) -> dict[str, object]:
    raw_payload = await _decode_request_json(request)
    payload = validate_content_draft_request_payload(
        raw_payload,
        authenticated_generation_id=getattr(request.state, "authenticated_generation_id", None),
    )
    response_payload = await service.draft(
        payload,
        request_id=str(getattr(request.state, "request_id", "")),
    )
    response.headers.update(service.response_headers)
    return response_payload