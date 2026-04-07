from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.auth import verify_request_signature
from app.contracts import (
    ARTIFACT_METADATA_VERSION,
    GENERATION_SPEC_VERSION,
    HEALTH_SCHEMA_VERSION,
    IMPLEMENTED_EXPORT_FORMATS,
    RESPONSE_SCHEMA_VERSION,
    SIGNATURE_ALGORITHM,
)
from app.document_model import build_render_document
from app.errors import ContractValidationError, MediaGeneratorError
from app.generators.registry import GeneratorRegistry
from app.models import GenerateErrorResponse, GenerateRequest, GenerateSuccessResponse
from app.settings import Settings, get_settings

logger = logging.getLogger("klass-media-generator")
registry = GeneratorRegistry()


def build_error_response(request: Request, exc: MediaGeneratorError) -> JSONResponse:
    response_payload = GenerateErrorResponse.model_validate(
        {
            "schema_version": RESPONSE_SCHEMA_VERSION,
            "request_id": getattr(request.state, "request_id", str(uuid4())),
            "status": "failed",
            "error": {
                "code": exc.code,
                "message": exc.message,
                "retryable": exc.retryable,
                "laravel_error_code_hint": exc.laravel_error_code_hint,
                "details": exc.details,
            },
        }
    )

    return JSONResponse(status_code=exc.status_code, content=response_payload.model_dump(mode="python"))


def configure_logging(settings: Settings) -> None:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_logging(get_settings())
    yield


app = FastAPI(
    title="Klass Media Generator",
    version=get_settings().service_version,
    lifespan=lifespan,
)


@app.middleware("http")
async def attach_request_id(request: Request, call_next):
    request_id = str(uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-Id"] = request_id
    return response


@app.exception_handler(MediaGeneratorError)
async def media_generator_error_handler(request: Request, exc: MediaGeneratorError) -> JSONResponse:
    return build_error_response(request, exc)


@app.exception_handler(RequestValidationError)
async def request_validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    validation_error = ContractValidationError(
        "request_contract_invalid",
        "Incoming request payload failed validation.",
        {"errors": exc.errors()},
    )
    return await media_generator_error_handler(request, validation_error)


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled media generator exception", exc_info=exc)
    return build_error_response(
        request,
        MediaGeneratorError(
            status_code=500,
            code="internal_error",
            message="An unexpected error occurred while generating the artifact.",
            details={},
            retryable=True,
            laravel_error_code_hint="python_service_unavailable",
        ),
    )


def health_payload(settings: Settings) -> dict[str, object]:
    return {
        "schema_version": HEALTH_SCHEMA_VERSION,
        "status": "ok",
        "service": settings.service_name,
        "version": settings.service_version,
        "supported_formats": list(IMPLEMENTED_EXPORT_FORMATS),
        "contracts": {
            "generation_spec": GENERATION_SPEC_VERSION,
            "artifact_metadata": ARTIFACT_METADATA_VERSION,
            "response": RESPONSE_SCHEMA_VERSION,
        },
        "auth": {
            "signature_algorithm": SIGNATURE_ALGORITHM,
            "configured": settings.shared_secret != "",
            "max_request_age_seconds": settings.request_max_age_seconds,
        },
    }


@app.get("/health")
def health(settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return health_payload(settings)


@app.get("/v1/health")
def versioned_health(settings: Settings = Depends(get_settings)) -> dict[str, object]:
    return health_payload(settings)


@app.post("/v1/generate")
async def generate_artifact(
    payload: GenerateRequest,
    request: Request,
    settings: Settings = Depends(get_settings),
    _: None = Depends(verify_request_signature),
) -> dict[str, object]:
    header_generation_id = getattr(request.state, "authenticated_generation_id", None)
    if header_generation_id != payload.generation_id:
        raise ContractValidationError(
            "generation_id_mismatch",
            "Header generation id does not match request body generation id.",
            {
                "header_generation_id": header_generation_id,
                "body_generation_id": payload.generation_id,
            },
        )

    render_document = build_render_document(payload.generation_spec)
    generator = registry.get(payload.generation_spec.export_format)
    artifact_metadata = generator.generate(payload, render_document, settings)

    response = GenerateSuccessResponse.model_validate(
        {
            "schema_version": RESPONSE_SCHEMA_VERSION,
            "request_id": request.state.request_id,
            "status": "completed",
            "data": {
                "generation_id": payload.generation_id,
                "artifact_delivery": artifact_metadata["artifact_locator"],
                "artifact_metadata": artifact_metadata,
                "contracts": {
                    "artifact_metadata": ARTIFACT_METADATA_VERSION,
                },
            },
        }
    )

    return response.model_dump(mode="python")
