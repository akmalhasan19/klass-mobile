╔══════════════════════════════════════════════════════════════════════════════╗
║                    RANGKUMAN PERBAIKAN GENERATION WORKFLOW                  ║
║                          Tanggal: 21 Juli 2026                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 1: MASALAH YANG DITEMUKAN & SUDAH DIFIX (9 masalah)
═══════════════════════════════════════════════════════════════════════════════
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #1-4: Worker & Database Migrations (Sudah dilakukan sebelumnya)        │
├─────────────────────────────────────────────────────────────────────────────┤
│ - Worker tidak ada (Redis stream tidak di-consume)                         │
│   → Fix: Embed worker di main.rs                                           │
│ - Tabel llm_rate_limit_policies tidak ada                                  │
│   → Fix: SQL migration di Neon                                             │
│ - Tabel llm_cache_entries kurang kolom hit_count                            │
│   → Fix: DROP + CREATE ulang                                               │
│ - Model tencent/hy3 tidak support json_object                               │
│   → Fix: Hapus response_format dari request (gateway/src/providers/)       │
└─────────────────────────────────────────────────────────────────────────────┘
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #5: DB Type Mismatch (jsonb vs json)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Error: "COALESCE could not convert type jsonb to json"                      │
│ File: gateway/src/llm/step_adapters.rs baris 265                           │
│                                                                             │
│ PERUBAHAN:                                                                  │
│ BEFORE: SET generation_spec_payload = COALESCE(generation_spec_payload, $1) │
│ AFTER:  SET generation_spec_payload = COALESCE(generation_spec_payload,     │
│         $1::jsonb)                                                          │
│                                                                             │
│ ALASAN: serde_json::Value di-bind sebagai tipe 'json' tapi kolom adalah     │
│ 'jsonb'. PostgreSQL tidak bisa menggabungkan keduanya dalam COALESCE.       │
└─────────────────────────────────────────────────────────────────────────────┘
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #6: Interpret Contract Repair (output_type_candidates)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Error: "invalid type: string 'pdf', expected struct OutputCandidate"        │
│ File: gateway/src/contracts/prompt_interpretation.rs                        │
│                                                                             │
│ PERUBAHAN:                                                                  │
│ - Tambah fungsi repair_interpretation_json() sebelum decode_and_validate()  │
│ - Fungsi ini memperbaiki response LLM sebelum validasi:                    │
│   • output_type_candidates string "pdf" → array of objects                 │
│   • output_type_candidates object → array of objects                        │
│   • Missing schema_version → inject "media_prompt_understanding.v1"         │
│   • Missing document_blueprint fields → inject defaults                     │
│   • Missing teacher_intent fields → inject defaults                         │
│   • Missing confidence fields → inject defaults                             │
│ - Tambah fungsi: normalize_output_type(), normalize_output_type_candidates_ │
│   string(), normalize_output_type_candidates_object(), repair_section()     │
│ - Tambah truncate_str() (char-aware, UTF-8 safe)                            │
│ - Hapus truncate() lama (byte-based, UTF-8 unsafe)                          │
│ - Tambah tests: test_repair_missing_schema_version,                         │
│   test_repair_output_type_candidates_as_string, etc.                        │
└─────────────────────────────────────────────────────────────────────────────┘
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #7: Draft Contract Repair (missing schema_version)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Error: "missing field schema_version at line 31 column 1"                   │
│ File: gateway/src/contracts/content_draft.rs                                │
│                                                                             │
│ PERUBAHAN:                                                                  │
│ - Tambah fungsi repair_draft_json() sebelum decode_and_validate()           │
│ - Fungsi ini memperbaiki response LLM:                                     │
│   • Missing schema_version → inject "media_content_draft.v1"                │
│   • Missing/null title → inject "Untitled Draft"                            │
│   • Missing/null summary → use title as fallback                            │
│   • Empty sections → inject minimal section                                 │
│   • Empty body_blocks → fill from purpose                                   │
│   • Missing teacher_delivery_summary → use title                            │
│ - Tambah fungsi: repair_draft_section(), normalize_body_block_type()        │
│ - Hapus truncate() lama, gunakan truncate_str()                             │
│ - Tambah tests: test_draft_repair_missing_schema_version,                   │
│   test_draft_repair_empty_sections, etc.                                    │
└─────────────────────────────────────────────────────────────────────────────┘
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #8: Python Renderer Contract Validation                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ Error: "artifact_invalid: Incoming request payload failed validation"       │
│ File: gateway/src/orchestrator/decision.rs                                  │
│                                                                             │
│ PERUBAHAN:                                                                  │
│ 1. Contract Version Mismatch (PENYEBAB UTAMA):                             │
│    BEFORE: "generator_output_metadata": "media_artifact_metadata.v1"       │
│    AFTER:  "generator_output_metadata": "media_generator_output_metadata.v1"│
│                                                                             │
│ 2. Normalisasi semua field di build_generation_spec():                      │
│    - title, language, summary, teacher_delivery_summary → non-null fallback │
│    - sections[].emphasis → normalize ke "short"/"medium"/"long"             │
│    - assessment_blocks[].type → normalize ke Literal values                 │
│    - body_blocks[].type & content → validate & normalize                    │
│    - assets[].type → validate & normalize                                   │
│    - sections[] minimal 1 entry (default_section helper)                    │
│    - layout_hints counts = actual len (section_count, asset_count, etc.)    │
│                                                                             │
│ 3. Tambah fungsi: normalize_emphasis(), normalize_assessment_type(),        │
│    normalize_body_block_type(), require_str(), default_section()            │
│                                                                             │
│ 4. Fix UTF-8 safety di default_section():                                   │
│    BEFORE: &teacher_prompt[..197]  (byte-based, panics on multi-byte)       │
│    AFTER:  teacher_prompt.chars().take(197).collect()                       │
└─────────────────────────────────────────────────────────────────────────────┘
 
┌─────────────────────────────────────────────────────────────────────────────┐
│ FIX #9: generation_status Sync Bug                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Error: User lihat "Pending" forever saat workflow gagal                     │
│ File: gateway/src/orchestrator/audit_trail.rs (mark_failed method)          │
│                                                                             │
│ PERUBAHAN:                                                                  │
│ BEFORE:                                                                     │
│   UPDATE media_generations                                                  │
│   SET status = 'failed',                                                    │
│       orchestration_audit_payload = $1,                                     │
│       error_code = $2,                                                      │
│       error_message = $3,                                                   │
│       updated_at = NOW()                                                    │
│   WHERE id = $4                                                             │
│                                                                             │
│ AFTER:                                                                      │
│   UPDATE media_generations                                                  │
│   SET status = 'failed',                                                    │
│       generation_status = 'failed',          ← TAMBAH INI                  │
│       orchestration_audit_payload = $1,                                     │
│       error_code = $2,                                                      │
│       error_message = $3,                                                   │
│       generation_error_code = $2,            ← TAMBAH INI                  │
│       generation_error_message = $3,         ← TAMBAH INI                  │
│       updated_at = NOW()                                                    │
│   WHERE id = $4                                                             │
│                                                                             │
│ ALASAN: mark_failed() sebelumnya hanya update 'status' tapi tidak update    │
│ 'generation_status'. Sehingga user lihat "Pending" padahal sudah "failed".  │
└─────────────────────────────────────────────────────────────────────────────┘
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 2: FILES YANG DIPERBAIKI
═══════════════════════════════════════════════════════════════════════════════
 
1. gateway/src/llm/step_adapters.rs
   → Fix #5: Cast $1::jsonb di COALESCE
 
2. gateway/src/contracts/prompt_interpretation.rs
   → Fix #6: repair_interpretation_json() + helpers
 
3. gateway/src/contracts/content_draft.rs
   → Fix #7: repair_draft_json() + helpers
 
4. gateway/src/orchestrator/decision.rs
   → Fix #8: Contract version fix + build_generation_spec() normalization
 
5. gateway/src/orchestrator/audit_trail.rs
   → Fix #9: mark_failed() update generation_status
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 3: STATUS SEMUA FIX
═══════════════════════════════════════════════════════════════════════════════
 
┌──────┬──────────────────────────────────────────────┬──────────┐
│  #   │ Masalah                                      │ Status   │
├──────┼──────────────────────────────────────────────┼──────────┤
│  1   │ Worker tidak ada (Redis stream)              │ ✅ Fixed │
│  2   │ Tabel llm_rate_limit_policies tidak ada      │ ✅ Fixed │
│  3   │ Tabel llm_cache_entries kurang kolom         │ ✅ Fixed │
│  4   │ Model tencent/hy3 json_object                │ ✅ Fixed │
│  5   │ DB type mismatch (jsonb vs json)             │ ✅ Fixed │
│  6   │ Interpret contract (output_type_candidates)  │ ✅ Fixed │
│  7   │ Draft contract (missing schema_version)      │ ✅ Fixed │
│  8   │ Python renderer validation                   │ ✅ Fixed │
│  9   │ generation_status sync bug                   │ ✅ Fixed │
│  10  │ Chromium sidecar tidak tersedia              │ ⏳ TODO  │
└──────┴──────────────────────────────────────────────┴──────────┘
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 4: YANG HARUS DILAKUKAN SELANJUTNYA (Step by Step)
═══════════════════════════════════════════════════════════════════════════════
 
STEP 1: VERIFIKASI DEPLOY GATEWAY
─────────────────────────────────
Buka Render Dashboard → klass-gateway → Logs
Cari log: "Starting Klass Gateway (server + embedded worker)"
Jika error "COALESCE" masih muncul = deploy belum selesai, tunggu atau redeploy.
Jika tidak ada error COALESCE = deploy berhasil ✅
 
STEP 2: BACKFILL DATA LAMA (Neon SQL Editor)
─────────────────────────────────────────────
UPDATE media_generations 
SET generation_status = 'failed',
    generation_error_code = error_code,
    generation_error_message = error_message
WHERE status = 'failed' AND generation_status = 'pending';
 
STEP 3: DEPLOY MEDIA-GENERATOR-SERVICE KE HUGGINGFACE
──────────────────────────────────────────────────────
 
3a. Buat HuggingFace Space:
    - Buka https://huggingface.co/new-space
    - Name: klass-media-generator
    - SDK: Docker
    - Visibility: Public/Private
 
3b. Set Environment Variables (di Space Settings → Repository secrets):
 
    MEDIA_GENERATION_PYTHON_SHARED_SECRET=<sama dengan MEDIA_GEN_HMAC_SECRET di Render>
    MEDIA_GENERATION_PYTHON_REDIS_URL=rediss://default:gQAAAAAAAj-TAAIgcDI1NDQyMWIxYjk3NWI0YjE5OTFmZjNkNGVkNGMwNTNjYQ@sincere-scorpion-147347.upstash.io:6379
    MEDIA_GENERATION_PYTHON_LOG_LEVEL=info
    MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY=1
    MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY_AUTO=false
    PORT=7860
 
3c. Clone Space & Push Code:
    git clone https://huggingface.co/spaces/<USERNAME>/klass-media-generator
    cd klass-media-generator
    xcopy /E /I C:\Users\user\klass-mobile\media-generator-service\* .
    git add -A
    git commit -m "Initial deploy"
    git push
 
3d. Verifikasi Space:
    - Buka tab Logs di HuggingFace Space
    - Cari: "Chromium sidecar started and ready" ✅
    - Cari: "Redis connected" ✅
    - Cari: "Template registry loaded" ✅
    - Test health: GET https://<USERNAME>-klass-media-generator.hf.space/health
 
STEP 4: UPDATE GATEWAY CONFIG (Render)
───────────────────────────────────────
Buka Render Dashboard → klass-gateway → Environment
 
Tambah/Update env vars:
  MEDIA_GEN_URL=https://<USERNAME>-klass-media-generator.hf.space
  MEDIA_GEN_HMAC_SECRET=<sama dengan MEDIA_GENERATION_PYTHON_SHARED_SECRET>
 
Lalu redeploy gateway.
 
STEP 5: BACKFILL DATA STUCK (lagi)
──────────────────────────────────
Setelah gateway redeploy, jalankan lagi backfill SQL di Step 2
untuk clear semua generations yang stuck 'pending'.
 
STEP 6: TEST DARI FLUTTER APP
─────────────────────────────
1. Buka Flutter app
2. Input prompt: "Buatkan materi pecahan untuk kelas 5 SD"
3. Klik "Enhance Prompt"
4. Jawab/skip clarification
5. Pilih output type: PDF
6. Klik "Generate"
7. Tunggu 30-60 detik
8. Cek: file PDF harusnya ter-download
 
STEP 7: VERIFIKASI LOGS
───────────────────────
Gateway logs (Render):
  ✅ "Step completed: ensure_classified (xxx ms, success)"
  ✅ "Step completed: ensure_generated (xxx ms, success)"
  ✅ "Workflow transitioning to async processing"
  ✅ webhook: "generation_completed" (bukan "failed")
 
HuggingFace logs:
  ✅ "POST /v1/jobs: enqueued job..."
  ✅ "process_generation_job: completed"
  ✅ No "Chromium sidecar is not available" error
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 5: TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════════
 
Jika masih error "COALESCE could not convert type jsonb to json":
  → Gateway belum di-deploy dengan fix terbaru. Redeploy manual.
 
Jika error "Chromium sidecar is not available":
  → HuggingFace Space belum selesai build / sidecar gagal start.
  → Cek HuggingFace logs untuk detail error.
 
Jika error "generation_id_mismatch":
  → Header generation_id tidak sama dengan body. Cek gateway client.
 
Jika error "request_contract_invalid":
  → HMAC secret tidak match. Pastikan MEDIA_GEN_HMAC_SECRET = 
    MEDIA_GENERATION_PYTHON_SHARED_SECRET (nilai yang sama).
 
Jika status stuck "processing" terus:
  → Webhook tidak sampai ke gateway. Cek:
    1. MEDIA_GEN_URL sudah benar?
    2. Gateway port 10000 bisa diakses dari HuggingFace?
    3. Webhook path: /internal/media-generations/webhook
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 6: ENVIRONMENT VARIABLES YANG DIBUTUHKAN
═══════════════════════════════════════════════════════════════════════════════
 
GATEWAY (Render Dashboard → klass-gateway → Environment):
  MEDIA_GEN_URL=https://<USERNAME>-klass-media-generator.hf.space
  MEDIA_GEN_HMAC_SECRET=<shared secret>
  REDIS_URL=rediss://default:gQAAAAAAAj-TAAIgcDI1NDQyMWIxYjk3NWI0YjE5OTFmZjNkNGVkNGMwNTNjYQ@sincere-scorpion-147347.upstash.io:6379
  DATABASE_URL=<Neon PostgreSQL URL>
 
MEDIA-GENERATOR-SERVICE (HuggingFace Space → Settings → Secrets):
  MEDIA_GENERATION_PYTHON_SHARED_SECRET=<shared secret>
  MEDIA_GENERATION_PYTHON_REDIS_URL=rediss://default:gQAAAAAAAj-TAAIgcDI1NDQyMWIxYjk3NWI0YjE5OTFmZjNkNGVkNGMwNTNjYQ@sincere-scorpion-147347.upstash.io:6379
  MEDIA_GENERATION_PYTHON_LOG_LEVEL=info
  MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY=1
  MEDIA_GENERATION_PYTHON_WORKER_CONCURRENCY_AUTO=false
  PORT=7860
 
 
═══════════════════════════════════════════════════════════════════════════════
 SECTION 7: ARSITEKTUR FLOW (Setelah Fix)
═══════════════════════════════════════════════════════════════════════════════
 
Flutter App
    │
    ▼
[Clarification API] ──→ Gateway (Render) ──→ Redis Stream "klass:media-gen"
                                                     │
                                                     ▼
                                            Embedded Worker (Gateway)
                                                     │
                                            ┌────────┴────────┐
                                            ▼                 ▼
                                    ensure_classified    ensure_generated
                                    (Interpret LLM →     (POST /v1/jobs →
                                     Decision → Draft)    Python Service)
                                            │                 │
                                            ▼                 ▼
                                    DB: generation_spec   HuggingFace Space
                                    payload stored         (Media Generator)
                                                                 │
                                                                 ▼
                                                        Chromium Sidecar
                                                        (HTML → PDF)
                                                                 │
                                                                 ▼
                                                        Upload to R2/S3
                                                                 │
                                                                 ▼
                                                        Webhook callback
                                                        → Gateway DB update
                                                                 │
                                                                 ▼
                                                        Flutter polls status
                                                        → Shows "Completed"