# Klass Project Overview

**Klass** is an educational content generation and management platform focused on the Indonesian education market. It enables teachers to generate learning materials (PDF, DOCX, PPTX) using AI-powered LLM interpretation and content drafting, with a marketplace for freelance educational content creators.

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile Frontend | Flutter (Dart) | SDK ^3.11.1 |
| State Management | Riverpod | flutter_riverpod ^2.6.1 |
| HTTP Client | Dio | ^5.9.2 |
| Gateway API | Rust | 1.97, Axum 0.8, sqlx |
| Database | PostgreSQL (Neon Cloud) | via sqlx, PgBouncer |
| Job Queue | Redis | Upstash (deadpool-redis) |
| Object Storage | Cloudflare R2 / AWS S3 | aws-sdk-s3 |
| LLM Providers | OpenRouter + Fallback | gemini-2.5-flash-lite, gpt-5.4 |
| Media Generator Service | FastAPI (Python) | python-docx, HTML+Chromium (PDF), python-pptx |
| LLM Adapter Service | FastAPI (Python) | FastAPI >=0.115 (Used as fallback) |
| Frontend Build | Vite | ^8.0.0, Tailwind CSS ^4.0.0 |
| Containerization | Docker | Render (Gateway) & HF Spaces (Media Gen) |
| Monitoring | Sentry | (Mobile/Frontend) |

## Project Architecture

```
Flutter App (Dio REST)
    |
    v
Rust Gateway (Axum) ----> OpenRouter (Primary LLM)
    |          |
    |          +--------> LLM Adapter (FastAPI/Python) [Fallback]
    |
    v
Media Generator (FastAPI/Python)
    |
    v
Cloudflare R2 / AWS S3 (artifacts)
```

The project is structured into four main components:

1.  **`gateway/` (Rust):** The core API orchestrator built with Axum and SQLx. Manages users, subjects, topics, media generation lifecycle, freelancer marketplace, and personalized project recommendations. Acts as the central orchestrator and communicates with LLMs natively (via OpenRouter) or falls back to the LLM Adapter.

2.  **`frontend/` (Flutter/Dart):** The mobile application client (iOS/Android). Feature-based architecture with modules: auth, home, media_generation, search, bookmark, gallery, profile, freelancer. Uses Riverpod for state management and Dio with layered interceptors (auth, cache, retry, logging, monitoring).

3.  **`media-generator-service/` (FastAPI/Python):** Document renderer for PDF (HTML+Chromium/Playwright), DOCX (python-docx), and PPTX (python-pptx) formats with registry pattern. Receives signed specification payloads from Rust gateway, renders artifacts, and returns signed download URLs. 7 test files.

4.  **`llm-adapter-service/` (FastAPI/Python):** Legacy boundary for LLM interactions (Gemini + OpenAI) now acting as a fallback for the Rust gateway. Handles prompt interpretation, content classification, drafting, and delivery response composition.

### Additional Components

-   **`docs/adr/`**: Architecture Decision Records documenting the completed Rust gateway migration.
-   **`subjects.json`**: 7686-line Indonesian curriculum taxonomy covering SD, SMP, SMA, and SMK levels.

## Directory Structure

```
frontend/
  lib/
    app/                     # app.dart (MaterialApp), env.dart
    core/
      config/                # animations, api_config, app_colors, feature_flags, theme
      network/               # 9 network files (interceptors, error handling, monitoring)
      providers/             # Riverpod providers
      storage/               # Locale preferences service
    features/
      auth/                  # Login, forgot password, account settings
      bookmark/              # Bookmark screen
      freelancer/            # Freelancer home, jobs, portfolio
      gallery/               # Gallery data, screens, widgets
      home/                  # Home screen, recommendation feed
      media_generation/      # Generation history, project success, status
      profile/               # Profile screen, settings
      search/                # Search data, screens, widgets
    l10n/                    # Localization (en, id)
    shared/widgets/          # Shared UI components (BottomNav, etc.)
  assets/                    # fonts (Mona Sans), images, avatars, icons
  test/                      # 7 test files + helpers
  integration_test/          # 3 integration tests

gateway/
  src/
    api/                     # Axum routing and handlers
    auth/                    # Auth, HMAC, session management
    cache/                   # Redis caching implementations
    contracts/               # Cross-service schemas
    db/                      # Database models and sqlx queries
    media_gen/               # Python client for media generation
    orchestrator/            # Workflow orchestration
    providers/               # LLM integration (OpenRouter, Fallback)
    queue/                   # Background job queue processing
  Cargo.toml                 # Rust dependencies
  render.yaml                # Render deployment configuration

llm-adapter-service/
  app/
    providers/               # gemini.py, openai.py, routing.py, base.py, registry.py
    routes/                  # interpret, draft, respond, health, ops
  tests/                     # 23 test files

media-generator-service/
  app/
    generators/              # pdf_generator.py, docx_generator.py, pptx_generator.py, registry.py
    auth.py                  # HMAC verification
    artifact_download.py     # Signed URL generation
  tests/                     # 7 test files
```

## Core Features

### Media Generation (Core Feature)
Submit a natural-language prompt describing desired educational content. The system processes through a 9-state lifecycle:

```
QUEUED -> INTERPRETING -> CLASSIFIED -> GENERATING -> UPLOADING -> PUBLISHING -> COMPLETED
                                                                 -> FAILED
                                                                 -> CANCELLED
```

Each state transition is validated, logged with full audit trail (timing, provider info, attempt numbers), and supports retry with state-specific behavior (requeue, resume, continue, restart). Regeneration creates parent-child chains.

### Freelancer Marketplace
Teachers can hire freelance educational content creators. Freelancers have separate UI navigation (home, jobs, portfolio) and receive task notifications.

### Personalized Recommendations
AI-powered project recommendation feed on homepage with personalization and aggregation services.

### Gallery
Public read-only gallery of media-rich educational content.

### LLM Governance
Semantic caching, per-minute/hour/day rate limiting, budget enforcement, and cost tracking managed natively by the Rust gateway or downstream providers.

## Inter-Service Authentication

All service-to-service calls use timestamped HMAC-SHA256 signatures:

-   Headers: `X-Klass-Generation-Id`, `X-Klass-Request-Timestamp`, `X-Klass-Signature-Algorithm`, `X-Klass-Signature`
-   Signature input: `{unix_timestamp}.{raw_body}`
-   Supports secret rotation via `accepted_shared_secrets` list
-   Replay protection with configurable max age (default 300s)

## Building and Running

### Gateway (Rust)

```bash
cd gateway
cargo build
# Run REST server
cargo run --features rest
# Run background worker
cargo run --features worker -- --worker
```

### Frontend (Flutter)

```bash
# Run with custom backend URL
flutter run --dart-define=API_BASE_URL=http://<BACKEND_IP>:8080/api

# Unit tests
flutter test -r expanded

# Integration tests
flutter test integration_test/
```

### Media Generator Service (FastAPI)

```bash
cd media-generator-service
pip install -r requirements.txt
uvicorn app.main:app --reload   # Development server
pytest                           # Tests
```

## Testing

| Component | Framework | Coverage |
|-----------|-----------|---------|
| Rust Gateway | cargo test | Integration and Unit tests via sqlx / Axum |
| Flutter Frontend | flutter_test + integration_test | 7 unit/widget + 3 integration tests |
| LLM Adapter | pytest 8.3+ | 23 test files (auth, cache, governance, providers, routing) |
| Media Generator | pytest 8.3+ | 7 test files (API, generators, sanitizer) |
| Load Testing | k6 | baseline.js, media_generation_e2e.js |

## Key Conventions

-   **Versioned API:** All endpoints prefixed with `/api/v1/`, centralized via `ApiConfig.v()` and `Env.apiVersion`
-   **Dio Interceptor Chain:** Auth -> Cache -> Retry -> Logging -> Monitoring (with CancelableStateMixin for widget disposal)
-   **Feature-Based Flutter Architecture:** Each feature contains `data/`, `screens/`, `widgets/`, `providers/` folders
-   **Structured Logging:** Both Rust and Python services use structured JSON logging with context
-   **Full Audit Trail:** Media generation logs every state transition with timing, provider info, and job context
-   **Localization:** English (en) and Indonesian (id) via ARB files
-   **Completed Rust Migration:** The backend has successfully migrated from Laravel to Rust (Axum). Legacy PHP references should be considered historical.
