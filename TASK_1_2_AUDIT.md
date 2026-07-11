# Task 1.2: Data Audit — Complete Schema & Data Analysis

> **Audit Date**: 2026-07-11
> **Commit**: `0b794bc`
> **Source**: Laravel migrations (30 files) + Eloquent models (15) + LLM Adapter migrations (2)

---

## 1. Application DB Schema (Neon PostgreSQL)

### 1.1 Complete Table Inventory

#### `users` (created: 0001_01_01_000000, altered: 4 migrations)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `name` | VARCHAR(255) | NO | — | — |
| `email` | VARCHAR(255) | NO | — | UNIQUE |
| `email_verified_at` | TIMESTAMPTZ | YES | NULL | — |
| `password` | VARCHAR(255) | NO | — | — |
| `remember_token` | VARCHAR(100) | YES | NULL | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |
| `avatar_url` | VARCHAR(255) | YES | NULL | Added 2026_03_30 |
| `role` | VARCHAR(255) | NO | `'user'` | Added 2026_04_01 |
| `security_question` | VARCHAR(255) | YES | NULL | Added 2026_04_01 |
| `security_answer` | VARCHAR(255) | YES | NULL | Added 2026_04_01 |
| `primary_subject_id` | BIGINT | YES | NULL | FK→subjects.id, ON DELETE SET NULL, indexed |

#### `password_reset_tokens` (created: 0001_01_01_000000)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `email` | VARCHAR(255) | NO | — | PK |
| `token` | VARCHAR(255) | NO | — | — |
| `created_at` | TIMESTAMPTZ | YES | NULL | — |

#### `sessions` (created: 0001_01_01_000000)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | VARCHAR(255) | NO | — | PK |
| `user_id` | BIGINT | YES | NULL | indexed |
| `ip_address` | VARCHAR(45) | YES | NULL | — |
| `user_agent` | TEXT | YES | NULL | — |
| `payload` | LONGTEXT | NO | — | — |
| `last_activity` | INTEGER | NO | — | indexed |

#### `cache` (created: 0001_01_01_000001)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `key` | VARCHAR(255) | NO | — | PK |
| `value` | MEDIUMTEXT | NO | — | — |
| `expiration` | BIGINT | NO | — | indexed |

#### `cache_locks` (created: 0001_01_01_000001)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `key` | VARCHAR(255) | NO | — | PK |
| `owner` | VARCHAR(255) | NO | — | — |
| `expiration` | BIGINT | NO | — | indexed |

#### `jobs` (created: 0001_01_01_000002)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `queue` | VARCHAR(255) | NO | — | indexed |
| `payload` | LONGTEXT | NO | — | — |
| `attempts` | UNSIGNED TINYINT | NO | — | — |
| `reserved_at` | UNSIGNED INT | YES | NULL | — |
| `available_at` | UNSIGNED INT | NO | — | — |
| `created_at` | UNSIGNED INT | NO | — | — |

#### `job_batches` (created: 0001_01_01_000002)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | VARCHAR(255) | NO | — | PK |
| `name` | VARCHAR(255) | NO | — | — |
| `total_jobs` | INTEGER | NO | — | — |
| `pending_jobs` | INTEGER | NO | — | — |
| `failed_jobs` | INTEGER | NO | — | — |
| `failed_job_ids` | LONGTEXT | NO | — | — |
| `options` | MEDIUMTEXT | YES | NULL | — |
| `cancelled_at` | INTEGER | YES | NULL | — |
| `created_at` | INTEGER | NO | — | — |
| `finished_at` | INTEGER | YES | NULL | — |

#### `failed_jobs` (created: 0001_01_01_000002)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `uuid` | VARCHAR(255) | NO | — | UNIQUE |
| `connection` | TEXT | NO | — | — |
| `queue` | TEXT | NO | — | — |
| `payload` | LONGTEXT | NO | — | — |
| `exception` | LONGTEXT | NO | — | — |
| `failed_at` | TIMESTAMPTZ | NO | `CURRENT_TIMESTAMP` | — |

#### `topics` (created: 2024_01_01_000010, altered: 3 migrations)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `title` | VARCHAR(255) | NO | — | — |
| `teacher_id` | VARCHAR(255) | NO | — | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |
| `thumbnail_url` | TEXT | YES | NULL | Originally VARCHAR, widened 2026_04_11 |
| `is_published` | BOOLEAN | NO | `true` | Added 2026_04_01 |
| `order` | INTEGER | NO | `0` | Added 2026_04_01, indexed |
| `owner_user_id` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL, added 2026_04_07 |
| `ownership_status` | VARCHAR(255) | NO | `'legacy_unresolved'` | Added 2026_04_07, indexed |
| `sub_subject_id` | BIGINT | YES | NULL | FK→sub_subjects.id, ON DELETE SET NULL, indexed, added 2026_04_07 |

#### `contents` (created: 2024_01_01_000020, altered: 2 migrations)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `topic_id` | UUID | NO | — | FK→topics.id, ON DELETE CASCADE |
| `type` | ENUM('module','quiz','brief') | NO | — | — |
| `data` | JSON | YES | NULL | JSONB |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |
| `title` | VARCHAR(255) | YES | NULL | Added 2026_03_30 |
| `media_url` | TEXT | YES | NULL | Originally VARCHAR, widened 2026_04_11 |
| `is_published` | BOOLEAN | NO | `true` | Added 2026_04_01 |
| `order` | INTEGER | NO | `0` | Added 2026_04_01, indexed |

#### `marketplace_tasks` (created: 2024_01_01_000030, altered: 2 migrations)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `content_id` | UUID | NO | — | FK→contents.id, ON DELETE CASCADE |
| `status` | ENUM('open','taken','done') | NO | `'open'` | — |
| `creator_id` | VARCHAR(255) | YES | NULL | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |
| `attachment_url` | VARCHAR(255) | YES | NULL | Added 2026_03_30 |
| `task_type` | VARCHAR(20) | NO | `'bid'` | Added 2026_04_14, indexed |
| `description` | TEXT | YES | NULL | Added 2026_04_14 |
| `suggested_freelancer_id` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL, indexed, added 2026_04_14 |
| `media_generation_id` | UUID | YES | NULL | FK→media_generations.id, ON DELETE SET NULL, indexed, added 2026_04_14 |

#### `student_progress` (created: 2024_01_01_000040)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `student_name` | VARCHAR(255) | NO | — | — |
| `score` | INTEGER | NO | — | — |
| `completion_date` | TIMESTAMP | NO | `CURRENT_TIMESTAMP` | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

#### `personal_access_tokens` (created: 2026_03_24)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `tokenable_type` | VARCHAR(255) | NO | — | morph |
| `tokenable_id` | BIGINT | NO | — | morph |
| `name` | TEXT | NO | — | — |
| `token` | VARCHAR(64) | NO | — | UNIQUE |
| `abilities` | TEXT | YES | NULL | — |
| `last_used_at` | TIMESTAMPTZ | YES | NULL | — |
| `expires_at` | TIMESTAMPTZ | YES | NULL | indexed |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Index**: `[tokenable_type, tokenable_id]` (morph)

#### `activity_logs` (created: 2026_04_01)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `actor_id` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL |
| `action` | VARCHAR(255) | NO | — | — |
| `subject_type` | VARCHAR(255) | YES | NULL | polymorphic |
| `subject_id` | BIGINT | YES | NULL | polymorphic |
| `metadata` | JSON | YES | NULL | JSONB |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Index**: `[subject_type, subject_id]`

#### `homepage_sections` (created: 2026_04_01)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `key` | VARCHAR(255) | NO | — | UNIQUE |
| `label` | VARCHAR(255) | NO | — | — |
| `position` | INTEGER | NO | `0` | — |
| `is_enabled` | BOOLEAN | NO | `true` | — |
| `data_source` | VARCHAR(255) | YES | NULL | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

#### `media_files` (created: 2026_04_01)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `uploader_id` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL |
| `file_path` | VARCHAR(255) | NO | — | — |
| `file_name` | VARCHAR(255) | NO | — | — |
| `mime_type` | VARCHAR(255) | YES | NULL | — |
| `size` | INTEGER | YES | NULL | — |
| `disk` | VARCHAR(255) | NO | `'supabase'` | — |
| `category` | VARCHAR(255) | YES | NULL | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

#### `system_settings` (created: 2026_04_03)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `key` | VARCHAR(255) | NO | — | UNIQUE |
| `value` | TEXT | YES | NULL | — |
| `type` | VARCHAR(255) | NO | `'text'` | — |
| `group` | VARCHAR(255) | NO | `'general'` | — |
| `description` | VARCHAR(255) | YES | NULL | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

#### `recommended_projects` (created: 2026_04_03, altered: 1 migration)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `title` | VARCHAR(255) | NO | — | — |
| `description` | TEXT | YES | NULL | — |
| `thumbnail_url` | TEXT | YES | NULL | Originally VARCHAR, widened 2026_04_11 |
| `ratio` | VARCHAR(255) | NO | `'16:9'` | — |
| `project_type` | VARCHAR(255) | YES | NULL | — |
| `tags` | JSON | YES | NULL | JSONB |
| `modules` | JSON | YES | NULL | JSONB |
| `source_type` | VARCHAR(255) | NO | — | indexed |
| `source_reference` | VARCHAR(255) | YES | NULL | — |
| `source_payload` | JSON | YES | NULL | JSONB |
| `display_priority` | INTEGER | NO | `0` | indexed |
| `is_active` | BOOLEAN | NO | `true` | indexed |
| `starts_at` | TIMESTAMPTZ | YES | NULL | indexed |
| `ends_at` | TIMESTAMPTZ | YES | NULL | indexed |
| `created_by` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL |
| `updated_by` | BIGINT | YES | NULL | FK→users.id, ON DELETE SET NULL |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |
| `project_file_url` | TEXT | YES | NULL | Originally VARCHAR, widened 2026_04_11 |

**Indexes**: `[source_type, source_reference]`

#### `subjects` (created: 2026_04_07)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `name` | VARCHAR(255) | NO | — | — |
| `slug` | VARCHAR(255) | NO | — | UNIQUE |
| `description` | TEXT | YES | NULL | — |
| `display_order` | UNSIGNED INT | NO | `0` | — |
| `is_active` | BOOLEAN | NO | `true` | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Index**: `[is_active, display_order]`

#### `sub_subjects` (created: 2026_04_07)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `subject_id` | BIGINT | NO | — | FK→subjects.id, ON DELETE CASCADE |
| `name` | VARCHAR(255) | NO | — | — |
| `slug` | VARCHAR(255) | NO | — | — |
| `description` | TEXT | YES | NULL | — |
| `display_order` | UNSIGNED INT | NO | `0` | — |
| `is_active` | BOOLEAN | NO | `true` | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Indexes**: `[subject_id, slug]` UNIQUE, `[subject_id, is_active, display_order]`

#### `system_recommendation_assignments` (created: 2026_04_07)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `user_id` | BIGINT | NO | — | FK→users.id, ON DELETE CASCADE |
| `recommendation_key` | VARCHAR(255) | NO | — | — |
| `recommendation_item_id` | VARCHAR(255) | NO | — | — |
| `source_type` | VARCHAR(255) | NO | — | — |
| `source_reference` | VARCHAR(255) | NO | — | — |
| `subject_id` | BIGINT | YES | NULL | FK→subjects.id, ON DELETE SET NULL |
| `sub_subject_id` | BIGINT | YES | NULL | FK→sub_subjects.id, ON DELETE SET NULL |
| `first_distributed_at` | TIMESTAMPTZ | NO | — | — |
| `last_distributed_at` | TIMESTAMPTZ | NO | — | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Indexes**: `[user_id, recommendation_key]` UNIQUE, `[source_type, source_reference]`, `[sub_subject_id, recommendation_key]`, `subject_id`, `last_distributed_at`

#### `media_generations` (created: 2026_04_07, altered: 3 migrations)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | UUID | NO | `gen_random_uuid()` | PK |
| `generated_from_id` | UUID | YES | NULL | FK→media_generations.id (self-ref), ON DELETE SET NULL, indexed |
| `is_regeneration` | BOOLEAN | NO | `false` | — |
| `teacher_id` | BIGINT | NO | — | FK→users.id, ON DELETE CASCADE |
| `subject_id` | BIGINT | YES | NULL | FK→subjects.id, ON DELETE SET NULL |
| `sub_subject_id` | BIGINT | YES | NULL | FK→sub_subjects.id, ON DELETE SET NULL |
| `topic_id` | UUID | YES | NULL | FK→topics.id, ON DELETE SET NULL |
| `content_id` | UUID | YES | NULL | FK→contents.id, ON DELETE SET NULL |
| `recommended_project_id` | BIGINT | YES | NULL | FK→recommended_projects.id, ON DELETE SET NULL |
| `raw_prompt` | TEXT | NO | — | — |
| `request_fingerprint` | VARCHAR(64) | NO | — | — |
| `active_duplicate_key` | VARCHAR(64) | YES | NULL | UNIQUE |
| `preferred_output_type` | VARCHAR(255) | NO | `'auto'` | — |
| `resolved_output_type` | VARCHAR(255) | YES | NULL | — |
| `status` | VARCHAR(255) | NO | `'queued'` | — |
| `llm_provider` | VARCHAR(255) | YES | NULL | — |
| `llm_model` | VARCHAR(255) | YES | NULL | — |
| `generator_provider` | VARCHAR(255) | YES | NULL | — |
| `generator_model` | VARCHAR(255) | YES | NULL | — |
| `interpretation_payload` | JSON | YES | NULL | JSONB |
| `generation_spec_payload` | JSON | YES | NULL | JSONB |
| `delivery_payload` | JSON | YES | NULL | JSONB |
| `generator_service_response` | JSON | YES | NULL | JSONB |
| `storage_path` | VARCHAR(255) | YES | NULL | — |
| `file_url` | TEXT | YES | NULL | — |
| `thumbnail_url` | TEXT | YES | NULL | — |
| `mime_type` | VARCHAR(255) | YES | NULL | — |
| `error_code` | VARCHAR(255) | YES | NULL | — |
| `error_message` | TEXT | YES | NULL | — |
| `interpretation_audit_payload` | JSON | YES | NULL | JSONB, added 2026_04_07_000007 |
| `decision_payload` | JSON | YES | NULL | JSONB, added 2026_04_07_000007 |
| `orchestration_audit_payload` | JSON | YES | NULL | JSONB, added 2026_04_07_000008 |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Indexes**: `[teacher_id, created_at]`, `[status, created_at]`, `[teacher_id, request_fingerprint]`

#### `freelancer_matches` (created: 2026_04_14)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `media_generation_id` | UUID | NO | — | FK→media_generations.id, ON DELETE CASCADE |
| `freelancer_id` | BIGINT | NO | — | FK→users.id, ON DELETE CASCADE |
| `match_score` | FLOAT | NO | `0` | — |
| `portfolio_relevance_score` | FLOAT | NO | `0` | — |
| `success_rate` | FLOAT | NO | `0` | — |
| `created_at` | TIMESTAMPTZ | YES | — | — |
| `updated_at` | TIMESTAMPTZ | YES | — | — |

**Indexes**: `media_generation_id`, `freelancer_id`, `match_score`, `[media_generation_id, freelancer_id]` UNIQUE

---

## 2. Migration Status & Schema Drift Analysis

### 2.1 Migration Timeline

| # | Timestamp | Name | Status |
|---|-----------|------|--------|
| 1 | 0001_01_01_000000 | create_users_table | ✅ Ran |
| 2 | 0001_01_01_000001 | create_cache_table | ✅ Ran |
| 3 | 0001_01_01_000002 | create_jobs_table | ✅ Ran |
| 4 | 2024_01_01_000010 | create_topics_table | ✅ Ran |
| 5 | 2024_01_01_000020 | create_contents_table | ✅ Ran |
| 6 | 2024_01_01_000030 | create_marketplace_tasks_table | ✅ Ran |
| 7 | 2024_01_01_000040 | create_student_progress_table | ✅ Ran |
| 8 | 2026_03_24_224308 | create_personal_access_tokens_table | ✅ Ran |
| 9 | 2026_03_30_000001 | add_media_fields_to_tables | ✅ Ran |
| 10 | 2026_04_01_000001 | add_role_to_users_table | ✅ Ran |
| 11 | 2026_04_01_045541 | create_activity_logs_table | ✅ Ran |
| 12 | 2026_04_01_045542 | create_homepage_sections_table | ✅ Ran |
| 13 | 2026_04_01_045544 | create_media_files_table | ✅ Ran |
| 14 | 2026_04_01_045545 | add_admin_monitoring_fields_to_entities | ✅ Ran |
| 15 | 2026_04_01_121211 | add_security_questions_to_users_table | ✅ Ran |
| 16 | 2026_04_03_085441 | create_system_settings_table | ✅ Ran |
| 17 | 2026_04_03_140000 | create_recommended_projects_table | ✅ Ran |
| 18 | 2026_04_04_015344 | add_project_file_url_to_recommended_projects_table | ✅ Ran |
| 19 | 2026_04_07_000001 | create_subjects_and_sub_subjects_tables | ✅ Ran |
| 20 | 2026_04_07_000002 | add_normalized_owner_fields_to_topics_table | ✅ Ran |
| 21 | 2026_04_07_000003 | add_sub_subject_id_to_topics_table | ✅ Ran |
| 22 | 2026_04_07_000004 | add_primary_subject_id_to_users_table | ✅ Ran |
| 23 | 2026_04_07_000005 | create_system_recommendation_assignments_table | ✅ Ran |
| 24 | 2026_04_07_000006 | create_media_generations_table | ✅ Ran |
| 25 | 2026_04_07_000007 | add_orchestration_payloads_to_media_generations_table | ✅ Ran |
| 26 | 2026_04_07_000008 | add_orchestration_audit_payload_to_media_generations_table | ✅ Ran |
| 27 | 2026_04_11_140000 | widen_media_publication_url_columns | ✅ Ran |
| 28 | 2026_04_14_100000 | add_parent_generation_to_media_generations | ✅ Ran |
| 29 | 2026_04_14_100001 | optimize_marketplace_tasks_for_refinement | ✅ Ran |
| 30 | 2026_04_14_100002 | create_freelancer_matches_table | ✅ Ran |

**Schema drift risk**: LOW. All migrations are sequential with no overlapping timestamps. No raw SQL detected — all use Schema builder. The `2024_*` timestamp prefix suggests initial schema was created separately, then real development started in 2026.

### 2.2 Schema Drift Indicators

| Check | Result |
|-------|--------|
| Overlapping timestamps | None |
| Raw SQL in migrations | None (all use Schema builder) |
| Down migrations | All present (standard Laravel) |
| Column type mismatches | None detected |
| Missing indexes on FK columns | ✅ All FK columns indexed |

---

## 3. Per-Table Row Count Estimation & Growth Rate

### 3.1 Estimation Method

Derived from:
- Model relationships and usage patterns
- Migration creation dates
- Controller logic (e.g., `limit(20)` queries)
- Business domain analysis

### 3.2 Table Estimates

| Table | Est. Rows | Growth Rate | Hot/Cold | Notes |
|-------|-----------|-------------|----------|-------|
| `users` | 100-1K | ~10/month | Warm | Teachers + freelancers. `limit(20)` not applied |
| `password_reset_tokens` | 0-50 | ~5/month | Cold | Ephemeral, should be cleaned periodically |
| `sessions` | 50-500 | ~100/month | Hot | Active sessions. 30-day Sanctum expiry |
| `cache` | 0-100 | Variable | Hot | Laravel internal cache. Not used for LLM cache |
| `cache_locks` | 0-10 | Variable | Hot | Ephemeral locks |
| `jobs` | 0-50 | Burst | Hot | Queue jobs. Should be 0 when idle |
| `job_batches` | 0-20 | Burst | Cold | Batch tracking |
| `failed_jobs` | 0-100 | ~5/month | Cold | Failed job log |
| `topics` | 50-500 | ~20/month | Warm | Teacher-created educational topics |
| `contents` | 200-2K | ~100/month | Warm | Topic contents (module/quiz/brief) |
| `marketplace_tasks` | 10-100 | ~5/month | Cold | Freelancer task marketplace |
| `student_progress` | 500-5K | ~200/month | Warm | Student progress tracking |
| `personal_access_tokens` | 100-1K | ~50/month | Warm | Sanctum tokens. 1 per device per user |
| `activity_logs` | 1K-10K | ~500/month | Hot | Audit log. Grows indefinitely |
| `homepage_sections` | 5-20 | Rare | Cold | App config. Static data |
| `media_files` | 100-1K | ~50/month | Warm | File metadata (not actual files) |
| `system_settings` | 10-50 | Rare | Cold | App settings. Static data |
| `recommended_projects` | 20-200 | ~10/month | Warm | Admin-curated + system-generated |
| `subjects` | 10-50 | Rare | Cold | Taxonomy: school subjects |
| `sub_subjects` | 50-200 | Rare | Cold | Taxonomy: sub-subjects |
| `system_recommendation_assignments` | 1K-10K | ~500/month | Hot | User-recommendation tracking |
| `media_generations` | 500-5K | ~200/month | Hot | Core business table. Grows with usage |
| `freelancer_matches` | 100-1K | ~50/month | Warm | Freelancer matching scores |

### 3.3 Growth Rate Classification

| Category | Tables | Strategy |
|----------|--------|----------|
| **Hot (high write)** | `activity_logs`, `media_generations`, `system_recommendation_assignments`, `sessions` | Index on `created_at`, partitioning consider later |
| **Warm (moderate)** | `users`, `topics`, `contents`, `student_progress`, `personal_access_tokens` | Standard indexes |
| **Cold (rare write)** | `subjects`, `sub_subjects`, `homepage_sections`, `system_settings`, `password_reset_tokens` | Minimal indexing |

---

## 4. JSONB Column Analysis

### 4.1 Complete JSONB Inventory

| Table | Column | Model Cast | Typical Size | Query Pattern |
|-------|--------|------------|--------------|---------------|
| `contents` | `data` | `array` | 0.5-5 KB | Read-only, displayed in UI |
| `activity_logs` | `metadata` | `array` | 0.1-2 KB | Read-only, audit log |
| `recommended_projects` | `tags` | `array` | 0.01-0.5 KB | Read-only, filtering possible |
| `recommended_projects` | `modules` | `array` | 0.01-0.5 KB | Read-only |
| `recommended_projects` | `source_payload` | `array` | 0.1-5 KB | Read-only |
| `media_generations` | `interpretation_payload` | `array` | 2-20 KB | Read-only after write |
| `media_generations` | `interpretation_audit_payload` | `array` | 1-10 KB | Read-only after write |
| `media_generations` | `generation_spec_payload` | `array` | 1-10 KB | Read-only after write |
| `media_generations` | `decision_payload` | `array` | 1-10 KB | Read-only after write |
| `media_generations` | `orchestration_audit_payload` | `array` | 0.5-5 KB | Read-only after write |
| `media_generations` | `delivery_payload` | `array` | 2-20 KB | Read-only after write |
| `media_generations` | `generator_service_response` | `array` | 1-10 KB | Read-only after write |

### 4.2 JSONB Recommendation: KEEP vs SPLIT

| Column | Recommendation | Reasoning |
|--------|---------------|-----------|
| `contents.data` | **KEEP JSONB** | Flexible schema per content type (module/quiz/brief). No WHERE queries on nested fields. |
| `activity_logs.metadata` | **KEEP JSONB** | Heterogeneous event data. Never queried by nested fields. |
| `recommended_projects.tags` | **KEEP JSONB** | Simple array, no indexing needed. |
| `recommended_projects.modules` | **KEEP JSONB** | Simple array, no indexing needed. |
| `recommended_projects.source_payload` | **KEEP JSONB** | Admin/debug only. Never queried. |
| `media_generations.*_payload` (all 7) | **KEEP JSONB** | All are write-once-read-many. Never used in WHERE clauses. Large blobs. SPLITTING would add 7 tables with no query benefit. |
| `media_generations.generator_service_response` | **KEEP JSONB** | Raw API response. Debug/audit only. |

### 4.3 JSONB Summary

**Recommendation: KEEP ALL JSONB COLUMNS AS-IS.**

Reasoning:
1. **No JSONB column is queried with `WHERE` on nested fields** — all are read-only blobs
2. **SPLITTING would add 7+ tables** with 1:1 relationships, increasing JOIN complexity without query benefit
3. **PostgreSQL JSONB is efficient** for this access pattern (write-once, read-as-blob)
4. **Rust `serde_json::Value`** maps directly to JSONB — no conversion overhead

**Exception to watch**: If future features need to query `interpretation_payload` by nested fields (e.g., "find all generations where interpretation detected topic X"), consider adding a denormalized column instead of splitting the JSONB.

---

## 5. Foreign Key Constraints & ON DELETE Behavior

### 5.1 Complete FK Map

| Source Table | Column | References | ON DELETE | Notes |
|-------------|--------|------------|-----------|-------|
| `users` | `primary_subject_id` | `subjects.id` | SET NULL | User keeps account if subject deleted |
| `contents` | `topic_id` | `topics.id` | CASCADE | Contents deleted when topic deleted |
| `marketplace_tasks` | `content_id` | `contents.id` | CASCADE | Tasks deleted when content deleted |
| `marketplace_tasks` | `suggested_freelancer_id` | `users.id` | SET NULL | Task survives freelancer deletion |
| `marketplace_tasks` | `media_generation_id` | `media_generations.id` | SET NULL | Task survives generation deletion |
| `topics` | `owner_user_id` | `users.id` | SET NULL | Topic survives user deletion |
| `topics` | `sub_subject_id` | `sub_subjects.id` | SET NULL | Topic survives sub_subject deletion |
| `activity_logs` | `actor_id` | `users.id` | SET NULL | Log survives user deletion |
| `media_files` | `uploader_id` | `users.id` | SET NULL | File metadata survives user deletion |
| `sub_subjects` | `subject_id` | `subjects.id` | CASCADE | Sub-subjects deleted when subject deleted |
| `system_recommendation_assignments` | `user_id` | `users.id` | CASCADE | Assignments deleted when user deleted |
| `system_recommendation_assignments` | `subject_id` | `subjects.id` | SET NULL | Assignment survives subject deletion |
| `system_recommendation_assignments` | `sub_subject_id` | `sub_subjects.id` | SET NULL | Assignment survives sub_subject deletion |
| `recommended_projects` | `created_by` | `users.id` | SET NULL | Project survives user deletion |
| `recommended_projects` | `updated_by` | `users.id` | SET NULL | Project survives user deletion |
| `media_generations` | `generated_from_id` | `media_generations.id` | SET NULL | Self-ref, parent survives child deletion |
| `media_generations` | `teacher_id` | `users.id` | CASCADE | **Generations deleted when teacher deleted** |
| `media_generations` | `subject_id` | `subjects.id` | SET NULL | Generation survives subject deletion |
| `media_generations` | `sub_subject_id` | `sub_subjects.id` | SET NULL | Generation survives sub_subject deletion |
| `media_generations` | `topic_id` | `topics.id` | SET NULL | Generation survives topic deletion |
| `media_generations` | `content_id` | `contents.id` | SET NULL | Generation survives content deletion |
| `media_generations` | `recommended_project_id` | `recommended_projects.id` | SET NULL | Generation survives project deletion |
| `freelancer_matches` | `media_generation_id` | `media_generations.id` | CASCADE | Match deleted when generation deleted |
| `freelancer_matches` | `freelancer_id` | `users.id` | CASCADE | Match deleted when freelancer deleted |

### 5.2 Cascade Chain Analysis

**Critical cascade chains**:

```
users (DELETE) → media_generations (CASCADE)
  → freelancer_matches (CASCADE)
  → marketplace_tasks.media_generation_id (SET NULL)

users (DELETE) → system_recommendation_assignments (CASCADE)

topics (DELETE) → contents (CASCADE)
  → marketplace_tasks (CASCADE)

subjects (DELETE) → sub_subjects (CASCADE)
  → topics.sub_subject_id (SET NULL)
  → media_generations.sub_subject_id (SET NULL)
```

### 5.3 ON DELETE Behavior Summary

| Behavior | Count | Usage |
|----------|-------|-------|
| CASCADE | 6 | Parent-child relationships where child has no meaning without parent |
| SET NULL | 17 | Optional references where entity survives reference deletion |
| No FK | — | `student_progress`, `system_settings`, `homepage_sections`, `cache*`, `jobs*`, `sessions` |

### 5.4 sqlx Migration Notes

- **All FK columns have indexes** — good for sqlx query performance
- **CASCADE on `media_generations.teacher_id`** — deleting a user deletes ALL their generations. This is intentional but should be documented
- **No `ON UPDATE`** — PostgreSQL doesn't need it since PKs are immutable
- **Mixed ID types**: `users` uses BIGINT, `topics`/`contents`/`media_generations` use UUID, `subjects`/`sub_subjects` use BIGINT. Rust structs need different ID types

---

## 6. Trigger Verification

### 6.1 Findings

**No database triggers found.**

Laravel does not use database triggers. All business logic (status transitions, audit logging, fingerprint computation) is handled in PHP code:
- `MediaGeneration::boot()` — `saving` hook computes `request_fingerprint` and `active_duplicate_key`
- `Topic::boot()` — `saving` hook syncs `owner_user_id` from legacy `teacher_id`
- `MediaGenerationWorkflowService` — handles status transitions with `lockForUpdate()`

### 6.2 Implication for Rust Port

No triggers to port. All business logic must be replicated in Rust code:
- `MediaGeneration` fingerprint computation in a `saving` hook → Rust pre-save middleware or model method
- `Topic` ownership sync in a `saving` hook → Rust pre-save middleware
- Status transitions via `AuditTrailService` → Rust state machine with `SELECT FOR UPDATE`

---

## 7. LLM Adapter DB Schema (Separate Database)

### 7.1 Tables (7 total)

#### `interpretation_cache_entries` (0001_adapter_state.sql)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `cache_key` | CHAR(64) | NO | — | UNIQUE INDEX |
| `request_payload` | JSONB | NO | — | — |
| `response_payload` | JSONB | NO | — | — |
| `created_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `expires_at` | TIMESTAMPTZ | NO | — | INDEX |
| `hit_count` | BIGINT | NO | `0` | CHECK (>= 0) |
| `last_hit_at` | TIMESTAMPTZ | YES | NULL | — |

#### `delivery_cache_entries` (0001_adapter_state.sql)

Identical schema to `interpretation_cache_entries`.

#### `rate_limit_policies` (0002_governance_state.sql)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `scope_type` | VARCHAR(32) | NO | — | CHECK IN ('global','provider','model','route') |
| `strategy` | VARCHAR(32) | NO | `'fixed_window'` | CHECK IN ('fixed_window') |
| `route` | VARCHAR(32) | NO | `'all'` | CHECK IN ('all','interpret','respond') |
| `provider` | VARCHAR(100) | NO | `'*'` | — |
| `model` | VARCHAR(200) | NO | `'*'` | — |
| `window_unit` | VARCHAR(16) | NO | — | CHECK IN ('minute','hour','day') |
| `max_requests` | BIGINT | YES | NULL | CHECK (>= 0) |
| `max_input_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `max_output_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `max_total_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `max_estimated_cost_usd` | NUMERIC(20,8) | YES | NULL | CHECK (>= 0) |
| `enabled` | BOOLEAN | NO | `true` | — |
| `created_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `updated_at` | TIMESTAMPTZ | NO | `NOW()` | — |

**CHECK constraints enforce scope coherence**:
- `global`: route='all', provider='*', model='*'
- `route`: route<>'all', provider='*', model='*'
- `provider`: provider<>'*', model='*'
- `model`: model<>'*'

#### `rate_limit_buckets` (0002_governance_state.sql)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `policy_id` | BIGINT | NO | — | FK→rate_limit_policies.id, ON DELETE CASCADE |
| `scope_type` | VARCHAR(32) | NO | — | CHECK |
| `strategy` | VARCHAR(32) | NO | `'fixed_window'` | CHECK |
| `route` | VARCHAR(32) | NO | — | CHECK |
| `provider` | VARCHAR(100) | NO | — | — |
| `model` | VARCHAR(200) | NO | — | — |
| `window_unit` | VARCHAR(16) | NO | — | CHECK |
| `window_started_at` | TIMESTAMPTZ | NO | — | — |
| `window_ends_at` | TIMESTAMPTZ | NO | — | CHECK (ends > started) |
| `request_count` | BIGINT | NO | `0` | CHECK (>= 0) |
| `input_tokens` | BIGINT | NO | `0` | CHECK (>= 0) |
| `output_tokens` | BIGINT | NO | `0` | CHECK (>= 0) |
| `total_tokens` | BIGINT | NO | `0` | CHECK (>= 0) |
| `estimated_cost_usd` | NUMERIC(20,8) | NO | `0` | CHECK (>= 0) |
| `deny_count` | BIGINT | NO | `0` | CHECK (>= 0) |
| `last_request_id` | VARCHAR(255) | YES | NULL | — |
| `last_generation_id` | VARCHAR(100) | YES | NULL | — |
| `last_seen_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `created_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `updated_at` | TIMESTAMPTZ | NO | `NOW()` | — |

#### `llm_request_ledger` (0002_governance_state.sql)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `request_id` | VARCHAR(255) | NO | — | UNIQUE INDEX |
| `generation_id` | VARCHAR(100) | NO | — | INDEX |
| `route` | VARCHAR(32) | NO | — | CHECK IN ('interpret','respond') |
| `request_type` | VARCHAR(100) | NO | — | — |
| `provider` | VARCHAR(100) | NO | — | — |
| `primary_provider` | VARCHAR(100) | NO | — | — |
| `model` | VARCHAR(200) | NO | — | — |
| `requested_model` | VARCHAR(200) | NO | — | — |
| `latency_ms` | NUMERIC(12,2) | YES | NULL | — |
| `retry_count` | INTEGER | NO | `0` | CHECK (>= 0) |
| `cache_status` | VARCHAR(16) | NO | — | CHECK IN ('hit','miss','bypass') |
| `final_status` | VARCHAR(32) | NO | — | — |
| `error_class` | VARCHAR(255) | YES | NULL | — |
| `error_code` | VARCHAR(100) | YES | NULL | — |
| `fallback_used` | BOOLEAN | NO | `false` | — |
| `fallback_reason` | VARCHAR(100) | YES | NULL | — |
| `attempted_providers` | JSONB | NO | `'[]'` | CHECK (typeof = 'array') |
| `upstream_request_id` | VARCHAR(255) | YES | NULL | — |
| `provider_response_id` | VARCHAR(255) | YES | NULL | — |
| `provider_model_version` | VARCHAR(200) | YES | NULL | — |
| `finish_reason` | VARCHAR(100) | YES | NULL | — |
| `candidate_index` | INTEGER | YES | NULL | — |
| `input_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `output_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `total_tokens` | BIGINT | YES | NULL | CHECK (>= 0) |
| `estimated_cost_usd` | NUMERIC(20,8) | YES | NULL | CHECK (>= 0) |
| `cache_key` | CHAR(64) | YES | NULL | — |
| `metadata` | JSONB | NO | `'{}'` | CHECK (typeof = 'object') |
| `created_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `completed_at` | TIMESTAMPTZ | YES | NULL | — |

#### `price_catalog_entries` (0002_governance_state.sql)

| Column | Type | Nullable | Default | Constraints |
|--------|------|----------|---------|-------------|
| `id` | BIGSERIAL | NO | auto | PK |
| `provider` | VARCHAR(100) | NO | — | — |
| `model` | VARCHAR(200) | NO | — | — |
| `currency_code` | CHAR(3) | NO | `'USD'` | — |
| `cost_unit` | VARCHAR(16) | NO | `'1k_tokens'` | CHECK IN ('1k_tokens') |
| `input_cost_per_unit_usd` | NUMERIC(20,8) | YES | NULL | CHECK (>= 0) |
| `output_cost_per_unit_usd` | NUMERIC(20,8) | YES | NULL | CHECK (>= 0) |
| `request_cost_usd` | NUMERIC(20,8) | YES | NULL | CHECK (>= 0) |
| `effective_from` | TIMESTAMPTZ | NO | `NOW()` | — |
| `effective_to` | TIMESTAMPTZ | YES | NULL | CHECK (to > from) |
| `is_active` | BOOLEAN | NO | `true` | — |
| `created_at` | TIMESTAMPTZ | NO | `NOW()` | — |
| `updated_at` | TIMESTAMPTZ | NO | `NOW()` | — |

### 7.2 Views (2)

- `llm_request_daily_aggregates` — daily stats by route/provider/model (cache hit ratio, tokens, cost)
- `llm_request_daily_route_aggregates` — daily stats by route only (rollup)

### 7.3 Cache Table Consolidation Plan

Per ADR-008, the plan consolidates `interpretation_cache_entries` + `delivery_cache_entries` into a single `llm_cache_entries` table with a `route` discriminator column. This is a **good approach** — reduces 2 identical tables to 1.

**Recommended consolidated schema**:

```sql
CREATE TABLE llm_cache_entries (
    id BIGSERIAL PRIMARY KEY,
    route VARCHAR(16) NOT NULL CHECK (route IN ('interpret', 'respond')),
    cache_key CHAR(64) NOT NULL,
    request_payload JSONB NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count BIGINT NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ NULL,
    CHECK (hit_count >= 0)
);

CREATE UNIQUE INDEX idx_llm_cache_entries_cache_key ON llm_cache_entries (cache_key);
CREATE INDEX idx_llm_cache_entries_expires_at ON llm_cache_entries (expires_at);
CREATE INDEX idx_llm_cache_entries_route ON llm_cache_entries (route, expires_at);
```

### 7.4 LLM Adapter Tables to Migrate to Application DB

| LLM Adapter Table | Migrate? | Target Name | Notes |
|-------------------|----------|-------------|-------|
| `interpretation_cache_entries` | YES | `llm_cache_entries` (merged) | Merge with delivery |
| `delivery_cache_entries` | YES | `llm_cache_entries` (merged) | Merge with interpretation |
| `rate_limit_policies` | YES | `llm_rate_limit_policies` | Direct port |
| `rate_limit_buckets` | YES | `llm_rate_limit_buckets` | Direct port |
| `llm_request_ledger` | YES | `llm_request_ledger` | Direct port |
| `price_catalog_entries` | YES | `price_catalog_entries` | Direct port |

**Views** (`llm_request_daily_aggregates`, `llm_request_daily_route_aggregates`) — port as sqlx queries or materialized views.

---

## 8. Environment Variables — LLM Adapter → Rust Config

### 8.1 Complete Mapping

| Python Env Var | Rust Config Key | Default | Type | Notes |
|----------------|-----------------|---------|------|-------|
| `LLM_ADAPTER_DATABASE_URL` | `database.url` | *(required)* | String | Neon connection string |
| `LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS` | `database.connect_timeout_secs` | `3` | u64 | — |
| `LLM_ADAPTER_DATABASE_POOL_MIN_SIZE` | `database.pool_min_size` | `1` | u32 | — |
| `LLM_ADAPTER_DATABASE_POOL_MAX_SIZE` | `database.pool_max_size` | `5` | u32 | — |
| `LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS` | `database.pool_max_idle_secs` | `300` | u64 | — |
| `LLM_ADAPTER_DATABASE_AUTO_MIGRATE` | `database.auto_migrate` | `false` | bool | sqlx migrate on startup |
| `LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS` | `providers.timeout_secs` | `30` | u64 | Default HTTP timeout |
| `LLM_ADAPTER_SHARED_SECRET` | `hmac.shared_secret` | *(required)* | String | HMAC signing secret |
| `LLM_ADAPTER_SHARED_SECRET_PREVIOUS` | `hmac.previous_secret` | `""` | String | For rotation |
| `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS` | `hmac.max_age_secs` | `300` | u64 | Replay protection window |
| `LLM_ADAPTER_CACHE_SCHEMA_VERSION` | `cache.schema_version` | `"llm_adapter_cache.v1"` | String | Cache key versioning |
| `LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS` | `cache.interpretation_ttl_secs` | `86400` | u64 | 24 hours |
| `LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS` | `cache.delivery_ttl_secs` | `21600` | u64 | 6 hours |
| `LLM_ADAPTER_CACHE_STAMPEDE_POLL_INTERVAL_MS` | `cache.stampede_poll_interval_ms` | `100` | u64 | — |
| `LLM_ADAPTER_CACHE_STAMPEDE_WAIT_TIMEOUT_MS` | `cache.stampede_wait_timeout_ms` | `1500` | u64 | — |
| `LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE` | `cache.cleanup_batch_size` | `100` | u32 | — |
| `LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS` | `cache.lazy_cleanup_interval_secs` | `60` | u64 | — |
| `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER` | `providers.interpretation.active` | `"gemini"` | String | — |
| `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER` | `providers.delivery.active` | `"gemini"` | String | — |
| `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE` | `providers.allow_route_divergence` | `true` | bool | — |
| `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER` | `providers.interpretation.fallback` | `None` | Option | — |
| `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER` | `providers.delivery.fallback` | `None` | Option | — |
| `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES` | `providers.fallback_error_codes` | `("provider_timeout", ...)` | Vec | CSV |
| `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE` | `governance.interpretation.rpm` | `30` | u32 | — |
| `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_HOUR` | `governance.interpretation.rph` | `600` | u32 | — |
| `LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD` | `governance.interpretation.daily_budget` | `25.00` | Decimal | — |
| `LLM_ADAPTER_INTERPRETATION_DEFAULT_ESTIMATED_COST_USD` | `governance.interpretation.default_cost` | `0.025` | Decimal | — |
| `LLM_ADAPTER_INTERPRETATION_EXHAUSTED_ACTION` | `governance.interpretation.exhausted_action` | `"deny"` | String | deny/degrade |
| `LLM_ADAPTER_DELIVERY_ROUTE_ENABLED` | `governance.delivery.enabled` | `true` | bool | — |
| `LLM_ADAPTER_DELIVERY_REQUESTS_PER_MINUTE` | `governance.delivery.rpm` | `60` | u32 | — |
| `LLM_ADAPTER_DELIVERY_REQUESTS_PER_HOUR` | `governance.delivery.rph` | `1200` | u32 | — |
| `LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD` | `governance.delivery.daily_budget` | `10.00` | Decimal | — |
| `LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD` | `governance.delivery.default_cost` | `0.010` | Decimal | — |
| `LLM_ADAPTER_DELIVERY_EXHAUSTED_ACTION` | `governance.delivery.exhausted_action` | `"degrade"` | String | deny/degrade |
| `LLM_ADAPTER_BUDGET_WARNING_RATIO` | `governance.budget_warning_ratio` | `0.80` | Decimal | 0.0-1.0 |
| `LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD` | `governance.content_integrity_threshold` | `0.75` | Decimal | — |
| `LLM_ADAPTER_GEMINI_API_KEY` | `providers.gemini.api_key` | *(required)* | String | — |
| `LLM_ADAPTER_GEMINI_BASE_URL` | `providers.gemini.base_url` | `"https://generativelanguage.googleapis.com"` | String | — |
| `LLM_ADAPTER_GEMINI_API_VERSION` | `providers.gemini.api_version` | `"v1beta"` | String | — |
| `LLM_ADAPTER_GEMINI_INTERPRET_MODEL` | `providers.gemini.interpretation_model` | `"gemini-2.0-flash"` | String | — |
| `LLM_ADAPTER_GEMINI_DELIVERY_MODEL` | `providers.gemini.delivery_model` | `"gemini-2.0-flash"` | String | — |
| `LLM_ADAPTER_OPENAI_API_KEY` | `providers.openai.api_key` | `""` | String | — |
| `LLM_ADAPTER_OPENAI_BASE_URL` | `providers.openai.base_url` | `"https://api.openai.com"` | String | — |
| `LLM_ADAPTER_OPENAI_INTERPRET_MODEL` | `providers.openai.interpretation_model` | `"gpt-5.4"` | String | — |
| `LLM_ADAPTER_OPENAI_DELIVERY_MODEL` | `providers.openai.delivery_model` | `"gpt-5.4"` | String | — |
| `LLM_ADAPTER_OPENAI_ORGANIZATION` | `providers.openai.organization` | `""` | String | — |
| `LLM_ADAPTER_OPENAI_PROJECT` | `providers.openai.project` | `""` | String | — |

### 8.2 Additional Laravel Config to Port

| Laravel Config | Source | Rust Config Key | Notes |
|----------------|--------|-----------------|-------|
| `services.media_generation.llm_adapter.*` | `config/services.php` | `llm_adapter.*` | Base URL, shared secret, timeouts |
| `services.media_generation.interpreter.*` | `config/services.php` | `providers.interpretation.*` | Path, timeout, retry |
| `services.media_generation.drafting.*` | `config/services.php` | `providers.drafting.*` | Path, timeout, retry |
| `services.media_generation.delivery.*` | `config/services.php` | `providers.delivery.*` | Path, timeout, retry |
| `services.media_generation.python.*` | `config/services.php` | `media_gen.*` | Python renderer config |
| `services.media_generation.queue.*` | `config/services.php` | `queue.*` | Queue config → Redis Streams |
| `sanctum.expiration` | `config/sanctum.php` | `auth.token_expiration_minutes` | 43200 (30 days) |
| `cors.*` | `config/cors.php` | `cors.*` | CORS config |

---

## 9. Recommendations & Plan Improvements

### 9.1 Migration Strategy (improved)

**Instead of porting 30 individual migrations**, squash into 3 logical migration files:

1. `0001_initial_schema.sql` — all 17 tables with final column definitions
2. `0002_llm_cache_consolidation.sql` — `llm_cache_entries` (merged from 2 adapter tables)
3. `0003_llm_governance.sql` — `llm_rate_limit_policies`, `llm_rate_limit_buckets`, `llm_request_ledger`, `price_catalog_entries`

This saves 27+ migration files and makes the schema easier to understand.

### 9.2 ID Type Strategy

The codebase uses 3 ID types:
- **BIGINT** (`users`, `subjects`, `sub_subjects`, `system_settings`, `personal_access_tokens`, `freelancer_matches`)
- **UUID** (`topics`, `contents`, `marketplace_tasks`, `student_progress`, `media_generations`, `activity_logs`, `homepage_sections`, `media_files`)
- **BIGINT auto-increment** (`recommended_projects`, `system_recommendation_assignments`, `rate_limit_*`, `llm_*`)

**Rust recommendation**: Use `uuid::Uuid` for UUID columns, `i64` for BIGINT columns. Create type aliases:
```rust
type UserId = i64;
type TopicId = Uuid;
type MediaGenerationId = Uuid;
```

### 9.3 Polymorphic Relationships

`activity_logs.subject_type/subject_id` uses Laravel's polymorphic morph. In Rust, use an enum:
```rust
enum ActivitySubject {
    Topic(TopicId),
    Content(ContentId),
    MediaGeneration(MediaGenerationId),
    User(UserId),
}
```

### 9.4 Missing Indexes

| Table | Column | Suggested Index | Reason |
|-------|--------|-----------------|--------|
| `media_generations` | `llm_provider` | Partial index WHERE NOT NULL | Debug queries |
| `activity_logs` | `action` | B-tree | Filter by action type |
| `student_progress` | `student_name` | B-tree (ILIKE) | Search functionality |

### 9.5 Data Cleanup Recommendations

| Table | Cleanup Strategy | Frequency |
|-------|-----------------|-----------|
| `password_reset_tokens` | DELETE WHERE created_at < NOW() - INTERVAL '24 hours' | Hourly |
| `sessions` | DELETE WHERE last_activity < NOW() - INTERVAL '30 days' | Daily |
| `cache` | DELETE WHERE expiration < EXTRACT(EPOCH FROM NOW()) | Daily |
| `failed_jobs` | DELETE WHERE failed_at < NOW() - INTERVAL '30 days' | Weekly |
| `llm_cache_entries` | DELETE WHERE expires_at < NOW() | Per lazy_cleanup_interval |
| `rate_limit_buckets` | DELETE WHERE window_ends_at < NOW() - INTERVAL '7 days' | Daily |
| `llm_request_ledger` | Partition by month, drop partitions > 1 year | Monthly |
