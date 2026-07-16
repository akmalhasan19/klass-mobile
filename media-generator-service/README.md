---
title: Klass Media Generator
sdk: docker
app_port: 7860
pinned: false
---

# Klass Media Generator Service

Thin FastAPI service for rendering learning materials from the structured media
generation spec produced by the Klass **Rust gateway**.

Current capabilities:

- Accepts signed `POST /v1/generate` requests from the Rust gateway.
- Validates the structured `media_generation_spec.v1` payload.
- Routes rendering by `generation_spec.export_format` without redoing business decisions.
- Generates `.docx` with `python-docx` / `docxtpl`.
- Generates `.pdf` via a template-driven HTML pipeline (Jinja2) rendered to PDF by a
  warm Chromium sidecar (Node + Playwright).
- Generates `.pptx` with `python-pptx` using title, section, and optional assessment slides.
- Renders a self-contained HTML preview for slide-based formats (`.pptx`, `.pdf`).
- Exposes `GET /health` and `GET /v1/health` for smoke tests.

This service is deployed as a Docker-based Hugging Face Space.

## Architecture Context

Business orchestration lives in the Rust gateway (`gateway/`, which replaced the
former Laravel backend). Responsibilities are split cleanly:

- **Rust gateway**: decides the business flow and the final export type, signs each
  request with HMAC-SHA256, calls this service at `{MEDIA_GEN_URL}/v1/generate`, and
  consumes the returned artifact metadata + signed download URL.
- **This service** (`media-generator-service`): stays deterministic. It only validates
  the signed contract, routes by `export_format`, and renders the artifact.

The gateway client lives at `gateway/src/media_gen/python_client.rs`.

## Local Run

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

> Note: `.pdf` generation and HTML previews require the Chromium sidecar
> (Node 20 + Playwright). The bundled `Dockerfile` provisions this automatically;
> for a bare local run you also need Node and `npx playwright install chromium`.

## Hugging Face Spaces

Deploy this folder as a Docker Space.

Required Space secrets/variables (this service):

- `MEDIA_GENERATION_PYTHON_SHARED_SECRET`
- `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS` optional comma-separated grace-period secrets during rotation
- `MEDIA_GENERATION_PYTHON_PUBLIC_BASE_URL` optional public base URL override for signed artifact download links
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS=300`
- `MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS=900`
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME=klass-media-generator`
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION=0.1.0`
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL=info`
- `PORT=7860`

After the Space is live, point the **Rust gateway** at it via the gateway-side
environment:

- `MEDIA_GEN_URL=https://your-space-name.hf.space`
- `MEDIA_GEN_HMAC_SECRET=<same value as this service's MEDIA_GENERATION_PYTHON_SHARED_SECRET>`

Smoke test endpoints:

- `GET /health`
- `GET /v1/health`
- `POST /v1/generate`
- `GET /v1/artifacts/download`

## Environment Variables

- `MEDIA_GENERATION_PYTHON_SHARED_SECRET`: shared HMAC secret used by the Rust gateway and this service. Must equal the gateway's `MEDIA_GEN_HMAC_SECRET`.
- `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS`: optional comma-separated previous shared secrets accepted during zero-downtime rotation.
- `MEDIA_GENERATION_PYTHON_PUBLIC_BASE_URL`: optional absolute public base URL used to build signed artifact download links. Default uses the incoming request base URL.
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS`: allowed timestamp skew for signed requests. Default `300`.
- `MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS`: signed artifact download URL lifetime in seconds. Default `900`.
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME`: metadata value returned in artifact responses. Default `klass-media-generator`.
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION`: metadata value returned in artifact responses. Default `0.1.0`.
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL`: application log level. Default `info`.

> The `MEDIA_GENERATION_PYTHON_*` prefix is retained from the original naming
> convention; these variables are set on this service, while the gateway uses
> its own `MEDIA_GEN_URL` / `MEDIA_GEN_HMAC_SECRET` pair to reach it.

## Credential Rotation

Use a two-step rollout for inter-service HMAC rotation:

1. Deploy this service with the new secret in `MEDIA_GENERATION_PYTHON_SHARED_SECRET` and keep the old secret in `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS`.
2. Deploy the Rust gateway with the same new value in `MEDIA_GEN_HMAC_SECRET`.
3. Run the gateway's media-generation smoke check (or hit `GET /health`) to confirm reachability and auth readiness.
4. Remove the previous secret from this service after the rollout stabilizes.

The health payload reports `auth.rotation_enabled` and `auth.accepted_secret_count`
so the gateway's smoke checks can confirm whether a grace-period secret is still active.

## Render Model

Rendering stays deterministic on this service:

- The Rust gateway decides the business flow and final export type.
- This service only validates the signed contract, routes by `export_format`, and renders the artifact.
- `.docx` uses `python-docx` / `docxtpl`.
- `.pdf` uses a template-driven HTML pipeline: a universal `SlideBlueprint` is built from
  the render document, rendered to a self-contained HTML string by the Jinja2
  `HtmlTemplateEngine`, then converted to PDF by the warm Chromium sidecar
  (Playwright `page.setContent()` + `page.pdf()`).
- `.pptx` uses `python-pptx` and keeps one opening slide, one content slide per section, plus an optional closing assessment slide.

## Response Contract

`POST /v1/generate` returns a structured envelope with schema version `media_generator_response.v1`.

Success shape:

- `request_id`
- `status=completed`
- `data.generation_id`
- `data.artifact_delivery` with the chosen transport strategy
- `data.artifact_metadata` with the validated metadata contract consumed by the gateway
- `data.preview_delivery` with a signed HTML preview locator (slide-based formats only)
- `data.contracts.artifact_metadata`

Failure shape:

- `request_id`
- `status=failed`
- `error.code`
- `error.message`
- `error.retryable`
- `error.laravel_error_code_hint`
- `error.details`

> `error.laravel_error_code_hint` keeps its historical field name for wire
> compatibility: the gateway still reads `/error/laravel_error_code_hint`
> (`gateway/src/media_gen/python_client.rs`) to map renderer failures onto its own
> `PYTHON_SERVICE_UNAVAILABLE` / `ARTIFACT_INVALID` codes. Do not rename this field
> without a coordinated gateway change.

Current artifact delivery strategy is `signed_url`, exposed through both `data.artifact_delivery` and `data.artifact_metadata.artifact_locator`. The signed URL lets the gateway download the generated file from this service without assuming shared local filesystem access between containers.

The gateway currently depends on these metadata fields being present and valid:

- `title`
- `filename`
- `extension`
- `mime_type`
- `size_bytes`
- `checksum_sha256`
- `artifact_locator.kind`
- `artifact_locator.value`
- `page_count` for paged artifacts when available
- `slide_count` for `.pptx`
