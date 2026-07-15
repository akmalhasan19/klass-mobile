from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse

from app.artifact_download import (
    build_signed_artifact_locator,
    media_type_for_filename,
    verify_artifact_download_request,
)
from app.auth import verify_request_signature
from app.contracts import (
    ARTIFACT_METADATA_VERSION,
    GENERATION_SPEC_VERSION,
    HEALTH_SCHEMA_VERSION,
    HTML_MIME_TYPE,
    IMPLEMENTED_EXPORT_FORMATS,
    PREVIEW_SCHEMA_VERSION,
    RESPONSE_SCHEMA_VERSION,
    SIGNATURE_ALGORITHM,
)
from app.document_model import build_render_document
from app.engines.blueprint_builder import build_slide_blueprint
from app.engines.marp.marp_markdown_builder import build_marp_markdown
from app.engines.marp.marp_renderer import MarpRenderer
from app.engines.marp.sidecar.sidecar_manager import SidecarManager, build_sidecar_manager
from app.errors import ContractValidationError, MediaGeneratorError, ServiceMisconfiguredError
from app.generators.registry import GeneratorRegistry
from app.models import GenerateErrorResponse, GenerateRequest, GenerateSuccessResponse
from app.preview.preview_handler import build_preview_locator, store_preview_html
from app.settings import Settings, get_settings
from app.templates.registry import TemplateRegistry

logger = logging.getLogger("klass-media-generator")
registry = GeneratorRegistry()

# Module-level sidecar manager — started during lifespan, accessible by
# health endpoint and by generators (via the registry or module import).
sidecar_manager: SidecarManager | None = None

# Module-level template registry — loaded during lifespan, provides
# master .pptx templates and manifests for PPTX generation.
template_registry: TemplateRegistry | None = None


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
    settings = get_settings()
    global sidecar_manager, template_registry, registry

    # ── Bootstrap template registry ────────────────────────────────────
    logger.info("Loading PPTX master templates…")
    try:
        from pathlib import Path

        templates_dir = Path(__file__).resolve().parent / "templates"
        tpl_registry = TemplateRegistry()
        tpl_registry.load_templates(templates_dir)
        template_registry = tpl_registry
        logger.info(
            "Template registry loaded: %s",
            template_registry.template_ids,
        )
    except Exception as exc:
        logger.critical("Failed to load PPTX templates: %s", exc)
        template_registry = None
        raise ServiceMisconfiguredError(
            "PPTX master templates failed to load. "
            "PPTX generation will be unavailable.",
            {"startup_error": str(exc)},
        ) from exc

    # ── Bootstrap sidecar ──────────────────────────────────────────────
    logger.info("Starting Marp sidecar (Node + Chromium warm)…")
    try:
        manager = build_sidecar_manager(settings)
        await manager.start()
        sidecar_manager = manager
        logger.info("Marp sidecar started and ready")
    except Exception as exc:
        logger.critical("Failed to start Marp sidecar: %s", exc)
        sidecar_manager = None
        raise ServiceMisconfiguredError(
            "Marp sidecar (Node + Chromium) failed to start. "
            "HTML previews and PDF generation will be unavailable.",
            {"startup_error": str(exc)},
        ) from exc

    # ── Rebuild generator registry with injected dependencies ──────────
    # The module-level ``registry`` is created at import time (before deps
    # exist). Now that the template registry and sidecar are live, rebuild
    # it so generators receive their real dependencies instead of relying
    # on lazy fallback / circular imports per-request.
    logger.info(
        "Rebuilding generator registry with template_registry=%s, "
        "sidecar_manager=%s",
        template_registry is not None,
        sidecar_manager is not None,
    )
    registry = GeneratorRegistry(
        template_registry=template_registry,
        sidecar_manager=sidecar_manager,
    )

    try:
        yield
    finally:
        # ── Shutdown sidecar ───────────────────────────────────────────
        if sidecar_manager is not None:
            logger.info("Shutting down Marp sidecar…")
            try:
                await sidecar_manager.stop()
            except Exception as exc:
                logger.warning("Error during Marp sidecar shutdown: %s", exc)
            sidecar_manager = None
            logger.info("Marp sidecar stopped")


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
    # Sidecar status — simple sync properties, no RPC call needed.
    sidecar_info: dict[str, object] = {"enabled": False}
    if sidecar_manager is not None:
        sidecar_info = {
            "enabled": True,
            "running": sidecar_manager.is_running,
            "ready": sidecar_manager.is_ready,
            "uptime_seconds": round(sidecar_manager.uptime_seconds, 1),
        }

    # Template registry status
    template_info: dict[str, object] = {"enabled": False}
    if template_registry is not None:
        template_info = {
            "enabled": True,
            "templates": template_registry.template_ids,
        }

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
            "rotation_enabled": settings.rotation_enabled,
            "accepted_secret_count": len(settings.accepted_shared_secrets),
            "max_request_age_seconds": settings.request_max_age_seconds,
        },
        "sidecar": sidecar_info,
        "templates": template_info,
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
    response_artifact_locator = build_signed_artifact_locator(
        request,
        generation_id=payload.generation_id,
        artifact_metadata=artifact_metadata,
        settings=settings,
    )
    response_artifact_metadata = {
        **artifact_metadata,
        "artifact_locator": response_artifact_locator,
    }

    # ── Preview HTML rendering (best-effort, pptx/pdf only) ──────────
    preview_delivery: dict[str, object] | None = None
    if payload.generation_spec.export_format in ("pptx", "pdf") and sidecar_manager is not None:
        try:
            renderer = MarpRenderer(sidecar_manager)
            blueprint = build_slide_blueprint(render_document)
            markdown = build_marp_markdown(blueprint)

            # Allocate a temp file for the preview HTML.
            preview_path = store_preview_html(
                "", payload.generation_id, render_document.title,
            )
            # Render HTML to the allocated path (overwrites the empty file).
            await renderer.render_html(markdown, preview_path)

            preview_locator = build_preview_locator(
                request,
                generation_id=payload.generation_id,
                preview_path=preview_path,
                title=render_document.title,
                settings=settings,
            )
            preview_delivery = {
                "schema_version": PREVIEW_SCHEMA_VERSION,
                "mime_type": HTML_MIME_TYPE,
                "locator": preview_locator,
            }
        except Exception as exc:
            logger.warning(
                "Preview HTML rendering failed for generation %s (non-fatal): %s",
                payload.generation_id,
                exc,
            )

    response = GenerateSuccessResponse.model_validate(
        {
            "schema_version": RESPONSE_SCHEMA_VERSION,
            "request_id": request.state.request_id,
            "status": "completed",
            "data": {
                "generation_id": payload.generation_id,
                "artifact_delivery": response_artifact_locator,
                "artifact_metadata": response_artifact_metadata,
                "preview_delivery": preview_delivery,
                "contracts": {
                    "artifact_metadata": ARTIFACT_METADATA_VERSION,
                },
            },
        }
    )

    return response.model_dump(mode="python")


@app.get("/v1/artifacts/download", name="download_artifact")
async def download_artifact(
    generation_id: str,
    path: str,
    filename: str,
    expires: int,
    signature: str,
    settings: Settings = Depends(get_settings),
) -> FileResponse:
    artifact_path = verify_artifact_download_request(
        generation_id=generation_id,
        artifact_path=path,
        filename=filename,
        expires=expires,
        signature=signature,
        settings=settings,
    )

    return FileResponse(
        path=str(artifact_path),
        media_type=media_type_for_filename(filename),
        filename=filename,
    )
