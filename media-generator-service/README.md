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
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS=300`
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME=klass-media-generator`
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION=0.1.0`
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL=info`
- `PORT=7860`

After the Space is live, point Laravel to the Space URL via `MEDIA_GENERATION_PYTHON_BASE_URL`, for example `https://your-space-name.hf.space`.

Smoke test endpoints:

- `GET /health`
- `GET /v1/health`
- `POST /v1/generate`

## Environment Variables

- `MEDIA_GENERATION_PYTHON_SHARED_SECRET`: shared HMAC secret used by Laravel and the Python service.
- `MEDIA_GENERATION_PYTHON_REQUEST_MAX_AGE_SECONDS`: allowed timestamp skew for signed requests. Default `300`.
- `MEDIA_GENERATION_PYTHON_SERVICE_NAME`: metadata value returned in artifact responses. Default `klass-media-generator`.
- `MEDIA_GENERATION_PYTHON_SERVICE_VERSION`: metadata value returned in artifact responses. Default `0.1.0`.
- `MEDIA_GENERATION_PYTHON_LOG_LEVEL`: application log level. Default `info`.

## Render Model

Rendering stays deterministic on the Python side:

- Laravel decides the business flow and final export type.
- Python only validates the signed contract, routes by `export_format`, and renders the artifact.
- `.docx` uses `python-docx`.
- `.pdf` uses `reportlab` from a shared intermediate document model defined in `app/document_model.py`.
