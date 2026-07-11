# Klass Project Overview

**Klass** is an educational content generation and management platform focused on the Indonesian education market. It enables teachers to generate learning materials (PDF, DOCX, PPTX) using AI-powered LLM interpretation and content drafting, with a marketplace for freelance educational content creators.

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile Frontend | Flutter (Dart) | SDK ^3.11.1 |
| State Management | Riverpod | flutter_riverpod ^2.6.1 |
| HTTP Client | Dio | ^5.9.2 |
| Backend API | Laravel (PHP) | ^13.0, PHP ^8.3 |
| Authentication | Laravel Sanctum | ^4.0 |
| Database | PostgreSQL (Neon Cloud) | via Supabase/Neon, PgBouncer |
| Object Storage | Cloudflare R2 / Supabase Storage | S3-compatible |
| LLM Adapter Service | FastAPI (Python) | FastAPI >=0.115, Pydantic >=2.8 |
| LLM Providers | Gemini + OpenAI | gemini-2.0-flash, gpt-5.4 |
| Media Generator Service | FastAPI (Python) | python-docx, reportlab, python-pptx |
| Frontend Build | Vite | ^8.0.0, Tailwind CSS ^4.0.0 |
| Containerization | Docker | Multi-stage builds |
| Monitoring | Sentry | sentry-laravel ^4.0 |

## Project Architecture

```
Flutter App (Dio REST)
    |
    v
Laravel Backend (PHP 8.3) ----> LLM Adapter (FastAPI/Python) ----> Gemini / OpenAI
    |                                |
    |                                v
    |                          PostgreSQL (LLM cache, governance)
    |
    v
Media Generator (FastAPI/Python)
    |
    v
Cloudflare R2 / Supabase Storage (artifacts)
```

The project is structured into four main components:

1.  **`backend/` (Laravel/PHP):** The core backend API with 14 versioned API controllers (V1), 12 admin controllers, 22 service classes, 15 Eloquent models, and 20 FormRequest validation classes. Manages users, subjects, topics, media generation lifecycle, freelancer marketplace, and personalized project recommendations. Acts as the central orchestrator.

2.  **`frontend/` (Flutter/Dart):** The mobile application client (iOS/Android). Feature-based architecture with modules: auth, home, media_generation, search, bookmark, gallery, profile, freelancer. Uses Riverpod for state management and Dio with layered interceptors (auth, cache, retry, logging, monitoring).

3.  **`llm-adapter-service/` (FastAPI/Python):** Single boundary for LLM interactions (Gemini + OpenAI with provider fallback). Handles prompt interpretation, content classification, drafting, and delivery response composition. Extensive PostgreSQL-based semantic caching with stampede protection (advisory locks), rate limiting, daily budget enforcement, and cost tracking. Routes: interpret, draft, respond, health, ops. 23 test files.

4.  **`media-generator-service/` (FastAPI/Python):** Document renderer for PDF (reportlab), DOCX (python-docx), and PPTX (python-pptx) formats with registry pattern. Receives signed specification payloads from Laravel backend, renders artifacts, and returns signed download URLs. 7 test files.

### Additional Components

-   **`docs/adr/`**: 8 Architecture Decision Records documenting a planned Rust gateway migration.
-   **`subjects.json`**: 7686-line Indonesian curriculum taxonomy covering SD, SMP, SMA, and SMK levels.
-   **`scratch/`**: Utility scripts.

## Directory Structure

```
backend/
  app/
    Console/Commands/       # 7 Artisan commands (backfill, smoke test, seed)
    Http/
      Controllers/Admin/    # 12 admin controllers
      Controllers/Api/V1/   # 14 API controllers (versioned)
      Middleware/            # Admin, Freelancer, Teacher, StructuredApiLogger
      Requests/              # 20 FormRequest classes
      Resources/             # 9 JSON Resource transformers
    Jobs/                    # ProcessMediaGenerationJob (async queue)
    MediaGeneration/         # 17 domain classes (lifecycle, contracts, schemas, error codes)
    Models/                  # 15 Eloquent models
    Services/                # 22 service classes
  config/                    # 16 config files
  database/
    factories/
    migrations/              # 30 migration files
    seeders/
  docker/                    # nginx.conf, supervisord.conf, entrypoint.sh
  routes/                    # api.php, web.php, console.php
  tests/
    Feature/                 # 34 feature test files
    Unit/                    # 5 unit test files
    load/                    # k6 load test scripts

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

llm-adapter-service/
  app/
    providers/               # gemini.py, openai.py, routing.py, base.py, registry.py
    routes/                  # interpret, draft, respond, health, ops
    cache.py                 # 829-line cache service (stampede protection, advisory locks)
    governance.py            # 1014-line governance (rate limiting, budget enforcement)
    auth.py                  # HMAC-SHA256 inter-service auth
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
Semantic caching with PostgreSQL advisory lock-based stampede protection (Blake2b-derived lock IDs), per-minute/hour/day rate limiting, daily USD budget enforcement, provider fallback (Gemini -> OpenAI), and cost tracking.

### Admin Dashboard
12 admin controllers for monitoring, user management, content moderation, and taxonomy debugging.

## Inter-Service Authentication

All service-to-service calls use timestamped HMAC-SHA256 signatures:

-   Headers: `X-Klass-Generation-Id`, `X-Klass-Request-Timestamp`, `X-Klass-Signature-Algorithm`, `X-Klass-Signature`
-   Signature input: `{unix_timestamp}.{raw_body}`
-   Supports secret rotation via `accepted_shared_secrets` list
-   Replay protection with configurable max age (default 300s)

## Building and Running

### Backend (Laravel)

```bash
# Full setup
composer setup  # installs deps, generates key, runs migrations, builds frontend

# Development (parallel: server + queue + logs + vite)
composer dev

# Tests (SQLite in-memory)
composer test
```

### Frontend (Flutter)

```bash
# Run with custom backend URL
flutter run --dart-define=API_BASE_URL=http://<BACKEND_IP>:8000/api

# Unit tests
flutter test -r expanded

# Integration tests
flutter test integration_test/
```

### LLM Adapter Service (FastAPI)

```bash
cd llm-adapter-service
pip install -r requirements.txt
python -m app.database migrate  # PostgreSQL migrations
uvicorn app.main:app --reload   # Development server
pytest                           # Tests
```

### Media Generator Service (FastAPI)

```bash
cd media-generator-service
pip install -r requirements.txt
uvicorn app.main:app --reload   # Development server
pytest                           # Tests
```

### Docker

```bash
docker build .    # Multi-stage build (PHP-FPM + nginx + supervisor)
docker run -p 7860:7860  # Hugging Face Spaces compatible
```

## Testing

| Component | Framework | Coverage |
|-----------|-----------|---------|
| Laravel Backend | PHPUnit 12.5 | 34 Feature + 5 Unit tests (SQLite in-memory) |
| Flutter Frontend | flutter_test + integration_test | 7 unit/widget + 3 integration tests |
| LLM Adapter | pytest 8.3+ | 23 test files (auth, cache, governance, providers, routing) |
| Media Generator | pytest 8.3+ | 7 test files (API, generators, sanitizer) |
| Load Testing | k6 | baseline.js, media_generation_e2e.js |

PHPUnit config uses SQLite in-memory, array cache, sync queue, and disables Pulse/Telescope/Nightwatch.

## Key Conventions

-   **Versioned API:** All endpoints prefixed with `/api/v1/`, centralized via `ApiConfig.v()` and `Env.apiVersion`
-   **Dio Interceptor Chain:** Auth -> Cache -> Retry -> Logging -> Monitoring (with CancelableStateMixin for widget disposal)
-   **Feature-Based Flutter Architecture:** Each feature contains `data/`, `screens/`, `widgets/`, `providers/` folders
-   **FormRequest Validation:** 20 dedicated validation classes with rules and authorization
-   **JSON Resource Transformers:** 9 resource classes standardizing API response shapes
-   **Structured Logging:** Both backend and Python services use structured logging with `event_data` context
-   **Full Audit Trail:** Media generation logs every state transition with timing, provider info, and job context
-   **Localization:** English (en) and Indonesian (id) via ARB files
-   **Planned Rust Migration:** 18-week, 6-phase plan (see `IMPLEMENTATION_PLAN.md`) to replace Laravel + LLM Adapter with Rust (Axum + tonic) gateway
