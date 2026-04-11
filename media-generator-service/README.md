---
title: Klass Media Generator
sdk: docker
app_port: 7860
pinned: false
---

# Klass Media Generator Service

Thin FastAPI service for rendering learning materials from the Laravel media generation spec.

Current capabilities:

- Accepts signed `POST /v1/generate` requests from Laravel.
- Validates the structured `media_generation_spec.v1` payload.
- Routes rendering by `generation_spec.export_format` without redoing business decisions.
- Generates `.docx` with `python-docx`.
- Generates `.pdf` with `reportlab` from a shared intermediate document model.
- Generates `.pptx` with `python-pptx` using title, section, and optional assessment slides.
- Exposes `GET /health` and `GET /v1/health` for smoke tests.

This service is prepared to be deployed as a Docker-based Hugging Face Space.

## Local Run

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Hugging Face Spaces

Deploy this folder as a Docker Space.

Required Space secrets/variables:

- `MEDIA_GENERATION_PYTHON_SHARED_SECRET`
- `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS` optional comma-separated grace-period secrets during rotation
- `MEDIA_GENERATION_PYTHON_PUBLIC_BASE_URL` optional public base URL override for signed artifact download links
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS=300`
- `MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS=900`
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME=klass-media-generator`
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION=0.1.0`
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL=info`
- `PORT=7860`

After the Space is live, point Laravel to the Space URL via `MEDIA_GENERATION_PYTHON_BASE_URL`, for example `https://your-space-name.hf.space`.

Smoke test endpoints:

- `GET /health`
- `GET /v1/health`
- `POST /v1/generate`
- `GET /v1/artifacts/download`

## Environment Variables

- `MEDIA_GENERATION_PYTHON_SHARED_SECRET`: shared HMAC secret used by Laravel and the Python service.
- `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS`: optional comma-separated previous shared secrets accepted during zero-downtime rotation.
- `MEDIA_GENERATION_PYTHON_PUBLIC_BASE_URL`: optional absolute public base URL used to build signed artifact download links. Default uses the incoming request base URL.
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS`: allowed timestamp skew for signed requests. Default `300`.
- `MEDIA_GENERATION_PYTHON_ARTIFACT_URL_TTL_SECONDS`: signed artifact download URL lifetime in seconds. Default `900`.
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME`: metadata value returned in artifact responses. Default `klass-media-generator`.
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION`: metadata value returned in artifact responses. Default `0.1.0`.
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL`: application log level. Default `info`.

## Credential Rotation

Use a two-step rollout for inter-service HMAC rotation:

1. Deploy the Python service with the new secret in `MEDIA_GENERATION_PYTHON_SHARED_SECRET` and keep the old secret in `MEDIA_GENERATION_PYTHON_SHARED_SECRET_PREVIOUS`.
2. Deploy Laravel with the same new value in `MEDIA_GENERATION_PYTHON_SHARED_SECRET`.
3. Run `php artisan media-generation:smoke-python-service` from Laravel to confirm reachability and auth readiness.
4. Remove the previous secret from the Python service after the rollout stabilizes.

The health payload reports `auth.rotation_enabled` and `auth.accepted_secret_count` so Laravel smoke checks can confirm whether a grace-period secret is still active.

## Render Model

Rendering stays deterministic on the Python side:

- Laravel decides the business flow and final export type.
- Python only validates the signed contract, routes by `export_format`, and renders the artifact.
- `.docx` uses `python-docx`.
- `.pdf` uses `reportlab` from a shared intermediate document model defined in `app/document_model.py`.
- `.pptx` uses `python-pptx` and keeps one opening slide, one content slide per section, plus an optional closing assessment slide.

## Response Contract

`POST /v1/generate` returns a structured envelope with schema version `media_generator_response.v1`.

Success shape:

- `request_id`
- `status=completed`
- `data.generation_id`
- `data.artifact_delivery` with the chosen transport strategy
- `data.artifact_metadata` with the validated metadata contract consumed by Laravel
- `data.contracts.artifact_metadata`

Failure shape:

- `request_id`
- `status=failed`
- `error.code`
- `error.message`
- `error.retryable`
- `error.laravel_error_code_hint`
- `error.details`

Current artifact delivery strategy is `signed_url`, exposed through both `data.artifact_delivery` and `data.artifact_metadata.artifact_locator`. The signed URL lets Laravel download the generated file from the Python service without assuming shared local filesystem access between containers.

Laravel currently depends on these metadata fields being present and valid:

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
