# Target Architecture: Klass Rust Gateway

> **Phase**: Fase 2 Design (Task 2.2)
> **Status**: Accepted
> **Date**: 2026-07-11
> **Based on**: ADR-001 through ADR-008, `INTEGRATION_MAPPING.md`

---

## Table of Contents

1. [System Context (C4 Level 1)](#system-context-c4-level-1)
2. [Container Diagram (C4 Level 2)](#container-diagram-c4-level-2)
3. [Rust Gateway Internal Components (C4 Level 3)](#rust-gateway-internal-components-c4-level-3)
4. [Data Flow: Media Generation](#data-flow-media-generation)
5. [Communication Protocol Matrix](#communication-protocol-matrix)
6. [Deployment View](#deployment-view)
7. [Concurrency & Connection Model](#concurrency--connection-model)

---

## System Context (C4 Level 1)

```mermaid
C4Context
    title System Context — Klass Platform

    Person(teacher, "Teacher / User", "Creates educational content via mobile app")

    System(klass, "Klass Platform", "AI-powered educational content generation and marketplace")

    System_Ext(gemini, "Google Gemini", "LLM — content interpretation & drafting")
    System_Ext(openai, "OpenAI", "LLM — fallback provider")
    System_Ext(r2, "Cloudflare R2", "Object storage — artifacts & thumbnails")

    Rel(teacher, klass, "Generates learning materials, browses marketplace", "Mobile (iOS/Android)")
    Rel(klass, gemini, "Prompt interpretation + content drafting", "HTTPS + API Key")
    Rel(klass, openai, "Fallback LLM calls", "HTTPS + Bearer Token")
    Rel(klass, r2, "Upload/download generated artifacts", "S3 API + signed URLs")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

The Klass Platform is a single logical system from the user's perspective. Internally, it is composed of two runtime containers: the **Rust Gateway** (API + orchestrator + LLM integration) and the **Media Generator** (document rendering). These are detailed in the Container Diagram below.

---

## Container Diagram (C4 Level 2)

```mermaid
C4Container
    title Container Diagram — Rust Gateway + Media Generator

    Person(teacher, "Teacher", "Mobile app user")

    Container_Boundary(klass, "Klass Platform") {
        Container(flutter, "Flutter App", "Dart / Riverpod", "Mobile client — REST + gRPC stream. UI unchanged except 1 service file rewritten for gRPC streaming.")
        Container(gateway, "Rust Gateway", "axum + tonic + sqlx + tokio", "REST API (26 endpoints) + gRPC streaming. Orchestrator, state machine, LLM providers, caching, governance.")
        Container(media_gen, "Media Generator", "FastAPI / Python", "Document rendering: DOCX (python-docx), PDF (reportlab), PPTX (python-pptx). Stateless, HMAC-secured.")
        ContainerDb(neon, "Neon PostgreSQL", "PostgreSQL 17 + PgBouncer", "Application data + consolidated cache/governance tables. ~35 migrations (30 Laravel parity + 5-6 new).")
        ContainerDb(redis, "Upstash Redis", "Redis 7", "Job queue via Redis Streams. Consumer groups, DLQ, XCLAIM-based redelivery.")
        ContainerDb(r2, "Cloudflare R2", "S3-compatible object storage", "Generated artifacts (.pdf, .docx, .pptx) and thumbnails. Signed URL delivery to Flutter.")
    }

    System_Ext(gemini, "Google Gemini", "LLM — interpretation + drafting")
    System_Ext(openai, "OpenAI", "LLM — fallback provider")

    Rel(teacher, flutter, "User interaction", "Mobile")
    Rel(flutter, gateway, "REST API calls", "REST/JSON (Dio)")
    Rel(flutter, gateway, "Media-gen progress stream", "gRPC server-streaming")
    Rel(gateway, media_gen, "Submit generation spec, get artifact URL", "HTTP/2 + HMAC-SHA256")
    Rel(gateway, gemini, "LLM API calls", "HTTPS + API Key")
    Rel(gateway, openai, "Fallback LLM calls", "HTTPS + Bearer Token")
    Rel(gateway, neon, "Read/write application data, cache, governance", "sqlx (PgBouncer, TLS)")
    Rel(gateway, redis, "Enqueue/dequeue media-gen jobs", "Redis Streams (XADD/XREADGROUP)")
    Rel(gateway, r2, "Upload generated files, generate signed URLs", "S3 API (aws-sdk-s3)")
    Rel(media_gen, r2, "Write generated artifact", "S3 API (temporary)")
    Rel(flutter, r2, "Download artifact via signed URL", "HTTPS")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

### Container Responsibilities

| Container | Stack | Responsibilities | Scale |
|-----------|-------|-----------------|-------|
| **Flutter App** | Dart 3.11, Riverpod, Dio | 26 REST screens + gRPC progress listener. Auth, home, search, gallery, profile, freelancer marketplace. | N/A (client-side) |
| **Rust Gateway** | Rust (axum 0.7, tonic 0.12, sqlx 0.8, tokio 1.x) | All API endpoints, Sanctum auth, media-gen orchestrator (9-state), LLM provider routing, semantic cache, rate-limit governance, Redis Streams producer/consumer. | Render Starter: 0.5 vCPU, 512MB RAM |
| **Media Generator** | Python (FastAPI, python-docx, reportlab, python-pptx) | Stateless renderer: receives generation spec → produces .docx/.pdf/.pptx → returns signed URL. | HF Space #3 (shared CPU, auto-sleep) |
| **Neon PostgreSQL** | PostgreSQL 17 + PgBouncer | Application data (users, topics, media_generations, etc.) + consolidated LLM cache + governance tables. | Free tier: 10 connections (PgBouncer) |
| **Upstash Redis** | Redis 7 | Job queue: `KLASS:media-generation` stream + `KLASS:media-generation-dlq`. Consumer group: `KLASS:workers`. | Free tier: 256MB, 10k cmd/day |
| **Cloudflare R2** | S3-compatible | Generated file storage + thumbnail storage. Signed URL delivery. | Pay-per-request (~$0-5/mo) |

---

## Rust Gateway Internal Components (C4 Level 3)

```mermaid
C4Container
    title Component Diagram — Rust Gateway Internals

    Container_Boundary(gateway_boundary, "Rust Gateway (single binary)") {

        Container(network, "Network Layer", "axum 0.7 + tonic 0.12", "HTTP server on port 8080 (REST) and 50051 (gRPC). Request parsing, CORS, timeout, tracing.")
        
        Container(mw, "Middleware Stack", "tower / tower-http", "TraceLayer → CORS → Compression → Timeout → RequestId → Auth extractor → Role guard")

        Container(auth, "Auth Module", "argon2 / sha2", "Sanctum-compatible token verification. Password hash verify (Argon2). Role-based guards (teacher, freelancer, admin). HMAC signer for service-to-service calls.")

        Container(handlers, "REST Handlers", "axum::Router", "26 endpoint handlers organized by domain: auth (7), public-read (9), config+gallery (2), protected (6), teacher (1), admin (10). Request validation via garde.")

        Container(grpc, "gRPC Service", "tonic 0.12", "MediaGenerationService: SubmitMediaGeneration + Regenerate. Server-streaming GenerationProgressEvent per state transition.")

        Container(orchestrator, "Orchestrator", "tokio::join!", "WorkflowService: interpret → classify → generate → upload → publish → complete. State machine with 9 states and statusBefore invariant. tokio::join!(interpret, draft) for parallel LLM calls.")

        Container(providers, "LLM Provider Module", "reqwest 0.12", "GeminiProviderClient + OpenAIProviderClient. ProviderRouter with primary/fallback logic. HTTP/2 connection pooling. Circuit breaker via tower::limit + tower::retry.")

        Container(cache, "Cache Module", "sqlx", "AdapterCacheService: semantic cache with SHA-256 key. PostgreSQL advisory lock stampede protection (pg_try_advisory_lock). Lazy TTL cleanup. Byte-compatible hash with Python for migration.")

        Container(gov, "Governance Module", "sqlx", "AdapterGovernanceService: fixed-window rate limiting (minute/hour/day). Budget tracking per route ($25/day interpret, $10/day deliver). Preflight check. deny/degrade exhaustion actions.")

        Container(media_client, "Media Gen Client", "reqwest 0.12", "PythonMediaGeneratorClient: HMAC-signed POST /v1/generate. Timeout 60s, retry 2x, backoff 500ms. Artifact download from signed URL.")

        Container(storage, "Storage Module", "aws-sdk-s3", "R2/S3 multipart upload. Signed URL generation for Flutter download. Thumbnail generation for PDF first page.")

        Container(queue, "Queue Module", "redis 0.27", "Redis Streams producer (XADD) + consumer worker (XREADGROUP + XACK + XCLAIM). DLQ for exhausted retries. Idempotent via statusBefore check.")

        Container(db, "Database Layer", "sqlx 0.8", "PgPool (PgBouncer-compatible). 15 structs with #[derive(FromRow)]. Repository pattern: trait per entity + PgXxxRepo impl. ~35 sqlx migration files.")

        Container(config, "Config & State", "config 0.14", "AppState { db_pool, redis_pool, llm_clients, media_gen_client, config }. Env-var driven (parity with Laravel + LLM Adapter). Health endpoint GET /health.")

        Container(error, "Error Handling", "thiserror / axum", "AppError enum with per-category variants. IntoResponse impl → JSON { success: false, error: { code, message } } matching Laravel format.")
    }

    ContainerDb(neon, "Neon PostgreSQL", "PostgreSQL 17", "")
    ContainerDb(redis_ext, "Upstash Redis", "Redis 7", "")

    Rel(network, mw, "Request pipeline")
    Rel(mw, auth, "Token extraction")
    Rel(mw, handlers, "Route dispatch")
    Rel(mw, grpc, "gRPC stream dispatch")
    Rel(handlers, orchestrator, "POST /media-generations")
    Rel(handlers, db, "CRUD operations")
    Rel(grpc, orchestrator, "Submit / Regenerate")
    Rel(orchestrator, providers, "LLM interpret/draft/respond")
    Rel(orchestrator, cache, "Cache lookup/store")
    Rel(orchestrator, gov, "Preflight check")
    Rel(orchestrator, queue, "Enqueue job")
    Rel(queue, redis_ext, "XADD/XREADGROUP")
    Rel(orchestrator, media_client, "Generate artifact")
    Rel(media_client, storage, "Upload to R2")
    Rel(providers, cache, "Cache lookup before API call")
    Rel(providers, gov, "Record usage after API call")
    Rel(cache, neon, "cache_key lookup/upsert")
    Rel(gov, neon, "rate limit buckets upsert")
    Rel(db, neon, "All app queries")

    UpdateLayoutConfig($c4ShapeInRow="4", $c4BoundaryInRow="1")
```

### Module Dependency Map

```
network (axum + tonic)
  ├── middleware stack
  │     ├── TraceLayer
  │     ├── CORS
  │     ├── CompressionLayer
  │     ├── TimeoutLayer (30s default)
  │     ├── RequestId middleware
  │     ├── Auth extractor → Sanctum token verify → role guard
  │     └── StructuredApiLogger
  │
  ├── REST handlers (26 endpoints)
  │     ├── AuthController        (register, login, logout, me, refresh, security-question, verify-reset)
  │     ├── TopicController       (index, show, store, update, destroy)
  │     ├── ContentController     (index, show, store, update, destroy)
  │     ├── MarketplaceController (index, show, store, update, destroy)
  │     ├── ProgressController    (index, show, store, update, destroy)
  │     ├── MediaGenController    (index, store, show, regenerate)
  │     ├── HomeController        (recommendations, sections)
  │     ├── GalleryController     (index)
  │     ├── UserController        (avatar)
  │     ├── FreelancerController  (suggest, hire)
  │     ├── UploadController      (upload, destroy)
  │     └── DebugController       (taxonomy)
  │
  └── gRPC service (1 endpoint)
        └── MediaGenerationService
              ├── SubmitMediaGeneration (server-streaming)
              └── Regenerate (server-streaming)

orchestrator (WorkflowService)
  ├── StateMachine (MediaGenerationLifecycle — 9 states)
  ├── tokio::join!(interpret, draft)  ← parallel LLM calls
  │
  ├── interpret → LLM Provider Module (router)
  │     ├── Primary: GeminiProviderClient → https://generativelanguage.googleapis.com
  │     ├── Fallback: OpenAIProviderClient → https://api.openai.com
  │     ├── Circuit breaker: tower::limit + tower::retry
  │     └── Cache integration: lookup before call, store after
  │
  ├── classify → Local decision (no external call)
  │
  ├── generate → Media Gen Client
  │     └── POST /v1/generate (HMAC-SHA256) → download artifact → upload to R2
  │
  ├── publish → Create Topic + Content + MediaFile records
  │
  └── respond → LLM Provider Module (drafting) → delivery payload composition

infrastructure cross-cutting
  ├── db layer (sqlx::PgPool → Neon via PgBouncer)
  ├── cache module (semantic cache, advisory lock stampede protection)
  ├── governance module (rate limits, budget tracking, preflight)
  ├── queue module (Redis Streams: producer + consumer worker)
  ├── storage module (aws-sdk-s3 → Cloudflare R2)
  └── config (AppState, env vars, health endpoint)
```

---

## Data Flow: Media Generation

The following data flow applies identically for **PDF**, **DOCX**, and **PPTX** output formats. The only difference is the `preferred_output_type` field in the request and the `export_format` returned by the Media Generator.

### Sequence: Submit → Completed (Full Lifecycle)

```mermaid
sequenceDiagram
    actor User as Teacher
    participant Flutter
    participant Axum as Axum (REST :8080)
    participant Tonic as Tonic (gRPC :50051)
    participant Orchestrator as WorkflowService
    participant State as StateMachine (9-state)
    participant Provider as LLM Provider Module
    participant Gemini as Google Gemini
    participant Cache as Cache Module (sqlx)
    participant Gov as Governance Module
    participant Queue as Redis Streams
    participant MediaClient as Media Gen Client
    participant MediaGen as HF Space #3
    participant R2 as Cloudflare R2
    participant DB as Neon PostgreSQL

    Note over User,R2: === PHASE 1: Submit ===

    User->>Flutter: Enter prompt + choose format
    Flutter->>Axum: POST /v1/media-generations<br/>(Bearer token, prompt, preferred_output_type)
    Axum->>Axum: Validate (garde) + Sanctum auth
    Axum->>DB: INSERT INTO media_generations (status: QUEUED)
    DB-->>Axum: generation_id
    Axum-->>Flutter: { id, status: "queued" }

    Flutter->>Tonic: gRPC SubmitMediaGeneration(generation_id)
    Tonic->>Tonic: Open server-streaming channel

    Axum->>Queue: XADD KLASS:media-generation * generation_id {id}
    Queue-->>Axum: message_id

    Note over User,R2: === PHASE 2: Async Processing (Queue Worker) ===

    Queue->>Orchestrator: XREADGROUP BLOCK 5000 → pop job
    Orchestrator->>State: transition(QUEUED → INTERPRETING)

    Note over Orchestrator,R2: tokio::join!(interpret, draft) — parallel

    par Parallel LLM Calls
        Orchestrator->>Cache: lookup_interp(cache_key)
        alt Cache miss
            Orchestrator->>Gov: preflight_check(route=interpret)
            Gov->>DB: SELECT rate_limit_buckets
            Gov-->>Orchestrator: GovernanceDecision(allowed=true)
            Orchestrator->>Provider: interpret(payload)
            Provider->>Gemini: POST /v1beta/models/gemini-2.0-flash:generateContent
            Gemini-->>Provider: interpretation JSON
            Provider->>Gov: record_usage(route=interpret, tokens, cost)
            Gov->>DB: UPSERT rate_limit_buckets
            Provider->>Cache: store_interp(cache_key, response)
            Cache->>DB: INSERT INTO llm_cache_entries (route='interpret')
        end
        Cache-->>Orchestrator: InterpretationResult

        and
            Orchestrator->>Provider: draft(payload)
            Provider->>Gemini: POST /v1beta/models/gemini-2.0-flash:generateContent
            Gemini-->>Provider: content draft JSON
        end

    Orchestrator->>State: transition(INTERPRETING → CLASSIFIED)
    Orchestrator->>State: make_decision() → GENERATING

    Tonic-->>Flutter: GenerationProgressEvent(status=GENERATING)

    Note over Orchestrator,MediaGen: Media Gen call
    Orchestrator->>MediaClient: POST /v1/generate (HMAC-SHA256, 60s timeout)
    MediaClient->>MediaGen: HTTP/2 + HMAC headers
    MediaGen->>MediaGen: python-docx / reportlab / python-pptx render
    MediaGen-->>MediaClient: { artifact_locator: signed URL, metadata }
    MediaClient->>MediaClient: Download artifact from signed URL
    MediaClient->>R2: Upload artifact (multipart, S3 API)
    MediaClient->>R2: Generate + upload thumbnail
    R2-->>MediaClient: artifact_url, thumbnail_url

    Orchestrator->>State: transition(GENERATING → UPLOADING → PUBLISHING)
    Orchestrator->>DB: INSERT topic, content, media_file records

    Note over Orchestrator,DB: Delivery response
    Orchestrator->>Cache: lookup_delivery(cache_key)
    alt Cache miss
        Orchestrator->>Provider: respond(delivery_payload)
        Provider->>Gemini: POST generateContent
        Gemini-->>Provider: delivery JSON
        Provider->>Cache: store_delivery(cache_key, response)
    end
    Cache-->>Orchestrator: DeliveryResult

    Orchestrator->>DB: UPDATE media_generations (status, delivery_payload)
    Orchestrator->>State: transition(PUBLISHING → COMPLETED)
    Orchestrator->>Queue: XACK (acknowledge job)

    Tonic-->>Flutter: GenerationProgressEvent(status=COMPLETED, delivery_payload, artifact_url)

    Note over User,R2: === PHASE 3: Client Retrieval ===

    Flutter->>R2: GET {artifact signed URL}
    R2-->>Flutter: artifact file (.pdf / .docx / .pptx)
    Flutter-->>User: Display / share / download artifact
```

### State Transitions Per Integration Call

```
QUEUED ──(worker picks up job)────────────────► INTERPRETING
                                                    │
                     POST /v1/interpret (LLM Adapter)│
                     POST /v1/draft (LLM Adapter)    │ tokio::join!
                                                    ▼
                                               CLASSIFIED
                                                    │
                     Local decision (no external)   │
                                                    ▼
                                               GENERATING
                                                    │
                     POST /v1/generate (Media Gen)   │
                                                    ▼
                                               UPLOADING
                                                    │
                     S3 multipart upload to R2       │
                                                    ▼
                                               PUBLISHING
                                                    │
                     POST /v1/respond (LLM Adapter)  │
                                                    ▼
                                               COMPLETED

Any state ──(fatal error)──► FAILED
Any state ──(user cancel)──► CANCELLED
```

### Output Format Differences

| Phase | PDF | DOCX | PPTX |
|-------|-----|------|------|
| Request | `preferred_output_type: "pdf"` | `preferred_output_type: "docx"` | `preferred_output_type: "pptx"` |
| Media Gen library | `reportlab` | `python-docx` | `python-pptx` |
| MIME type | `application/pdf` | `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | `application/vnd.openxmlformats-officedocument.presentationml.presentation` |
| Thumbnail | PDF first-page render | (icon) | (icon) |
| **All other steps identical** | ✅ | ✅ | ✅ |

---

## Communication Protocol Matrix

```
                    Flutter                   Rust Gateway             Media Gen           Gemini/OpenAI          R2
                    ───────                   ────────────             ─────────           ─────────────          ──
Flutter             ·                         REST/JSON (Dio)          ·                    ·                      S3 signed URL (HTTPS)
                                             + gRPC stream (tonic)

Rust Gateway        REST/JSON (axum :8080)    ·                        HTTP/2 + HMAC         HTTPS + API Key        S3 API (aws-sdk-s3)
                    gRPC stream (tonic :50051)                          POST /v1/generate     POST generateContent
                                                                       (60s timeout)         (30s timeout)

Media Gen           ·                         HTTP/2 + HMAC            ·                    ·                      S3 write (temporary)
                                               POST /v1/generate

Redis (Upstash)     ·                         Redis Streams            ·                    ·                      ·
                                               XADD / XREADGROUP
                                               XACK / XCLAIM

Neon PostgreSQL     ·                         sqlx (PgBouncer, TLS)    ·                    ·                      ·
```

### Detailed Protocol Per Edge

| # | From | To | Protocol | Auth | Port | TLS | Details |
|---|------|----|----------|------|------|-----|---------|
| 1 | Flutter | Rust Gateway | REST/JSON | Bearer (Sanctum token) | 8080 | Yes | Dio HTTP client. 26 endpoints. Error format: `{success, error: {code, message}}`. Read timeout: 30s. |
| 2 | Flutter | Rust Gateway | gRPC server-streaming | Bearer (metadata) | 50051 | Yes | Tonic + grpc (Dart). Single RPC with stream of `GenerationProgressEvent`. Fallback to REST polling if gRPC blocked. |
| 3 | Flutter | R2 | HTTPS GET | Signed URL (query param) | 443 | Yes | Download generated artifact. URL from `delivery_payload.artifact.url`. Time-limited (expiry configurable). |
| 4 | Rust Gateway | Media Generator | HTTP/2 + JSON | HMAC-SHA256 | 443 | Yes | POST `/v1/generate`. Headers: `X-Klass-Generation-Id`, `X-Klass-Request-Timestamp`, `X-Klass-Signature-Algorithm`, `X-Klass-Signature`. Timeout: 60s. Retry: 2x, backoff 500ms. |
| 5 | Rust Gateway | Gemini | HTTPS + JSON | API Key (query param) | 443 | Yes | POST `/v1beta/models/{model}:generateContent`. Default model: `gemini-2.0-flash`. Timeout: 30s. |
| 6 | Rust Gateway | OpenAI | HTTPS + JSON | Bearer Token | 443 | Yes | POST `/v1/responses`. Optional: `OpenAI-Organization`, `OpenAI-Project` headers. Default model: `gpt-5.4`. Timeout: 30s. |
| 7 | Rust Gateway | Neon PostgreSQL | PostgreSQL wire | Password | 5432 | Yes | Via PgBouncer (connection pooling). Max 5 connections from Gateway. sqlx async queries. |
| 8 | Rust Gateway | Upstash Redis | Redis protocol | Password | 6379 | Yes | Redis Streams commands: XADD, XREADGROUP, XACK, XCLAIM. Connection pool: deadpool-redis. |
| 9 | Rust Gateway | R2 | S3 API | Access Key + Secret | 443 | Yes | aws-sdk-s3. Multipart upload for artifacts. Generate signed URLs (GET). |
| 10 | Media Generator | R2 | S3 API | Access Key + Secret | 443 | Yes | Write generated artifact (temporary). URL returned to Gateway for re-upload to permanent location. |

---

## Deployment View

```mermaid
C4Deployment
    title Deployment Diagram — Production Topology

    Deployment_Node(render, "Render Web Service", "Singapore (ap-southeast-1)") {
        Container(gateway_container, "Rust Gateway", "Docker (binary <30MB)", "Port 8080 (REST) + 50051 (gRPC)")
    }

    Deployment_Node(hf, "Hugging Face Space #3", "US East") {
        Container(media_gen_container, "Media Generator", "Docker (Python/FastAPI)", "Port 7860")
    }

    Deployment_Node(neon_cloud, "Neon Cloud", "Singapore (ap-southeast-1)") {
        ContainerDb(neon_db, "PostgreSQL 17", "PgBouncer pooler", "Port 5432")
        ContainerDb(neon_staging, "Staging Branch", "Neon DB branching", "CI test target")
    }

    Deployment_Node(upstash, "Upstash", "Singapore (ap-southeast-1)") {
        ContainerDb(redis_db, "Redis 7", "Free tier (256MB)", "Port 6379")
    }

    Deployment_Node(cf, "Cloudflare", "Global (CDN)") {
        ContainerDb(r2_bucket, "R2 Bucket", "S3-compatible", "klass-artifacts")
    }

    Deployment_Node(gh, "GitHub Actions", "CI/CD") {
        Container(ci, "CI Pipeline", "lint → test → build → deploy", "")
    }

    Deployment_Node(mobile, "Mobile Device", "") {
        Container(flutter_app, "Flutter App", "iOS / Android", "")
    }

    Rel(ci, gateway_container, "Deploy (Docker push)", "Render Deploy Hook")
    Rel(flutter_app, gateway_container, "REST + gRPC", "HTTPS")
    Rel(gateway_container, neon_db, "sqlx queries", "TLS, PgBouncer")
    Rel(gateway_container, redis_db, "XADD/XREADGROUP", "TLS")
    Rel(gateway_container, media_gen_container, "POST /v1/generate", "HTTPS + HMAC")
    Rel(gateway_container, r2_bucket, "Upload + signed URLs", "S3 API")
    Rel(media_gen_container, r2_bucket, "Write artifact", "S3 API")
    Rel(flutter_app, r2_bucket, "Download artifact", "HTTPS signed URL")
```

### Network Latency Budget

| Hop | Distance | Latency (p50) | Latency (p99) |
|-----|----------|---------------|---------------|
| Flutter → Render (Singapore) | Variable (mobile) | 50-200ms | 500ms |
| Render → Neon (same region) | <1ms (same DC) | <1ms | <5ms |
| Render → Upstash (same region) | <1ms (same DC) | <1ms | <5ms |
| Render → Media Gen (US East → Singapore) | ~12,000 km | 180ms | 250ms |
| Render → Gemini API (Google) | Variable | 80ms | 200ms |
| Render → OpenAI API | Variable | 150ms | 400ms |
| Render → R2 (CDN) | Variable (nearest PoP) | 20ms | 80ms |

> **Note**: Media Gen berada di US East (HF Space default region). Latency 180ms ini adalah bottleneck terbesar. Jika tersedia HF Space region Singapore, ini bisa turun ke <10ms. Fallback: HTTP/1.1 + keep-alive untuk mengurangi connection setup overhead.

---

## Concurrency & Connection Model

### Connection Pools

```
Rust Gateway (single binary)
│
├── Neon PostgreSQL (sqlx::PgPool)
│   ├── max_connections: 5  (Neon free tier: 10, sisakan 5 untuk dev tools)
│   ├── idle_timeout: 300s  (PgBouncer-compatible)
│   └── acquire_timeout: 10s
│
├── Upstash Redis (deadpool-redis)
│   ├── max_connections: 5  (Upstash free tier: 100)
│   ├── idle_timeout: 300s
│   └── wait_timeout: 5s
│
├── reqwest Client (LLM Provider HTTP/2)
│   ├── pool_max_idle_per_host: 20
│   ├── pool_idle_timeout: 90s
│   ├── http2_prior_knowledge: true
│   └── timeout: 30s
│
└── reqwest Client (Media Gen HTTP/2)
    ├── pool_max_idle_per_host: 5
    ├── http2_prior_knowledge: true
    └── timeout: 60s
```

### tokio Runtime Configuration

```rust
#[tokio::main]
async fn main() {
    // Multi-thread runtime (default: num_cpus threads)
    // Worker threads handle:
    //   - axum request handlers (REST)
    //   - tonic request handlers (gRPC)
    //   - Redis Stream consumer (spawned task)
    //   - Background cleanup tasks
    //
    // I/O intensive workload (not CPU-bound) → default thread count optimal
}
```

### Concurrency Limits

| Resource | Limit | Rationale |
|----------|-------|-----------|
| Concurrent media-gen jobs | 5 | Redis consumer group with 5 workers |
| Concurrent LLM provider calls | 20 | reqwest pool idle per host |
| DB connections | 5 | Neon free tier limit |
| Redis connections | 5 | Upstash free tier limit |
| Max request body | 10 MB | File upload handler |
| gRPC stream timeout | 300s | Queue job timeout |
| REST request timeout | 30s | Default handler timeout |

### Scaling Model

Gateway adalah **single binary, single instance** pada Starter tier. Arsitektur ini mendukung vertical scaling (upgrade Render tier) sebelum perlu horizontal scaling:

| Tier | vCPU | RAM | Concurrent Media-Gen | Monthly Cost |
|------|------|-----|----------------------|-------------|
| Starter | 0.5 shared | 512 MB | 1-5 jobs | $7 |
| Standard 1 | 1 dedicated | 2 GB | 5-20 jobs | $25 |
| Standard 2 | 2 dedicated | 4 GB | 20-50 jobs | $50 |

Jika horizontal scaling diperlukan (jarang — Rust binary efisien), Redis Streams consumer groups secara native mendukung multiple consumer instances tanpa perubahan kode.

---

## References

- `IMPLEMENTATION_PLAN.md` — Architecture Target (ASCII diagram), Risk Assessment Matrix
- `INTEGRATION_MAPPING.md` — Current state integration contracts, HMAC details, provider behavior, error codes
- `docs/adr/0001-rust-gateway-language.md` through `docs/adr/0008-cache-db-consolidation.md` — Architecture decisions
- `frontend/lib/core/network/dio_provider.dart` — Current Flutter HTTP client configuration
- `backend/config/services.php` — Current timeout/retry configuration
