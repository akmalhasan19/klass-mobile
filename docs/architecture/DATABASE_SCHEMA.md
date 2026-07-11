# Database Schema Design: Klass Rust Gateway

> **Phase**: Fase 2 Design (Task 2.4)
> **Date**: 2026-07-11
> **Based on**: 30 Laravel migrations + 2 LLM Adapter SQL migrations
> **Target DB**: Neon PostgreSQL 17 via sqlx + PgBouncer

---

## Table of Contents

1. [Migration Inventory](#migration-inventory)
2. [Consolidated DDL — Application Tables](#consolidated-ddl--application-tables)
3. [New Tables — LLM Adapter Consolidation](#new-tables--llm-adapter-consolidation)
4. [Schema Change Notes (Laravel → PostgreSQL)](#schema-change-notes-laravel--postgresql)
5. [Rust Struct Definitions](#rust-struct-definitions)
6. [LLM Adapter Python → Rust Struct Mapping](#llm-adapter-python--rust-struct-mapping)
7. [Data Migration Strategy (Fase 6)](#data-migration-strategy-fase-6)
8. [Index Strategy](#index-strategy)

---

## Migration Inventory

### Laravel Migration → sqlx Status

| # | Laravel Migration | Table(s) Created/Modified | Status |
|---|------------------|--------------------------|--------|
| 1 | `0001_01_01_000000_create_users_table` | `users`, `password_reset_tokens`, `sessions` | **users**: Port | **password_reset_tokens, sessions**: Skip |
| 2 | `0001_01_01_000001_create_cache_table` | `cache`, `cache_locks` | **Skip** (Redis) |
| 3 | `0001_01_01_000002_create_jobs_table` | `jobs`, `job_batches`, `failed_jobs` | **Skip** (Redis Streams) |
| 4 | `2024_01_01_000010_create_topics_table` | `topics` | **Port** |
| 5 | `2024_01_01_000020_create_contents_table` | `contents` | **Port** |
| 6 | `2024_01_01_000030_create_marketplace_tasks_table` | `marketplace_tasks` | **Port** |
| 7 | `2024_01_01_000040_create_student_progress_table` | `student_progress` | **Port** |
| 8 | `2026_03_24_224308_create_personal_access_tokens_table` | `personal_access_tokens` | **Port** (Sanctum) |
| 9 | `2026_03_30_000001_add_media_fields_to_tables` | Alter: users, topics, contents, marketplace_tasks | **Consolidate into base DDL** |
| 10 | `2026_04_01_000001_add_role_to_users_table` | Alter: users | **Consolidate into base DDL** |
| 11 | `2026_04_01_045541_create_activity_logs_table` | `activity_logs` | **Port** |
| 12 | `2026_04_01_045542_create_homepage_sections_table` | `homepage_sections` | **Port** |
| 13 | `2026_04_01_045544_create_media_files_table` | `media_files` | **Port** |
| 14 | `2026_04_01_045545_add_admin_monitoring_fields_to_entities` | Alter: topics, contents | **Consolidate into base DDL** |
| 15 | `2026_04_01_121211_add_security_questions_to_users_table` | Alter: users | **Consolidate into base DDL** |
| 16 | `2026_04_03_085441_create_system_settings_table` | `system_settings` | **Port** |
| 17 | `2026_04_03_140000_create_recommended_projects_table` | `recommended_projects` | **Port** |
| 18 | `2026_04_04_015344_add_project_file_url_to_recommended_projects_table` | Alter: recommended_projects | **Consolidate into base DDL** |
| 19 | `2026_04_07_000001_create_subjects_and_sub_subjects_tables` | `subjects`, `sub_subjects` | **Port** |
| 20 | `2026_04_07_000002_add_normalized_owner_fields_to_topics_table` | Alter: topics | **Consolidate into base DDL** |
| 21 | `2026_04_07_000003_add_sub_subject_id_to_topics_table` | Alter: topics | **Consolidate into base DDL** |
| 22 | `2026_04_07_000004_add_primary_subject_id_to_users_table` | Alter: users | **Consolidate into base DDL** |
| 23 | `2026_04_07_000005_create_system_recommendation_assignments_table` | `system_recommendation_assignments` | **Port** |
| 24 | `2026_04_07_000006_create_media_generations_table` | `media_generations` | **Port** |
| 25 | `2026_04_07_000007_add_orchestration_payloads_to_media_generations_table` | Alter: media_generations | **Consolidate into base DDL** |
| 26 | `2026_04_07_000008_add_orchestration_audit_payload_to_media_generations_table` | Alter: media_generations | **Consolidate into base DDL** |
| 27 | `2026_04_11_140000_widen_media_publication_url_columns` | Alter: topics, contents, recommended_projects | **Consolidate into base DDL** (already TEXT) |
| 28 | `2026_04_14_100000_add_parent_generation_to_media_generations` | Alter: media_generations | **Consolidate into base DDL** |
| 29 | `2026_04_14_100001_optimize_marketplace_tasks_for_refinement` | Alter: marketplace_tasks | **Consolidate into base DDL** |
| 30 | `2026_04_14_100002_create_freelancer_matches_table` | `freelancer_matches` | **Port** |

### Final Migration Files for sqlx

| # | sqlx Migration | Type | Table(s) |
|---|---------------|------|----------|
| 1 | `0000000001_users` | CREATE | `users` |
| 2 | `0000000002_personal_access_tokens` | CREATE | `personal_access_tokens` |
| 3 | `0000000003_subjects_and_sub_subjects` | CREATE | `subjects`, `sub_subjects` |
| 4 | `0000000004_topics` | CREATE | `topics` |
| 5 | `0000000005_contents` | CREATE | `contents` |
| 6 | `0000000006_marketplace_tasks` | CREATE | `marketplace_tasks` |
| 7 | `0000000007_student_progress` | CREATE | `student_progress` |
| 8 | `0000000008_media_generations` | CREATE | `media_generations` |
| 9 | `0000000009_media_files` | CREATE | `media_files` |
| 10 | `0000000010_recommended_projects` | CREATE | `recommended_projects` |
| 11 | `0000000011_activity_logs` | CREATE | `activity_logs` |
| 12 | `0000000012_homepage_sections` | CREATE | `homepage_sections` |
| 13 | `0000000013_system_settings` | CREATE | `system_settings` |
| 14 | `0000000014_system_recommendation_assignments` | CREATE | `system_recommendation_assignments` |
| 15 | `0000000015_freelancer_matches` | CREATE | `freelancer_matches` |
| 16 | `0000000100_llm_cache_entries` | CREATE (new) | `llm_cache_entries` |
| 17 | `0000000101_llm_rate_limit_policies` | CREATE (new) | `llm_rate_limit_policies` |
| 18 | `0000000102_llm_rate_limit_buckets` | CREATE (new) | `llm_rate_limit_buckets` |
| 19 | `0000000103_llm_request_ledger` | CREATE (new) | `llm_request_ledger` |
| 20 | `0000000104_llm_price_catalog` | CREATE (new) | `llm_price_catalog` |

**Total: 20 sqlx migration files** (15 Laravel parity + 5 new)

> **Design decision**: Instead of 30 incremental migration files (many of which are `ALTER TABLE` add-column), we consolidate into 20 CREATE TABLE files. The final schema is identical. This reduces migration execution time and eliminates risk of ordering errors with `sqlx migrate run`.

---

## Consolidated DDL — Application Tables

### 1. `users`

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    email_verified_at TIMESTAMPTZ NULL,
    password VARCHAR(255) NOT NULL,
    avatar_url TEXT NULL,
    primary_subject_id BIGINT NULL REFERENCES subjects (id) ON DELETE SET NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'teacher',
    remember_token VARCHAR(100) NULL,
    security_question VARCHAR(255) NULL,
    security_answer VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_primary_subject_id ON users (primary_subject_id);

-- Replaces Laravel's sessions, password_reset_tokens tables
-- Authentication is stateless via Sanctum token (personal_access_tokens)
```

### 2. `personal_access_tokens`

```sql
CREATE TABLE personal_access_tokens (
    id BIGSERIAL PRIMARY KEY,
    tokenable_type VARCHAR(255) NOT NULL,
    tokenable_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    token VARCHAR(64) NOT NULL,
    abilities TEXT NULL,
    last_used_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_personal_access_tokens_token ON personal_access_tokens (token);
CREATE INDEX idx_personal_access_tokens_tokenable ON personal_access_tokens (tokenable_type, tokenable_id);
CREATE INDEX idx_personal_access_tokens_expires_at ON personal_access_tokens (expires_at);

-- Sanctum token format:
-- Store: hash('sha256', plain_text_token)
-- Verify: SELECT * FROM personal_access_tokens WHERE token = hash('sha256', $plain)
-- This is byte-compatible with Laravel's hash driver
```

### 3. `subjects`

```sql
CREATE TABLE subjects (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_subjects_slug ON subjects (slug);
CREATE INDEX idx_subjects_active_order ON subjects (is_active, display_order);
```

### 4. `sub_subjects`

```sql
CREATE TABLE sub_subjects (
    id BIGSERIAL PRIMARY KEY,
    subject_id BIGINT NOT NULL REFERENCES subjects (id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_sub_subjects_subject_slug ON sub_subjects (subject_id, slug);
CREATE INDEX idx_sub_subjects_active_order ON sub_subjects (subject_id, is_active, display_order);
```

### 5. `topics`

```sql
CREATE TABLE topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    teacher_id VARCHAR(255) NOT NULL,
    sub_subject_id BIGINT NULL REFERENCES sub_subjects (id) ON DELETE SET NULL,
    thumbnail_url TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    "order" INT NOT NULL DEFAULT 0,
    owner_user_id BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    ownership_status VARCHAR(50) NOT NULL DEFAULT 'legacy_unresolved',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_topics_order ON topics ("order");
CREATE INDEX idx_topics_sub_subject_id ON topics (sub_subject_id);
CREATE INDEX idx_topics_ownership_status ON topics (ownership_status);
```

### 6. `contents`

```sql
CREATE TABLE contents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES topics (id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('module', 'quiz', 'brief')),
    title VARCHAR(255) NULL,
    data JSONB NULL,
    media_url TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    "order" INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contents_order ON contents ("order");
CREATE INDEX idx_contents_topic_id ON contents (topic_id);

-- Laravel uses 'json' type → migrated to JSONB for better indexing and query performance
-- JSONB is backward-compatible for reads
```

### 7. `marketplace_tasks`

```sql
CREATE TABLE marketplace_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES contents (id) ON DELETE CASCADE,
    media_generation_id UUID NULL REFERENCES media_generations (id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'taken', 'done')),
    task_type VARCHAR(20) NOT NULL DEFAULT 'bid',
    description TEXT NULL,
    creator_id VARCHAR(255) NULL,
    suggested_freelancer_id BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    attachment_url VARCHAR(2048) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_marketplace_tasks_task_type ON marketplace_tasks (task_type);
CREATE INDEX idx_marketplace_tasks_media_generation_id ON marketplace_tasks (media_generation_id);
CREATE INDEX idx_marketplace_tasks_suggested_freelancer ON marketplace_tasks (suggested_freelancer_id);
```

### 8. `student_progress`

```sql
CREATE TABLE student_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name VARCHAR(255) NOT NULL,
    score INT NULL,
    completion_date TIMESTAMPTZ NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 9. `media_generations`

```sql
CREATE TABLE media_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Parent chain tracking (RF-05)
    generated_from_id UUID NULL REFERENCES media_generations (id) ON DELETE SET NULL,
    is_regeneration BOOLEAN NOT NULL DEFAULT FALSE,
    -- Ownership
    teacher_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    -- Taxonomy
    subject_id BIGINT NULL REFERENCES subjects (id) ON DELETE SET NULL,
    sub_subject_id BIGINT NULL REFERENCES sub_subjects (id) ON DELETE SET NULL,
    -- Publication references (set after publish)
    topic_id UUID NULL REFERENCES topics (id) ON DELETE SET NULL,
    content_id UUID NULL REFERENCES contents (id) ON DELETE SET NULL,
    recommended_project_id BIGINT NULL REFERENCES recommended_projects (id) ON DELETE SET NULL,
    -- Input
    raw_prompt TEXT NOT NULL,
    request_fingerprint VARCHAR(64) NOT NULL,
    active_duplicate_key VARCHAR(64) NULL,
    -- Output type
    preferred_output_type VARCHAR(10) NOT NULL DEFAULT 'auto',
    resolved_output_type VARCHAR(10) NULL,
    -- State machine
    status VARCHAR(20) NOT NULL DEFAULT 'queued',
    -- Provider metadata
    llm_provider VARCHAR(100) NULL,
    llm_model VARCHAR(200) NULL,
    generator_provider VARCHAR(100) NULL,
    generator_model VARCHAR(200) NULL,
    -- JSONB payloads (migrated from 'json' to JSONB)
    interpretation_payload JSONB NULL,
    interpretation_audit_payload JSONB NULL,
    generation_spec_payload JSONB NULL,
    decision_payload JSONB NULL,
    orchestration_audit_payload JSONB NULL,
    delivery_payload JSONB NULL,
    generator_service_response JSONB NULL,
    -- Artifact
    storage_path VARCHAR(1024) NULL,
    file_url TEXT NULL,
    thumbnail_url TEXT NULL,
    mime_type VARCHAR(255) NULL,
    -- Error state
    error_code VARCHAR(100) NULL,
    error_message TEXT NULL,
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hot indexes
CREATE INDEX idx_media_generations_teacher_created ON media_generations (teacher_id, created_at);
CREATE INDEX idx_media_generations_status_created ON media_generations (status, created_at);
CREATE INDEX idx_media_generations_teacher_fingerprint ON media_generations (teacher_id, request_fingerprint);
CREATE UNIQUE INDEX idx_media_generations_duplicate_key ON media_generations (active_duplicate_key) WHERE active_duplicate_key IS NOT NULL;
CREATE INDEX idx_media_generations_generated_from ON media_generations (generated_from_id);
```

### 10. `media_files`

```sql
CREATE TABLE media_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    file_path VARCHAR(1024) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(255) NULL,
    size INT NULL,
    disk VARCHAR(50) NOT NULL DEFAULT 'r2',
    category VARCHAR(50) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 11. `recommended_projects`

```sql
CREATE TABLE recommended_projects (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    thumbnail_url TEXT NULL,
    project_file_url TEXT NULL,
    ratio VARCHAR(10) NOT NULL DEFAULT '16:9',
    project_type VARCHAR(100) NULL,
    tags JSONB NULL,
    modules JSONB NULL,
    source_type VARCHAR(100) NULL,
    source_reference VARCHAR(255) NULL,
    source_payload JSONB NULL,
    display_priority INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at TIMESTAMPTZ NULL,
    ends_at TIMESTAMPTZ NULL,
    created_by BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    updated_by BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recommended_projects_source_type ON recommended_projects (source_type);
CREATE INDEX idx_recommended_projects_source_ref ON recommended_projects (source_type, source_reference);
CREATE INDEX idx_recommended_projects_display_priority ON recommended_projects (display_priority);
CREATE INDEX idx_recommended_projects_is_active ON recommended_projects (is_active);
CREATE INDEX idx_recommended_projects_starts_at ON recommended_projects (starts_at);
CREATE INDEX idx_recommended_projects_ends_at ON recommended_projects (ends_at);
```

### 12. `activity_logs`

```sql
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id BIGINT NULL REFERENCES users (id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    subject_type VARCHAR(255) NULL,
    subject_id BIGINT NULL,
    metadata JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activity_logs_subject ON activity_logs (subject_type, subject_id);
```

### 13. `homepage_sections`

```sql
CREATE TABLE homepage_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(255) NOT NULL,
    label VARCHAR(255) NOT NULL,
    position INT NOT NULL DEFAULT 0,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    data_source VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_homepage_sections_key ON homepage_sections (key);
```

### 14. `system_settings`

```sql
CREATE TABLE system_settings (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(255) NOT NULL,
    value TEXT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'boolean', 'number', 'json')),
    "group" VARCHAR(50) NOT NULL DEFAULT 'general',
    description VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_system_settings_key ON system_settings (key);
```

### 15. `system_recommendation_assignments`

```sql
CREATE TABLE system_recommendation_assignments (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recommendation_key VARCHAR(255) NOT NULL,
    recommendation_item_id VARCHAR(255) NOT NULL,
    source_type VARCHAR(255) NOT NULL,
    source_reference VARCHAR(255) NOT NULL,
    subject_id BIGINT NULL REFERENCES subjects (id) ON DELETE SET NULL,
    sub_subject_id BIGINT NULL REFERENCES sub_subjects (id) ON DELETE SET NULL,
    first_distributed_at TIMESTAMPTZ NOT NULL,
    last_distributed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_sra_user_recommendation ON system_recommendation_assignments (user_id, recommendation_key);
CREATE INDEX idx_sra_source ON system_recommendation_assignments (source_type, source_reference);
CREATE INDEX idx_sra_sub_subject ON system_recommendation_assignments (sub_subject_id, recommendation_key);
CREATE INDEX idx_sra_subject_id ON system_recommendation_assignments (subject_id);
CREATE INDEX idx_sra_last_distributed_at ON system_recommendation_assignments (last_distributed_at);
```

### 16. `freelancer_matches`

```sql
CREATE TABLE freelancer_matches (
    id BIGSERIAL PRIMARY KEY,
    media_generation_id UUID NOT NULL REFERENCES media_generations (id) ON DELETE CASCADE,
    freelancer_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    match_score FLOAT NOT NULL DEFAULT 0,
    portfolio_relevance_score FLOAT NOT NULL DEFAULT 0,
    success_rate FLOAT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_freelancer_matches_gen_freelancer ON freelancer_matches (media_generation_id, freelancer_id);
CREATE INDEX idx_freelancer_matches_media_gen ON freelancer_matches (media_generation_id);
CREATE INDEX idx_freelancer_matches_freelancer ON freelancer_matches (freelancer_id);
CREATE INDEX idx_freelancer_matches_score ON freelancer_matches (match_score);
```

---

## New Tables — LLM Adapter Consolidation

### 17. `llm_cache_entries`

Konsolidasi `interpretation_cache_entries` + `delivery_cache_entries` ke satu tabel.

```sql
CREATE TABLE llm_cache_entries (
    id BIGSERIAL PRIMARY KEY,
    cache_key CHAR(64) NOT NULL,
    route VARCHAR(16) NOT NULL CHECK (route IN ('interpret', 'respond')),
    request_payload JSONB NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count BIGINT NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ NULL,
    CHECK (hit_count >= 0)
);

-- Unique constraint: one entry per cache key (global, not per route)
CREATE UNIQUE INDEX idx_llm_cache_entries_cache_key ON llm_cache_entries (cache_key);

-- Partial indexes per route for efficient lookup and cleanup
CREATE INDEX idx_llm_cache_entries_lookup ON llm_cache_entries (cache_key, expires_at);

CREATE INDEX idx_llm_cache_entries_expires_interpret
    ON llm_cache_entries (expires_at) WHERE route = 'interpret';

CREATE INDEX idx_llm_cache_entries_expires_respond
    ON llm_cache_entries (expires_at) WHERE route = 'respond';

-- For analytics: cache hit ratio per route
CREATE INDEX idx_llm_cache_entries_route_created
    ON llm_cache_entries (route, created_at);
```

### 18. `llm_rate_limit_policies`

Pre-seeded dengan default policies dari `build_default_governance_policies()`.

```sql
CREATE TABLE llm_rate_limit_policies (
    id BIGSERIAL PRIMARY KEY,
    scope_type VARCHAR(32) NOT NULL CHECK (scope_type IN ('global', 'provider', 'model', 'route')),
    strategy VARCHAR(32) NOT NULL DEFAULT 'fixed_window' CHECK (strategy IN ('fixed_window')),
    route VARCHAR(32) NOT NULL DEFAULT 'all' CHECK (route IN ('all', 'interpret', 'respond')),
    provider VARCHAR(100) NOT NULL DEFAULT '*',
    model VARCHAR(200) NOT NULL DEFAULT '*',
    window_unit VARCHAR(16) NOT NULL CHECK (window_unit IN ('minute', 'hour', 'day')),
    max_requests BIGINT NULL CHECK (max_requests IS NULL OR max_requests >= 0),
    max_input_tokens BIGINT NULL CHECK (max_input_tokens IS NULL OR max_input_tokens >= 0),
    max_output_tokens BIGINT NULL CHECK (max_output_tokens IS NULL OR max_output_tokens >= 0),
    max_total_tokens BIGINT NULL CHECK (max_total_tokens IS NULL OR max_total_tokens >= 0),
    max_estimated_cost_usd NUMERIC(20, 8) NULL CHECK (max_estimated_cost_usd IS NULL OR max_estimated_cost_usd >= 0),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- At least one ceiling required
    CHECK (
        max_requests IS NOT NULL
        OR max_input_tokens IS NOT NULL
        OR max_output_tokens IS NOT NULL
        OR max_total_tokens IS NOT NULL
        OR max_estimated_cost_usd IS NOT NULL
    ),
    -- Scope-type enforcement
    CHECK ((scope_type <> 'global')   OR (route = 'all' AND provider = '*' AND model = '*')),
    CHECK ((scope_type <> 'route')    OR (route <> 'all' AND provider = '*' AND model = '*')),
    CHECK ((scope_type <> 'provider') OR (provider <> '*' AND model = '*')),
    CHECK ((scope_type <> 'model')    OR model <> '*')
);

CREATE UNIQUE INDEX idx_llm_rate_limit_policies_scope
    ON llm_rate_limit_policies (scope_type, route, provider, model, window_unit);

CREATE INDEX idx_llm_rate_limit_policies_lookup
    ON llm_rate_limit_policies (enabled, route, provider, model, window_unit);
```

### 19. `llm_rate_limit_buckets`

Fixed-window rate limit tracking. One row per policy per window.

```sql
CREATE TABLE llm_rate_limit_buckets (
    id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES llm_rate_limit_policies (id) ON DELETE CASCADE,
    scope_type VARCHAR(32) NOT NULL CHECK (scope_type IN ('global', 'provider', 'model', 'route')),
    strategy VARCHAR(32) NOT NULL DEFAULT 'fixed_window' CHECK (strategy IN ('fixed_window')),
    route VARCHAR(32) NOT NULL CHECK (route IN ('all', 'interpret', 'respond')),
    provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    window_unit VARCHAR(16) NOT NULL CHECK (window_unit IN ('minute', 'hour', 'day')),
    window_started_at TIMESTAMPTZ NOT NULL,
    window_ends_at TIMESTAMPTZ NOT NULL,
    request_count BIGINT NOT NULL DEFAULT 0 CHECK (request_count >= 0),
    input_tokens BIGINT NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
    output_tokens BIGINT NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
    total_tokens BIGINT NOT NULL DEFAULT 0 CHECK (total_tokens >= 0),
    estimated_cost_usd NUMERIC(20, 8) NOT NULL DEFAULT 0 CHECK (estimated_cost_usd >= 0),
    deny_count BIGINT NOT NULL DEFAULT 0 CHECK (deny_count >= 0),
    last_request_id VARCHAR(255) NULL,
    last_generation_id VARCHAR(100) NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (window_ends_at > window_started_at)
);

CREATE UNIQUE INDEX idx_llm_rate_limit_buckets_policy_window
    ON llm_rate_limit_buckets (policy_id, window_started_at);

CREATE INDEX idx_llm_rate_limit_buckets_lookup
    ON llm_rate_limit_buckets (route, provider, model, window_unit, window_started_at DESC);

CREATE INDEX idx_llm_rate_limit_buckets_window_ends
    ON llm_rate_limit_buckets (window_ends_at);
```

### 20. `llm_request_ledger`

Audit trail untuk setiap LLM API call. **Non-kritis** — bisa diganti dengan structured logging jika volume tinggi.

```sql
CREATE TABLE llm_request_ledger (
    id BIGSERIAL PRIMARY KEY,
    request_id VARCHAR(255) NOT NULL,
    generation_id VARCHAR(100) NOT NULL,
    route VARCHAR(32) NOT NULL CHECK (route IN ('interpret', 'respond')),
    request_type VARCHAR(100) NOT NULL,
    provider VARCHAR(100) NOT NULL,
    primary_provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    requested_model VARCHAR(200) NOT NULL,
    latency_ms NUMERIC(12, 2) NULL,
    retry_count INT NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
    cache_status VARCHAR(16) NOT NULL CHECK (cache_status IN ('hit', 'miss', 'bypass')),
    final_status VARCHAR(32) NOT NULL,
    error_class VARCHAR(255) NULL,
    error_code VARCHAR(100) NULL,
    fallback_used BOOLEAN NOT NULL DEFAULT FALSE,
    fallback_reason VARCHAR(100) NULL,
    attempted_providers JSONB NOT NULL DEFAULT '[]'::jsonb,
    upstream_request_id VARCHAR(255) NULL,
    provider_response_id VARCHAR(255) NULL,
    provider_model_version VARCHAR(200) NULL,
    finish_reason VARCHAR(100) NULL,
    candidate_index INT NULL,
    input_tokens BIGINT NULL CHECK (input_tokens IS NULL OR input_tokens >= 0),
    output_tokens BIGINT NULL CHECK (output_tokens IS NULL OR output_tokens >= 0),
    total_tokens BIGINT NULL CHECK (total_tokens IS NULL OR total_tokens >= 0),
    estimated_cost_usd NUMERIC(20, 8) NULL CHECK (estimated_cost_usd IS NULL OR estimated_cost_usd >= 0),
    cache_key CHAR(64) NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ NULL,
    CHECK (jsonb_typeof(attempted_providers) = 'array'),
    CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX idx_llm_request_ledger_request_id ON llm_request_ledger (request_id);
CREATE INDEX idx_llm_request_ledger_created_at ON llm_request_ledger (created_at DESC);
CREATE INDEX idx_llm_request_ledger_route_created ON llm_request_ledger (route, created_at DESC);
CREATE INDEX idx_llm_request_ledger_provider_model ON llm_request_ledger (provider, model, created_at DESC);
CREATE INDEX idx_llm_request_ledger_generation_id ON llm_request_ledger (generation_id);
```

### 21. `llm_price_catalog`

Simplifikasi dari `price_catalog_entries` — deduplikasi by provider+model.

```sql
CREATE TABLE llm_price_catalog (
    id BIGSERIAL PRIMARY KEY,
    provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    input_cost_per_unit_usd NUMERIC(20, 8) NULL CHECK (input_cost_per_unit_usd IS NULL OR input_cost_per_unit_usd >= 0),
    output_cost_per_unit_usd NUMERIC(20, 8) NULL CHECK (output_cost_per_unit_usd IS NULL OR output_cost_per_unit_usd >= 0),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (input_cost_per_unit_usd IS NOT NULL OR output_cost_per_unit_usd IS NOT NULL)
);

CREATE UNIQUE INDEX idx_llm_price_catalog_effective
    ON llm_price_catalog (provider, model, effective_from);

CREATE INDEX idx_llm_price_catalog_lookup
    ON llm_price_catalog (provider, model, is_active, effective_from DESC);
```

---

## Schema Change Notes (Laravel → PostgreSQL)

### JSON → JSONB

| Laravel Table | Column(s) | Change |
|---------------|-----------|--------|
| `media_generations` | `interpretation_payload`, `interpretation_audit_payload`, `generation_spec_payload`, `decision_payload`, `orchestration_audit_payload`, `delivery_payload`, `generator_service_response` | `json` → `jsonb` |
| `activity_logs` | `metadata` | `json` → `jsonb` |
| `contents` | `data` | `json` → `jsonb` |
| `recommended_projects` | `tags`, `modules`, `source_payload` | `json` → `jsonb` |

**Rationale**: JSONB supports indexing, is more efficient for querying, and is backward-compatible for reads. If the existing Neon DB already has these as `json` type, run `ALTER COLUMN ... SET DATA TYPE jsonb` during initial migration.

### ENUM → VARCHAR + CHECK

Laravel uses MySQL-style ENUM. PostgreSQL-native handling:

| Table | Column | Laravel ENUM | PostgreSQL |
|-------|--------|-------------|-----------|
| `contents` | `type` | `enum('module','quiz','brief')` | `VARCHAR(20) CHECK (type IN (...))` |
| `marketplace_tasks` | `status` | `enum('open','taken','done')` | `VARCHAR(20) CHECK (status IN (...))` |

### TEXT columns for URLs

Laravel widened `string` → `text` in migration `2026_04_11_140000`. We use `TEXT` directly in the consolidated DDL. Affected columns: `topics.thumbnail_url`, `contents.media_url`, `recommended_projects.thumbnail_url`, `recommended_projects.project_file_url`, `media_generations.file_url`, `media_generations.thumbnail_url`.

### Timestamps: `timestamp` → `TIMESTAMPTZ`

All Laravel `timestamp` columns become `TIMESTAMPTZ` for proper timezone handling. This is backward-compatible — existing UTC values are interpreted correctly.

---

## Rust Struct Definitions

### 15 Eloquent Models → Rust Structs

```rust
// =========================================================================
// src/db/models.rs — Rust structs mirroring Eloquent models
// All derive: sqlx::FromRow, serde::Serialize (for JSON response), Clone, Debug
// =========================================================================

use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;
use sqlx::FromRow;

// --- User (maps to 'users' table) ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct User {
    pub id: i64,
    pub name: String,
    pub email: String,
    pub email_verified_at: Option<DateTime<Utc>>,
    pub password: String,             // Argon2 hash — never serialized in API responses
    pub avatar_url: Option<String>,
    pub primary_subject_id: Option<i64>,
    pub role: String,
    pub remember_token: Option<String>,
    pub security_question: Option<String>,
    pub security_answer: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- Subject ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct Subject {
    pub id: i64,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub display_order: i32,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- SubSubject ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct SubSubject {
    pub id: i64,
    pub subject_id: i64,
    pub name: String,
    pub slug: String,
    pub description: Option<String>,
    pub display_order: i32,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- Topic ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct Topic {
    pub id: Uuid,
    pub title: String,
    pub teacher_id: String,
    pub sub_subject_id: Option<i64>,
    pub thumbnail_url: Option<String>,
    pub is_published: bool,
    pub order: i32,                   // Escaped with #[sqlx(rename = "order")] if needed
    pub owner_user_id: Option<i64>,
    pub ownership_status: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- Content ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct Content {
    pub id: Uuid,
    pub topic_id: Uuid,
    pub r#type: String,               // 'module' | 'quiz' | 'brief'
    pub title: Option<String>,
    pub data: Option<serde_json::Value>,
    pub media_url: Option<String>,
    pub is_published: bool,
    pub order: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- MarketplaceTask ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct MarketplaceTask {
    pub id: Uuid,
    pub content_id: Uuid,
    pub media_generation_id: Option<Uuid>,
    pub status: String,
    pub task_type: String,
    pub description: Option<String>,
    pub creator_id: Option<String>,
    pub suggested_freelancer_id: Option<i64>,
    pub attachment_url: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- StudentProgress ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct StudentProgress {
    pub id: Uuid,
    pub student_name: String,
    pub score: Option<i32>,
    pub completion_date: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- MediaGeneration ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct MediaGeneration {
    pub id: Uuid,
    pub generated_from_id: Option<Uuid>,
    pub is_regeneration: bool,
    pub teacher_id: i64,
    pub subject_id: Option<i64>,
    pub sub_subject_id: Option<i64>,
    pub topic_id: Option<Uuid>,
    pub content_id: Option<Uuid>,
    pub recommended_project_id: Option<i64>,
    pub raw_prompt: String,
    pub request_fingerprint: String,
    pub active_duplicate_key: Option<String>,
    pub preferred_output_type: String,
    pub resolved_output_type: Option<String>,
    pub status: String,
    pub llm_provider: Option<String>,
    pub llm_model: Option<String>,
    pub generator_provider: Option<String>,
    pub generator_model: Option<String>,
    pub interpretation_payload: Option<serde_json::Value>,
    pub interpretation_audit_payload: Option<serde_json::Value>,
    pub generation_spec_payload: Option<serde_json::Value>,
    pub decision_payload: Option<serde_json::Value>,
    pub orchestration_audit_payload: Option<serde_json::Value>,
    pub delivery_payload: Option<serde_json::Value>,
    pub generator_service_response: Option<serde_json::Value>,
    pub storage_path: Option<String>,
    pub file_url: Option<String>,
    pub thumbnail_url: Option<String>,
    pub mime_type: Option<String>,
    pub error_code: Option<String>,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- MediaFile ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct MediaFile {
    pub id: Uuid,
    pub uploader_id: Option<i64>,
    pub file_path: String,
    pub file_name: String,
    pub mime_type: Option<String>,
    pub size: Option<i32>,
    pub disk: String,
    pub category: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- RecommendedProject ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct RecommendedProject {
    pub id: i64,
    pub title: String,
    pub description: Option<String>,
    pub thumbnail_url: Option<String>,
    pub project_file_url: Option<String>,
    pub ratio: String,
    pub project_type: Option<String>,
    pub tags: Option<serde_json::Value>,
    pub modules: Option<serde_json::Value>,
    pub source_type: Option<String>,
    pub source_reference: Option<String>,
    pub source_payload: Option<serde_json::Value>,
    pub display_priority: i32,
    pub is_active: bool,
    pub starts_at: Option<DateTime<Utc>>,
    pub ends_at: Option<DateTime<Utc>>,
    pub created_by: Option<i64>,
    pub updated_by: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- HomepageSection ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct HomepageSection {
    pub id: Uuid,
    pub key: String,
    pub label: String,
    pub position: i32,
    pub is_enabled: bool,
    pub data_source: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- SystemSetting ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct SystemSetting {
    pub id: i64,
    pub key: String,
    pub value: Option<String>,
    pub r#type: String,
    pub group: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- SystemRecommendationAssignment ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct SystemRecommendationAssignment {
    pub id: i64,
    pub user_id: i64,
    pub recommendation_key: String,
    pub recommendation_item_id: String,
    pub source_type: String,
    pub source_reference: String,
    pub subject_id: Option<i64>,
    pub sub_subject_id: Option<i64>,
    pub first_distributed_at: DateTime<Utc>,
    pub last_distributed_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- FreelancerMatch ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct FreelancerMatch {
    pub id: i64,
    pub media_generation_id: Uuid,
    pub freelancer_id: i64,
    pub match_score: f64,
    pub portfolio_relevance_score: f64,
    pub success_rate: f64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- ActivityLog ---
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct ActivityLog {
    pub id: Uuid,
    pub actor_id: Option<i64>,
    pub action: String,
    pub subject_type: Option<String>,
    pub subject_id: Option<i64>,
    pub metadata: Option<serde_json::Value>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// --- PersonalAccessToken (Sanctum) ---
#[derive(Debug, Clone, FromRow)]
pub struct PersonalAccessToken {
    pub id: i64,
    pub tokenable_type: String,
    pub tokenable_id: i64,
    pub name: String,
    pub token: String,                 // SHA-256 hash of plain-text token
    pub abilities: Option<String>,
    pub last_used_at: Option<DateTime<Utc>>,
    pub expires_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

### Repository Pattern

```rust
// Trait definitions (one per entity)
#[async_trait]
pub trait UserRepo {
    async fn find_by_id(&self, id: i64) -> Result<Option<User>>;
    async fn find_by_email(&self, email: &str) -> Result<Option<User>>;
    async fn create(&self, user: NewUser) -> Result<User>;
    async fn update_avatar(&self, id: i64, avatar_url: &str) -> Result<()>;
}

#[async_trait]
pub trait MediaGenerationRepo {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<MediaGeneration>>;
    async fn find_by_teacher(&self, teacher_id: i64, parent_id: Option<Uuid>, limit: i64) -> Result<Vec<MediaGeneration>>;
    async fn create(&self, gen: NewMediaGeneration) -> Result<MediaGeneration>;
    async fn update_status(&self, id: Uuid, status: &str, payload: Option<serde_json::Value>) -> Result<()>;
    async fn find_by_duplicate_key(&self, key: &str) -> Result<Option<MediaGeneration>>;
}

// ... etc for all 15 entities
```

---

## LLM Adapter Python → Rust Struct Mapping

### Cache Structs

```python
# Python (source)
@dataclass(frozen=True)
class CacheEntry:
    cache_key: str
    request_payload: dict[str, Any]
    response_payload: dict[str, Any]
    created_at: datetime
    expires_at: datetime
    hit_count: int
    last_hit_at: datetime | None

@dataclass(frozen=True)
class CacheInFlightLock:
    route: CacheRoute
    cache_key: str
    lock_id: int
    acquired: bool
```

```rust
// Rust (target)
// Since we use single table llm_cache_entries with route discriminator

#[derive(Debug, Clone, FromRow, Serialize)]
pub struct LlmCacheEntry {
    pub id: i64,
    pub cache_key: String,
    pub route: String,                 // 'interpret' | 'respond'
    pub request_payload: serde_json::Value,
    pub response_payload: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub hit_count: i64,
    pub last_hit_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
pub struct CacheInFlightLock {
    pub route: String,
    pub cache_key: String,
    pub lock_id: i64,
    pub acquired: bool,
}
```

### Governance Structs

```python
# Python (source)
@dataclass(frozen=True)
class RateLimitPolicyRecord:
    scope_type: RateLimitScopeType
    window_unit: RateLimitWindowUnit
    max_requests: int | None
    max_estimated_cost_usd: Decimal | None
    route: str
    provider: str
    model: str

@dataclass(frozen=True)
class RateLimitBucketMutation:
    policy_id: int
    request_count: int
    input_tokens: int
    output_tokens: int
    total_tokens: int
    estimated_cost_usd: Decimal
```

```rust
// Rust (target)
#[derive(Debug, Clone, FromRow, Serialize)]
pub struct LlmRateLimitPolicy {
    pub id: i64,
    pub scope_type: String,
    pub strategy: String,
    pub route: String,
    pub provider: String,
    pub model: String,
    pub window_unit: String,
    pub max_requests: Option<i64>,
    pub max_input_tokens: Option<i64>,
    pub max_output_tokens: Option<i64>,
    pub max_total_tokens: Option<i64>,
    pub max_estimated_cost_usd: Option<Decimal>,
    pub enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
pub struct LlmRateLimitBucket {
    pub id: i64,
    pub policy_id: i64,
    pub window_started_at: DateTime<Utc>,
    pub window_ends_at: DateTime<Utc>,
    pub request_count: i64,
    pub input_tokens: i64,
    pub output_tokens: i64,
    pub total_tokens: i64,
    pub estimated_cost_usd: Decimal,
    pub deny_count: i64,
    pub last_request_id: Option<String>,
    pub last_generation_id: Option<String>,
    pub last_seen_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
pub struct LlmRequestLedgerEntry {
    pub id: i64,
    pub request_id: String,
    pub generation_id: String,
    pub route: String,
    pub request_type: String,
    pub provider: String,
    pub primary_provider: String,
    pub model: String,
    pub requested_model: String,
    pub latency_ms: Option<Decimal>,
    pub retry_count: i32,
    pub cache_status: String,
    pub final_status: String,
    pub error_class: Option<String>,
    pub error_code: Option<String>,
    pub fallback_used: bool,
    pub fallback_reason: Option<String>,
    pub attempted_providers: serde_json::Value,
    pub upstream_request_id: Option<String>,
    pub provider_response_id: Option<String>,
    pub provider_model_version: Option<String>,
    pub finish_reason: Option<String>,
    pub candidate_index: Option<i32>,
    pub input_tokens: Option<i64>,
    pub output_tokens: Option<i64>,
    pub total_tokens: Option<i64>,
    pub estimated_cost_usd: Option<Decimal>,
    pub cache_key: Option<String>,
    pub metadata: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, FromRow)]
pub struct LlmPriceCatalogEntry {
    pub id: i64,
    pub provider: String,
    pub model: String,
    pub input_cost_per_unit_usd: Option<Decimal>,
    pub output_cost_per_unit_usd: Option<Decimal>,
    pub effective_from: DateTime<Utc>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

---

## Data Migration Strategy (Fase 6)

### Principle: Zero-Downtime

Data user (`users`, `media_generations`, `topics`, dll) **tidak berpindah** — DB tetap sama (Neon). Yang dipindahkan hanya data dari LLM Adapter DB ke Neon.

### Pre-Cutover Steps

```
T-7 days: Verify schema parity
  - Run ALL sqlx migrations on Neon staging branch
  - Compare pg_dump --schema-only with production Neon
  - Assert no schema drift (column names, types, constraints)

T-3 days: Cache migration dry-run
  - Run migration script on staging
  - Verify count match: source (LLM Adapter DB) == target (Neon llm_cache_entries)
  - Spot-check 50 random cache keys — assert byte-identical

T-1 day: Full backup
  - pg_dump Neon production (PITR already active)
  - pg_dump LLM Adapter DB
```

### Cache Migration Script

```sql
-- Run on Neon DB (target), connected to LLM Adapter DB via dblink or manual dump/restore
-- Idempotent: ON CONFLICT DO NOTHING

INSERT INTO llm_cache_entries (
    cache_key, route, request_payload, response_payload,
    created_at, expires_at, hit_count, last_hit_at
)
SELECT
    cache_key,
    'interpret' AS route,
    request_payload,
    response_payload,
    created_at,
    expires_at,
    hit_count,
    last_hit_at
FROM interpretation_cache_entries
WHERE expires_at > NOW()
ON CONFLICT (cache_key) DO NOTHING;

INSERT INTO llm_cache_entries (
    cache_key, route, request_payload, response_payload,
    created_at, expires_at, hit_count, last_hit_at
)
SELECT
    cache_key,
    'respond' AS route,
    request_payload,
    response_payload,
    created_at,
    expires_at,
    hit_count,
    last_hit_at
FROM delivery_cache_entries
WHERE expires_at > NOW()
ON CONFLICT (cache_key) DO NOTHING;
```

### Rate-Limit Bucket Migration

```sql
-- Policies: idempotent via sync_default_policies() at startup
-- Buckets: only migrate active windows (window_ends_at > NOW())

INSERT INTO llm_rate_limit_buckets (
    policy_id, scope_type, strategy, route, provider, model,
    window_unit, window_started_at, window_ends_at,
    request_count, input_tokens, output_tokens, total_tokens,
    estimated_cost_usd, deny_count, last_request_id, last_generation_id,
    last_seen_at, created_at, updated_at
)
SELECT
    rb.policy_id, rb.scope_type, rb.strategy, rb.route, rb.provider, rb.model,
    rb.window_unit, rb.window_started_at, rb.window_ends_at,
    rb.request_count, rb.input_tokens, rb.output_tokens, rb.total_tokens,
    rb.estimated_cost_usd, rb.deny_count, rb.last_request_id, rb.last_generation_id,
    rb.last_seen_at, rb.created_at, rb.updated_at
FROM rate_limit_buckets rb
JOIN rate_limit_policies rp ON rb.policy_id = rp.id
WHERE rb.window_ends_at > NOW()
ON CONFLICT (policy_id, window_started_at) DO NOTHING;
```

### Verification Queries

```sql
-- Verify cache entry count
SELECT route, COUNT(*) FROM llm_cache_entries GROUP BY route;

-- Verify cache hit rate (sample 100 lookups)
SELECT COUNT(*) AS hits FROM llm_cache_entries
WHERE cache_key IN (SELECT cache_key FROM interpretation_cache_entries LIMIT 100);

-- Verify rate-limit buckets
SELECT COUNT(*) FROM llm_rate_limit_buckets WHERE window_ends_at > NOW();
```

### Rollback Plan

If cache hit ratio drops post-cutover:
1. Point Gateway `LLM_ADAPTER_DATABASE_URL` back to LLM Adapter DB
2. LLM Adapter service still running in read-only mode as fallback
3. Revert DNS → Laravel (Laravel still alive for 7 days)

---

## Index Strategy

### Hot Path Indexes (every request hits these)

| Table | Index | Query Pattern |
|-------|-------|-------------|
| `personal_access_tokens` | `idx_..._token` | `WHERE token = hash('sha256', $plain)` |
| `llm_cache_entries` | `idx_..._cache_key` | `WHERE cache_key = $1` |
| `llm_cache_entries` | `idx_..._lookup` | `WHERE cache_key = $1 AND expires_at > NOW()` |
| `llm_rate_limit_buckets` | `idx_..._policy_window` | `WHERE policy_id = $1 AND window_started_at = $2` (upsert) |
| `media_generations` | `idx_..._teacher_created` | `WHERE teacher_id = $1 ORDER BY created_at DESC` |
| `media_generations` | `idx_..._status_created` | `WHERE status = 'queued' ORDER BY created_at` |

### Partial Indexes (targeted, smaller)

| Table | Partial Index | Where Clause |
|-------|--------------|-------------|
| `llm_cache_entries` | `idx_..._expires_interpret` | `WHERE route = 'interpret'` |
| `llm_cache_entries` | `idx_..._expires_respond` | `WHERE route = 'respond'` |
| `media_generations` | `idx_..._duplicate_key` | `WHERE active_duplicate_key IS NOT NULL` |

### Maintenance

```sql
-- Run weekly during low-traffic window
-- Neon free tier: autovacuum handles this automatically
ANALYZE llm_cache_entries;
ANALYZE llm_rate_limit_buckets;
ANALYZE media_generations;
```

---

## sqlx Migration File Structure (Fase 3)

Directory layout for Rust gateway project:

```
gateway/
  migrations/
    0000000001_users.sql
    0000000002_personal_access_tokens.sql
    0000000003_subjects_and_sub_subjects.sql
    0000000004_topics.sql
    0000000005_contents.sql
    0000000006_marketplace_tasks.sql
    0000000007_student_progress.sql
    0000000008_media_generations.sql
    0000000009_media_files.sql
    0000000010_recommended_projects.sql
    0000000011_activity_logs.sql
    0000000012_homepage_sections.sql
    0000000013_system_settings.sql
    0000000014_system_recommendation_assignments.sql
    0000000015_freelancer_matches.sql
    0000000100_llm_cache_entries.sql
    0000000101_llm_rate_limit_policies.sql
    0000000102_llm_rate_limit_buckets.sql
    0000000103_llm_request_ledger.sql
    0000000104_llm_price_catalog.sql
```

Each file contains exactly the `CREATE TABLE ...` statement from the Consolidated DDL section above. No `ALTER TABLE` migrations needed since we use consolidated schemas.

> **CI note**: `cargo sqlx prepare --check` harus lulus dengan `SQLX_OFFLINE=true` untuk setiap perubahan query.

---

## References

- `backend/database/migrations/` — 30 Laravel migration files
- `llm-adapter-service/app/migrations/` — LLM Adapter SQL migrations (5 tables + 2 views)
- `IMPLEMENTATION_PLAN.md` — Task 1.2 (Data Audit), Task 2.4 (Schema Design)
- ADR-004 (`docs/adr/0004-database-strategy-neon-sqlx.md`) — Database strategy decision
- ADR-008 (`docs/adr/0008-cache-db-consolidation.md`) — Cache DB consolidation decision
