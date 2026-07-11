# Task 1.1: Code Audit Laravel — Complete Inventory

> **Audit Date**: 2026-07-11
> **Commit**: `0b794bc`
> **Laravel Version**: 13.x (PHP 8.3+)
> **Sanctum Version**: 4.0

---

## 1. Endpoint Inventory (36 controller actions → 26 unique routes)

### 1.1 Public Auth Routes (4)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 1 | `/api/v1/auth/register` | POST | `AuthController@register` | `RegisterRequest` | `UserResource` | `throttle:3,1` (3/min) |
| 2 | `/api/v1/auth/login` | POST | `AuthController@login` | `LoginRequest` | `UserResource` | `throttle:5,1` (5/min) |
| 3 | `/api/v1/auth/get-security-question` | POST | `AuthController@getSecurityQuestion` | `GetSecurityQuestionRequest` | — (inline) | — |
| 4 | `/api/v1/auth/verify-and-reset-password` | POST | `AuthController@verifyAndResetPassword` | `ResetPasswordRequest` | — (inline) | `throttle:3,1` (3/min) |

### 1.2 Protected Auth Routes (3)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 5 | `/api/v1/auth/logout` | POST | `AuthController@logout` | — | — (inline) | — |
| 6 | `/api/v1/auth/me` | GET | `AuthController@me` | — | `UserResource` | — |
| 7 | `/api/v1/auth/refresh` | POST | `AuthController@refresh` | — | — (inline: `{token}`) | — |

### 1.3 Public Read Routes (9)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 8 | `/api/v1/topics` | GET | `TopicController@index` | — | `TopicResource` | — |
| 9 | `/api/v1/topics/{topic}` | GET | `TopicController@show` | — | `TopicResource` | — |
| 10 | `/api/v1/contents` | GET | `ContentController@index` | — | `ContentResource` | — |
| 11 | `/api/v1/contents/{content}` | GET | `ContentController@show` | — | `ContentResource` | — |
| 12 | `/api/v1/marketplace-tasks` | GET | `MarketplaceTaskController@index` | — | `MarketplaceTaskResource` | — |
| 13 | `/api/v1/marketplace-tasks/{marketplaceTask}` | GET | `MarketplaceTaskController@show` | — | `MarketplaceTaskResource` | — |
| 14 | `/api/v1/student-progress` | GET | `StudentProgressController@index` | — | `StudentProgressResource` | — |
| 15 | `/api/v1/student-progress/{studentProgress}` | GET | `StudentProgressController@show` | — | `StudentProgressResource` | — |
| 16 | `/api/v1/homepage-recommendations` | GET | `HomepageRecommendationController@index` | `HomepageRecommendationRequest` | `RecommendedProjectRecommendationCollection` | — |

### 1.4 App Config Routes (1)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 17 | `/api/v1/homepage-sections` | GET | `HomepageSectionController@index` | — | — (inline JSON) | — |

### 1.5 Gallery Routes (1)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 18 | `/api/v1/gallery` | GET | `GalleryController@index` | — | `ContentResource` | — |

**Note**: Plan states "gallery (index + show)" but only `index` exists. No `show` route.

### 1.6 Protected Routes (6)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 19 | `/api/v1/user/avatar` | POST | `AvatarController@store` | `StoreAvatarRequest` | `UserResource` | — |
| 20 | `/api/v1/media-generations` | GET | `MediaGenerationController@index` | — | `MediaGenerationResource` | — |
| 21 | `/api/v1/media-generations` | POST | `MediaGenerationController@store` | `StoreMediaGenerationRequest` | `MediaGenerationResource` | — |
| 22 | `/api/v1/media-generations/{mediaGeneration}` | GET | `MediaGenerationController@show` | — | `MediaGenerationResource` | — |
| 23 | `/api/v1/media-generations/{mediaGeneration}/regenerate` | POST | `MediaGenerationController@regenerate` | `RegenerateMediaGenerationRequest` | `MediaGenerationResource` | — |
| 24 | `/api/v1/media-generations/{mediaGeneration}/suggest-freelancers` | POST | `FreelancerSuggestionController@suggest` | — | — (inline) | — |
| 25 | `/api/v1/media-generations/{mediaGeneration}/hire-freelancer` | POST | `FreelancerHiringController@hire` | `HireFreelancerRequest` | — (inline) | — |

### 1.7 Teacher Routes (1)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 26 | `/api/v1/topics` | POST | `TopicController@store` | `StoreTopicRequest` | `TopicResource` | — |

### 1.8 Admin Routes (11)

| # | Route | Method | Controller | FormRequest | Resource | Rate-Limit |
|---|-------|--------|------------|-------------|----------|------------|
| 27 | `/api/v1/admin/media-generations/{mediaGeneration}/debug-taxonomy` | GET | `AdminMediaGenerationDebugController@show` | — | `MediaGenerationTaxonomyDebugResource` | — |
| 28 | `/api/v1/topics/{topic}` | PUT/PATCH | `TopicController@update` | `UpdateTopicRequest` | `TopicResource` | — |
| 29 | `/api/v1/topics/{topic}` | DELETE | `TopicController@destroy` | — | — (noContent) | — |
| 30 | `/api/v1/contents` | POST | `ContentController@store` | `StoreContentRequest` | `ContentResource` | — |
| 31 | `/api/v1/contents/{content}` | PUT/PATCH | `ContentController@update` | `UpdateContentRequest` | `ContentResource` | — |
| 32 | `/api/v1/contents/{content}` | DELETE | `ContentController@destroy` | — | — (noContent) | — |
| 33 | `/api/v1/marketplace-tasks` | POST | `MarketplaceTaskController@store` | `StoreMarketplaceTaskRequest` | `MarketplaceTaskResource` | — |
| 34 | `/api/v1/marketplace-tasks/{marketplaceTask}` | PUT/PATCH | `MarketplaceTaskController@update` | `UpdateMarketplaceTaskRequest` | `MarketplaceTaskResource` | — |
| 35 | `/api/v1/marketplace-tasks/{marketplaceTask}` | DELETE | `MarketplaceTaskController@destroy` | — | — (noContent) | — |
| 36 | `/api/v1/student-progress` | POST | `StudentProgressController@store` | `StoreStudentProgressRequest` | `StudentProgressResource` | — |
| 37 | `/api/v1/student-progress/{studentProgress}` | PUT/PATCH | `StudentProgressController@update` | `UpdateStudentProgressRequest` | `StudentProgressResource` | — |
| 38 | `/api/v1/student-progress/{studentProgress}` | DELETE | `StudentProgressController@destroy` | — | — (noContent) | — |
| 39 | `/api/v1/upload/{category}` | POST | `FileUploadController@upload` | `FileUploadRequest` | — (inline) | — |
| 40 | `/api/v1/upload/{category}` | DELETE | `FileUploadController@destroy` | — | — (inline) | — |

### 1.9 Freelancer Routes (0 active)

Route group exists with `freelancer` middleware alias but no endpoints defined (placeholder only).

### 1.10 Summary

| Category | Count |
|----------|-------|
| Public Auth | 4 |
| Protected Auth | 3 |
| Public Read | 9 |
| App Config | 1 |
| Gallery | 1 |
| Protected (auth:sanctum) | 7 |
| Teacher | 1 |
| Admin | 14 (7 PUT+PATCH counted as 1 action each = 8 unique) |
| **Total unique controller actions** | **40** |
| **Total unique route patterns** | **26** |

### 1.11 Middleware Chain Summary

| Middleware | Applied To | Behavior |
|------------|-----------|----------|
| `throttle:3,1` | register, verify-and-reset-password | 3 requests/min per IP |
| `throttle:5,1` | login | 5 requests/min per IP |
| `auth:sanctum` | All protected routes | Sanctum token validation |
| `teacher` | topics/store, media-generations/* | `isAdmin() \|\| isTeacher()` check |
| `freelancer` | (no active routes) | `isAdmin() \|\| isFreelancer()` check |
| `admin` | All admin CRUD + debug-taxonomy | `isAdmin()` check |
| `StructuredApiLogger` | All API routes (global) | Structured logging, slow request detection |
| `HandleCors` | All routes (global) | CORS headers |

**Note**: `EnsureUserIsTeacher` and `EnsureUserIsFreelancer` both allow admin bypass. `EnsureUserIsAdmin` does NOT allow teacher/freelancer bypass.

---

## 2. FormRequest Validation Rules

### 2.1 Base Class: `ApiFormRequest`

All FormRequests extend `ApiFormRequest` except `RegenerateMediaGenerationRequest` and `HireFreelancerRequest` which extend `FormRequest` directly.

**Common behavior**: `authorize()` returns `true`; `failedValidation()` returns JSON `{success: false, message: "Validasi gagal.", errors: {...}}` with HTTP 422.

### 2.2 Validation Rules Inventory

| FormRequest | Fields | Rules (garde crate equivalent) |
|-------------|--------|-------------------------------|
| **RegisterRequest** | `name` | `required\|string\|max:255` |
| | `email` | `required\|string\|email\|max:255\|unique:users,email` |
| | `password` | `required\|string\|min:8\|confirmed` |
| | `role` | `sometimes\|string\|in:teacher,freelancer` |
| | `primary_subject_id` | `nullable\|integer\|exists:subjects,id` |
| **LoginRequest** | `email` | `required\|string\|email` |
| | `password` | `required\|string` |
| **GetSecurityQuestionRequest** | `email` | `required\|email` |
| **ResetPasswordRequest** | `email` | `required\|email` |
| | `security_answer` | `required\|string` |
| | `new_password` | `required\|string\|min:6` |
| **StoreTopicRequest** | `title` | `required\|string\|max:255` |
| | `teacher_id` | `nullable\|string\|max:255` |
| | `sub_subject_id` | `nullable\|integer\|exists:sub_subjects,id` |
| | `subject_id` | `nullable\|integer\|exists:subjects,id` |
| | `taxonomy` | `sometimes\|array` |
| | `taxonomy.subject.id` | `sometimes\|integer\|exists:subjects,id` |
| | `taxonomy.sub_subject.id` | `sometimes\|integer\|exists:sub_subjects,id` |
| | `thumbnail_url` | `nullable\|string\|url\|max:2048` |
| | **Custom**: taxonomy consistency | sub_subject must belong to subject |
| **UpdateTopicRequest** | Same as Store but all `sometimes` | Same rules, `sometimes` instead of `required` |
| **StoreContentRequest** | `topic_id` | `required\|uuid\|exists:topics,id` |
| | `type` | `required\|in:module,quiz,brief` |
| | `title` | `nullable\|string\|max:255` |
| | `data` | `nullable\|array` |
| | `media_url` | `nullable\|string\|url\|max:2048` |
| **UpdateContentRequest** | Same as Store but all `sometimes` | Same rules |
| **StoreMarketplaceTaskRequest** | `content_id` | `required\|uuid\|exists:contents,id` |
| | `status` | `sometimes\|in:open,taken,done` |
| | `creator_id` | `nullable\|string\|max:255` |
| | `attachment_url` | `nullable\|string\|url\|max:2048` |
| **UpdateMarketplaceTaskRequest** | `status` | `sometimes\|in:open,taken,done` |
| | `creator_id` | `nullable\|string\|max:255` |
| | `attachment_url` | `nullable\|string\|url\|max:2048` |
| **StoreStudentProgressRequest** | `student_name` | `required\|string\|max:255` |
| | `score` | `required\|integer\|min:0\|max:100` |
| | `completion_date` | `nullable\|date` |
| **UpdateStudentProgressRequest** | Same as Store but all `sometimes` | Same rules |
| **StoreMediaGenerationRequest** | `prompt` | `required\|string\|max:5000` |
| | `preferred_output_type` | `nullable\|string\|in:auto,docx,pdf,pptx` |
| | `subject_id` | `nullable\|integer\|exists:subjects,id` |
| | `sub_subject_id` | `nullable\|integer\|exists:sub_subjects,id` |
| | **Custom**: sub_subject must belong to subject | Cross-field validation |
| | **Custom**: `prepareForValidation()` | Trim prompt, lowercase preferred_output_type |
| | **Custom**: `failedValidation()` | Custom error format with `MediaGenerationErrorCode` |
| **RegenerateMediaGenerationRequest** | `additional_prompt` | `required\|string\|max:5000` |
| **StoreAvatarRequest** | `file` | `required\|file\|mimes:jpg,jpeg,png,webp\|max:2048` |
| **FileUploadRequest** | `file` | `required\|file\|mimes:{dynamic}\|max:{dynamic}` |
| | Dynamic from `filesystems.upload_categories.{category}` config |
| **HomepageRecommendationRequest** | `limit` | `nullable\|integer\|min:1\|max:50` |
| **HireFreelancerRequest** | `mode` | `required\|string\|in:auto_suggest,manual_task` |
| | `refinement_description` | `required\|string\|max:2000` |
| | `selected_freelancer_id` | `required_if:mode,auto_suggest\|integer\|exists:users,id` |

### 2.3 Validation Notes for Rust Port

- **Password min inconsistency**: `RegisterRequest` uses `min:8`, `ResetPasswordRequest` uses `min:6`. Standardize in Rust.
- **UUID validation**: `topic_id`, `content_id` validated as UUID in store routes but NOT in query params (index/show). Rust should validate consistently.
- **`unique:users,email`**: Only in `RegisterRequest`. Rust must do DB check.
- **`exists:` rules**: 9 different tables referenced. Rust needs `garde` custom validators with DB lookups.
- **File upload**: `FileUploadRequest` dynamically loads allowed mimes from config. Rust needs equivalent config system.
- **`InteractsWithTopicPayload` trait**: Normalizes legacy field names (`taxonomy.subject.id` → `subject_id`, `media_url`/`image`/`imagePath` → `thumbnail_url`). Rust should handle backward compatibility.

---

## 3. JsonResource Output Shape Spec

### 3.1 UserResource

```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "avatar_url": "string|null",
  "primary_subject_id": "int|null",
  "primary_subject": {"id": "int", "name": "string", "slug": "string"} | null,
  "role": "string",
  "is_admin": "bool",
  "is_teacher": "bool",
  "is_freelancer": "bool",
  "personalization_subject": {  // conditional: ?include_personalization_context=true
    "id": "int",
    "name": "string",
    "slug": "string",
    "source": "string"
  } | null,
  "email_verified_at": "ISO8601|null",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.2 TopicResource

```json
{
  "id": "uuid",
  "title": "string",
  "teacher_id": "string|null",
  "owner_user_id": "uuid|null",
  "ownership_status": "string",
  "sub_subject_id": "int|null",
  "subject_id": "int|null",
  "taxonomy": {
    "subject": {"id": "int", "name": "string", "slug": "string"},
    "sub_subject": {"id": "int", "subject_id": "int", "name": "string", "slug": "string"}
  } | null,
  "personalization": "mixed",
  "thumbnail_url": "string|null",
  "is_published": "bool",
  "order": "int",
  "contents_count": "int",  // when counted
  "contents": [...],         // when loaded (ContentResource collection)
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.3 ContentResource

```json
{
  "id": "uuid",
  "topic_id": "uuid",
  "type": "module|quiz|brief",
  "title": "string|null",
  "data": "object|null",
  "media_url": "string|null",
  "topic": {...},   // when loaded (TopicResource)
  "tasks": [...],   // when loaded (MarketplaceTaskResource collection)
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.4 MarketplaceTaskResource

```json
{
  "id": "uuid",
  "content_id": "uuid",
  "status": "open|taken|done",
  "creator_id": "string|null",
  "attachment_url": "string|null",
  "content": {...},  // when loaded (ContentResource)
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.5 StudentProgressResource

```json
{
  "id": "uuid",
  "student_name": "string",
  "score": "int (0-100)",
  "completion_date": "ISO8601|null",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.6 MediaGenerationResource

```json
{
  "id": "uuid",
  "generated_from_id": "uuid|null",
  "is_regeneration": "bool",
  "teacher_id": "uuid",
  "prompt": "string",
  "preferred_output_type": "auto|docx|pdf|pptx",
  "resolved_output_type": "docx|pdf|pptx|null",
  "status": "queued|interpreting|classified|generating|uploading|publishing|completed|failed|cancelled",
  "status_meta": {
    "lifecycle_version": "string",
    "is_terminal": "bool",
    "retry_behavior": "string|null"
  },
  "subject_id": "int|null",
  "sub_subject_id": "int|null",
  "taxonomy": {
    "subject": {"id": "int", "name": "string", "slug": "string"},
    "sub_subject": {"id": "int", "subject_id": "int", "name": "string", "slug": "string"}
  } | null,
  "provider": {
    "llm": {"name": "string|null", "model": "string|null"},
    "generator": {"name": "string|null", "model": "string|null"}
  },
  "artifact": {
    "storage_path": "string|null",
    "file_url": "string|null",
    "thumbnail_url": "string|null",
    "mime_type": "string|null"
  },
  "publication": {
    "topic": {"id": "uuid", "title": "string"} | null,
    "content": {"id": "uuid", "title": "string", "type": "string", "media_url": "string"} | null,
    "recommended_project": {"id": "uuid", "title": "string", "source_type": "string", "project_file_url": "string"} | null
  },
  "delivery_payload": "object|null",
  "error": {"code": "string", "message": "string", "retryable": "bool"} | null,
  "links": {"poll": "string"},
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.7 MediaGenerationTaxonomyDebugResource

```json
{
  "id": "uuid",
  "status": "string",
  "prompt": "string",
  "persisted_taxonomy": {
    "subject": {"id": "int", "name": "string", "slug": "string"} | null,
    "sub_subject": {"id": "int", "subject_id": "int", "name": "string", "slug": "string"} | null
  },
  "interpretation_context": {
    "subject_context": "mixed",
    "sub_subject_context": "mixed"
  },
  "taxonomy_inference": "object|null",
  "draft_taxonomy_hint": "mixed",
  "drafting": {
    "source": "string|null",
    "schema_version": "string|null",
    "fallback_triggered": "bool",
    "fallback_reason_code": "string|null"
  },
  "links": {"poll": "string"},
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### 3.8 RecommendedProjectRecommendationResource

```json
{
  "id": "string",
  "title": "string",
  "description": "string|null",
  "thumbnail_url": "string|null",
  "ratio": "string (default: 16:9)",
  "project_type": "string|null",
  "tags": ["string"],
  "modules": ["string"],
  "sub_subject_id": "int|null",
  "subject_id": "int|null",
  "taxonomy": "object|null",
  "personalization": "object|null",
  "source_type": "string|null",
  "display_priority": "int (default: 0)",
  "visibility": {
    "is_active": "bool",
    "starts_at": "ISO8601|null",
    "ends_at": "ISO8601|null"
  },
  "source_reference": "mixed",  // conditional: ?include_source_context=true
  "source_payload": "mixed",     // conditional: ?include_source_context=true
  "created_at": "ISO8601|null",
  "updated_at": "ISO8601|null"
}
```

### 3.9 RecommendedProjectRecommendationCollection

```json
{
  "data": [RecommendedProjectRecommendationResource, ...],
  "meta": {
    "total": "int",
    "source_breakdown": {
      "admin_upload": "int",
      "system_topic": "int",
      "ai_generated": "int"
    },
    "section": {...},
    "limit": {"requested": "int|null", "applied": "int"},
    "personalization": {...},
    "source_status": {...}
  }
}
```

### 3.10 Standard Response Envelope

All API responses use this envelope (via `ApiResponseTrait`):

```json
// Success
{"success": true, "data": {...}, "message": "string"}

// Error
{"success": false, "message": "string", "errors": {...}, "error": {"code": "string", "message": "string", "retryable": "bool"}, "timestamp": "ISO8601"}
```

---

## 4. Service Dependency Graph (22 services)

### 4.1 Pure Orchestration (port ke Rust — no business rules)

| Service | Lines | Dependencies | Purpose |
|---------|-------|-------------|---------|
| `MediaGenerationWorkflowService` | ~200 | InterpretationService, DecisionService, PythonClient, PublicationService, DeliveryService, AuditTrailService | Top-level pipeline orchestrator |
| `MediaGenerationSubmissionService` | ~80 | MediaGeneration model | Entry point: create/deduplicate generation records |
| `MediaGenerationAuditTrailService` | ~120 | MediaGenerationLifecycle | Status transitions, timing, structured logging |
| `MediaPublicationService` | ~180 | FileUploadService, ThumbnailGeneratorService, Topic/Content/RecommendedProject models | Upload artifact, create publication entities |
| `MediaDeliveryResponseService` | ~150 | InterServiceRequestSigner, LLM adapter HTTP | Compose teacher-facing delivery response |
| `InterServiceRequestSigner` | ~60 | (none) | HMAC-SHA256 signing utility |
| `RegenerationContextService` | ~40 | MediaGeneration model | Build regeneration context array |

### 4.2 Business Decision (contain scoring/rules/inference — need spec)

| Service | Lines | Dependencies | Business Rule |
|---------|-------|-------------|---------------|
| `MediaGenerationDecisionService` | ~250 | MediaContentDraftingService | Output type selection: scores PDF/DOCX/PPTX |
| `MediaPromptInterpretationService` | ~200 | InterServiceRequestSigner, TaxonomyInferenceService, LLM adapter HTTP | Prompt interpretation via LLM |
| `MediaPromptTaxonomyInferenceService` | ~300 | SubjectsJsonTaxonomyCatalog, Subject/SubSubject models | Taxonomy inference: token matching, jenjang/kelas/semester detection |
| `MediaContentDraftingService` | ~180 | InterServiceRequestSigner, LLM adapter HTTP | Content drafting via LLM |
| `RecommendationPersonalizationService` | ~150 | User, Subject, SubSubject, Topic models | Personalization signals resolution |
| `RecommendationAggregationService` | ~200 | RecommendedProject, SystemRecommendationAssignment, Topic models | Feed ranking + candidate selection |
| `FreelancerMatchingService` | ~120 | User model | Freelancer scoring: portfolio 50% + success rate 30% + availability 20% |
| `SystemRecommendationAssignmentService` | ~80 | SystemRecommendationAssignment model | Distribution tracking |

### 4.3 Infrastructure/Adapter (port as-is)

| Service | Lines | Dependencies | Purpose |
|---------|-------|-------------|---------|
| `PythonMediaGeneratorClient` | ~150 | MediaGenerationSpecContract | HTTP client → Python renderer |
| `PythonMediaGeneratorHealthCheckService` | ~40 | MediaGenerationSpecContract | Health check for Python service |
| `LlmAdapterHealthCheckService` | ~50 | InterServiceRequestSigner | Health check for LLM adapter |
| `LlmAdapterSmokeTestService` | ~80 | InterServiceRequestSigner | E2E smoke test |
| `FileUploadService` | ~100 | Supabase S3 storage | Upload/delete/exists on S3 |
| `ThumbnailGeneratorService` | ~120 | Imagick, ZipArchive | Extract/generate thumbnails |

### 4.4 Pipeline Flow

```
POST /media-generations
  └→ MediaGenerationSubmissionService::createOrReuse()
  └→ ProcessMediaGenerationJob (queued)
       └→ MediaGenerationWorkflowService::process(generation_id, attempt, job_context)
            ├─ AuditTrailService::transition(QUEUED → INTERPRETING)
            ├─ ensureClassified()
            │    ├─ MediaPromptInterpretationService::interpret()
            │    │    ├─ TaxonomyInferenceService::infer()
            │    │    └─ LLM Adapter HTTP POST /v1/interpret
            │    ├─ AuditTrailService::transition(INTERPRETING → CLASSIFIED)
            │    └─ MediaGenerationDecisionService::decide()
            │         └─ MediaContentDraftingService::draft()
            │              └─ LLM Adapter HTTP POST /v1/draft
            ├─ ensureGenerated()
            │    ├─ AuditTrailService::transition(CLASSIFIED → GENERATING)
            │    ├─ PythonMediaGeneratorClient::generate()
            │    │    └─ Python HTTP POST /v1/generate
            │    └─ AuditTrailService::transition(GENERATING → UPLOADING)
            ├─ ensurePublished()
            │    ├─ AuditTrailService::transition(UPLOADING → PUBLISHING)
            │    └─ MediaPublicationService::publish()
            │         ├─ FileUploadService::upload() → R2
            │         └─ ThumbnailGeneratorService::generate()
            └─ ensureCompleted()
                 ├─ AuditTrailService::transition(PUBLISHING → COMPLETED)
                 └─ MediaDeliveryResponseService::compose()
                      └─ LLM Adapter HTTP POST /v1/respond
```

---

## 5. State Machine — EXACT Map

### 5.1 Status Constants

```php
QUEUED      = 'queued'
INTERPRETING = 'interpreting'
CLASSIFIED   = 'classified'
GENERATING   = 'generating'
UPLOADING    = 'uploading'
PUBLISHING   = 'publishing'
COMPLETED    = 'completed'
FAILED       = 'failed'
CANCELLED    = 'cancelled'
```

### 5.2 Valid Transitions (EXACT)

```
QUEUED → INTERPRETING, FAILED, CANCELLED
INTERPRETING → CLASSIFIED, FAILED, CANCELLED
CLASSIFIED → GENERATING, FAILED, CANCELLED
GENERATING → UPLOADING, FAILED, CANCELLED
UPLOADING → PUBLISHING, FAILED, CANCELLED
PUBLISHING → COMPLETED, FAILED
COMPLETED → (terminal)
FAILED → (terminal)  [retry behavior: restart_from_interpreting]
CANCELLED → (terminal) [retry behavior: manual_requeue_only]
```

### 5.3 Status Order (for invariant check)

```php
STATUS_ORDER = [
    'queued'      => 0,
    'interpreting' => 1,
    'classified'   => 2,
    'generating'   => 3,
    'uploading'    => 4,
    'publishing'   => 5,
    'completed'    => 6,
    'failed'       => 7,
    'cancelled'    => 8,
]
```

### 5.4 Retry Behaviors

| Status | Retry Behavior | Description |
|--------|---------------|-------------|
| `queued` | `requeue_pending_job` | Job can be re-dispatched |
| `interpreting` | `resume_current_step` | Resume from interpretation |
| `classified` | `continue_to_next_step` | Continue to generation |
| `generating` | `resume_current_step` | Resume generation |
| `uploading` | `resume_current_step` | Resume upload |
| `publishing` | `resume_current_step` | Resume publication |
| `completed` | `forbidden` | No retry allowed |
| `failed` | `restart_from_interpreting` | Full restart |
| `cancelled` | `manual_requeue_only` | Manual intervention required |

### 5.5 Terminal States

```php
COMPLETED, FAILED, CANCELLED
```

### 5.6 Concurrency Control

- `AuditTrailService::transition()` uses `lockForUpdate()` (SELECT ... FOR UPDATE) to prevent race conditions
- All transitions validate `statusBefore()` invariant (state cannot go backward)
- Each transition inserts a row in `status_history` JSONB array with timing metadata

### 5.7 State Machine Diagram

```
                    ┌──────────┐
                    │  QUEUED  │
                    └────┬─────┘
                         │
                    ┌────▼──────────┐
              ┌────►│ INTERPRETING  │
              │     └────┬──────────┘
              │          │
              │     ┌────▼──────────┐
              │     │  CLASSIFIED   │
              │     └────┬──────────┘
              │          │
              │     ┌────▼──────────┐
              │     │  GENERATING   │
              │     └────┬──────────┘
              │          │
              │     ┌────▼──────────┐
              │     │   UPLOADING   │
              │     └────┬──────────┘
              │          │
              │     ┌────▼──────────┐
              │     │  PUBLISHING   │──────┐
              │     └────┬──────────┘      │
              │          │                 │
              │     ┌────▼──────────┐      │
              │     │  COMPLETED    │      │
              │     └───────────────┘      │
              │                            │
    ┌─────────┴───────┐           ┌───────▼────┐
    │     FAILED      │           │   FAILED   │
    │ (any state)     │           │(publishing)│
    └─────────────────┘           └────────────┘

    ┌─────────────────┐
    │   CANCELLED     │  (not from PUBLISHING or COMPLETED)
    │ (QUEUED→UPLOAD) │
    └─────────────────┘
```

---

## 6. Event Listeners & Subscribers

### 6.1 Findings

- **No `EventServiceProvider`** — Laravel 11+ uses automatic event discovery
- **No `app/Events/` directory** — No custom events defined
- **No `app/Listeners/` directory** — No custom listeners defined
- **No `app/Providers/EventServiceProvider.php`** — Removed in Laravel 11+

### 6.2 Implicit Events

The only implicit events are Eloquent model events (created, updated, deleted) used via:
- `User::create()` in AuthController
- `Topic::create()`, `Content::create()`, etc. in CRUD controllers
- `MarketplaceTask::updateOrCreate()` in FreelancerSuggestionController

### 6.3 Activity Logging

`ActivityLog::create()` is called explicitly in `AuthController@login` for failed login attempts. No event-driven logging.

### 6.4 Impact on Rust Port

No event system to port. Activity logging is inline. The Rust port can use `tracing` for structured logging instead of event/listener pattern.

---

## 7. Composer Dependency Analysis

### 7.1 Production Dependencies (4)

| Package | Version | Purpose | Rust Equivalent |
|---------|---------|---------|-----------------|
| `laravel/framework` | ^13.0 | Core framework | `axum` + `tokio` + `sqlx` |
| `laravel/sanctum` | ^4.0 | API token authentication | Custom impl: `sha2` + DB lookup |
| `laravel/tinker` | ^3.0 | REPL for debugging | N/A (dev tool only) |
| `league/flysystem-aws-s3-v3` | ^3.0 | S3-compatible storage | `aws-sdk-s3` |

### 7.2 Dev Dependencies (6)

| Package | Version | Purpose | Rust Equivalent |
|---------|---------|---------|-----------------|
| `fakerphp/faker` | ^1.23 | Test data generation | `fake` crate or fixtures |
| `laravel/pail` | ^1.2.5 | Real-time log tail | N/A |
| `laravel/pint` | ^1.27 | Code style fixer | `cargo fmt` + `clippy` |
| `mockery/mockery` | ^1.6 | Mocking framework | `mockall` or `mockito` |
| `nunomaduro/collision` | ^8.6 | Error reporting | N/A |
| `phpunit/phpunit` | ^12.5.12 | Testing framework | `cargo test` + `nextest` |

### 7.3 Implicit Dependencies (via Laravel)

- **Database**: PostgreSQL via `pdo_pgsql`
- **Queue**: Database queue driver (default)
- **Cache**: File cache driver (default)
- **Session**: Cookie-based
- **Logging**: Monolog → `tracing` in Rust

---

## 8. Scheduled Tasks

### 8.1 Findings

**No scheduled tasks found.**

- `routes/console.php` contains only the default `inspire` command
- No `app/Console/Kernel.php` (Laravel 11+ removed it)
- No custom Artisan commands in `app/Console/Commands/`

### 8.2 Queue Worker

The `composer.json` `dev` script includes:
```bash
php artisan queue:listen --tries=1 --timeout=0
```

This runs the queue worker for `ProcessMediaGenerationJob`. In Rust, this becomes the Redis Streams consumer worker.

---

## 9. Discrepancies vs IMPLEMENTATION_PLAN.md

| Item | Plan Says | Actual | Impact |
|------|-----------|--------|--------|
| Gallery endpoint count | 2 (index + show) | 1 (index only) | 1 fewer endpoint to port |
| Total endpoint count | 26 | 26 unique route patterns (40 controller actions) | Plan counts route patterns, not HTTP methods |
| EventServiceProvider | Should exist | Doesn't exist (Laravel 11+) | Nothing to port |
| Scheduled tasks | Should be documented | None exist | Nothing to port |
| Password min length | Not mentioned | Inconsistent: 8 (register) vs 6 (reset) | Standardize in Rust |

---

## 10. Recommendations for Implementation

### 10.1 Migration Strategy (improved)

**Instead of porting 30 individual Laravel migrations**, squash them into a single `0001_initial_schema.sql` for the Rust project. The intermediate migration states are irrelevant for a fresh deployment. Keep only the final schema. This saves ~29 migration files and reduces complexity.

### 10.2 Endpoint Count Clarification

The 26 unique route patterns map to 36 HTTP method combinations (PUT+PATCH counted separately). In Axum, each handler maps to one function, so the Rust port needs ~26 handler functions (PUT and PATCH share the same handler).

### 10.3 Cache Key Compatibility

The LLM adapter uses SHA-256 of canonical JSON for cache keys. The Rust port must implement byte-identical canonical JSON serialization:
- Keys sorted alphabetically
- No whitespace separators (`,:`)
- `ensure_ascii=false` (Unicode preserved)

### 10.4 Sanctum Token Compatibility

The token hash is `sha256(plain_token)`. The Rust port must use the exact same algorithm. Test with existing tokens from the database.

### 10.5 Error Response Format

All errors follow this exact structure:
```json
{
  "success": false,
  "message": "string",
  "error": {"code": "string", "message": "string", "retryable": "bool"},
  "errors": {"field": ["validation error messages"]},
  "timestamp": "ISO8601"
}
```

The `error` key uses `MediaGenerationErrorCode::toClientPayload()`. The Rust port must replicate this exactly.
