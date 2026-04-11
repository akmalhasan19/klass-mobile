# LLM Adapter Deployment Runbook

Dokumen ini adalah runbook step-by-step untuk deploy `llm-adapter-service` pada arsitektur `3 deployable` Klass App.

Dokumen ini ditujukan agar proses deployment tidak hilang, bisa diulang, dan bisa dipakai untuk cutover backend ke adapter secara aman.

## Target Deploy Saat Ini

- Adapter Space: `https://isanzy1-klass-mobile-llm-adapter.hf.space`
- Python renderer Space: `https://isanzy1-klass-mobile-python-service.hf.space`
- Folder source adapter: `llm-adapter-service/`
- Folder backend untuk smoke test dan cutover: `backend/`

## Prinsip Penting

- `llm-adapter-service` tidak memakai file `.env` internal yang dibaca otomatis saat runtime deploy.
- Semua konfigurasi deploy adapter harus diisi lewat Hugging Face Space `Settings -> Variables and secrets`.
- Database adapter harus database Postgres terpisah dari backend Laravel.
- `LLM_ADAPTER_DATABASE_URL` harus berupa Postgres DSN, bukan Supabase `Project URL` HTTP.
- `LLM_ADAPTER_SHARED_SECRET` di adapter harus sama persis dengan `MEDIA_GENERATION_LLM_ADAPTER_SHARED_SECRET` di backend Laravel.
- Provider API key seperti Gemini atau OpenAI hanya boleh hidup di adapter, bukan di backend.

## Step 1 - Siapkan Credential dan Nilai Konfigurasi

Siapkan nilai berikut sebelum membuka Hugging Face Space.

### 1.1 Database Adapter dari Supabase

Yang dibutuhkan adapter adalah satu Postgres connection string utuh:

- `LLM_ADAPTER_DATABASE_URL`

Nilai ini diambil dari Supabase Dashboard:

1. Buka project Supabase khusus untuk adapter.
2. Masuk ke `Project Settings`.
3. Buka `Database`.
4. Cari bagian `Connection string`.
5. Copy Postgres DSN, bukan `Project URL` yang bentuknya `https://<project>.supabase.co`.

Contoh bentuk yang benar:

```text
postgresql://USER:PASSWORD@HOST:PORT/postgres?sslmode=require
```

Contoh pola yang umum dari Supabase:

```text
postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres?sslmode=require
```

Catatan:

- Gunakan connection string yang diberikan langsung oleh Supabase.
- Simpan ini sebagai `Secret`, bukan `Variable`, karena mengandung password.
- Jika memungkinkan, gunakan connection string yang direkomendasikan Supabase untuk aplikasi server atau session pooler.

### 1.2 Shared Secret Antar-Service

Siapkan satu secret untuk backend Laravel dan adapter:

- `LLM_ADAPTER_SHARED_SECRET` pada adapter
- `MEDIA_GENERATION_LLM_ADAPTER_SHARED_SECRET` pada backend

Keduanya harus identik.

### 1.3 Gemini API Key

Siapkan:

- `LLM_ADAPTER_GEMINI_API_KEY`

Tanpa nilai ini, adapter health akan tetap `503` karena provider route tidak siap.

## Step 2 - Buka atau Buat Hugging Face Space Adapter

Gunakan Docker Space untuk adapter.

1. Buka Space adapter di Hugging Face.
2. Pastikan Space memakai mode `Docker`.
3. Pastikan source code yang dideploy adalah folder `llm-adapter-service/`.
4. Pastikan image menjalankan command default dari Dockerfile adapter.

Referensi runtime saat ini:

```dockerfile
CMD ["sh", "-lc", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
```

## Step 3 - Isi Hugging Face Space Secrets

Masuk ke `Settings -> Variables and secrets` pada Space adapter.

Isi bagian `Secrets` dengan nilai berikut:

- `LLM_ADAPTER_DATABASE_URL`
- `LLM_ADAPTER_GEMINI_API_KEY`
- `LLM_ADAPTER_SHARED_SECRET`

Opsional:

- `LLM_ADAPTER_SHARED_SECRET_PREVIOUS`
- `LLM_ADAPTER_OPENAI_API_KEY`

## Step 4 - Isi Hugging Face Space Variables

Isi bagian `Variables` minimal dengan baseline berikut.

### 4.1 Minimum Baseline

- `LLM_ADAPTER_DATABASE_AUTO_MIGRATE=true`
- `LLM_ADAPTER_ACTIVE_INTERPRETATION_PROVIDER=gemini`
- `LLM_ADAPTER_ACTIVE_DELIVERY_PROVIDER=gemini`
- `LLM_ADAPTER_SERVICE_NAME=klass-llm-adapter`
- `LLM_ADAPTER_SERVICE_VERSION=0.1.0`
- `PORT=7860`

### 4.2 Baseline yang Disarankan

- `LLM_ADAPTER_DATABASE_CONNECT_TIMEOUT_SECONDS=3`
- `LLM_ADAPTER_DATABASE_POOL_MIN_SIZE=1`
- `LLM_ADAPTER_DATABASE_POOL_MAX_SIZE=5`
- `LLM_ADAPTER_DATABASE_POOL_MAX_IDLE_SECONDS=300`
- `LLM_ADAPTER_UPSTREAM_TIMEOUT_SECONDS=30`
- `LLM_ADAPTER_REQUEST_MAX_AGE_SECONDS=300`
- `LLM_ADAPTER_CACHE_SCHEMA_VERSION=llm_adapter_cache.v1`
- `LLM_ADAPTER_INTERPRETATION_CACHE_TTL_SECONDS=86400`
- `LLM_ADAPTER_DELIVERY_CACHE_TTL_SECONDS=21600`
- `LLM_ADAPTER_CACHE_STAMPEDE_POLL_INTERVAL_MS=100`
- `LLM_ADAPTER_CACHE_STAMPEDE_WAIT_TIMEOUT_MS=1500`
- `LLM_ADAPTER_CACHE_CLEANUP_BATCH_SIZE=100`
- `LLM_ADAPTER_CACHE_LAZY_CLEANUP_INTERVAL_SECONDS=60`
- `LLM_ADAPTER_ALLOW_ROUTE_PROVIDER_DIVERGENCE=true`
- `LLM_ADAPTER_PROVIDER_FALLBACK_ERROR_CODES=provider_timeout,provider_connection_failed,provider_rate_limited,provider_unavailable`
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_MINUTE=30`
- `LLM_ADAPTER_INTERPRETATION_REQUESTS_PER_HOUR=600`
- `LLM_ADAPTER_INTERPRETATION_DAILY_BUDGET_USD=25.00`
- `LLM_ADAPTER_INTERPRETATION_DEFAULT_ESTIMATED_COST_USD=0.025`
- `LLM_ADAPTER_INTERPRETATION_EXHAUSTED_ACTION=deny`
- `LLM_ADAPTER_DELIVERY_ROUTE_ENABLED=true`
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_MINUTE=60`
- `LLM_ADAPTER_DELIVERY_REQUESTS_PER_HOUR=1200`
- `LLM_ADAPTER_DELIVERY_DAILY_BUDGET_USD=10.00`
- `LLM_ADAPTER_DELIVERY_DEFAULT_ESTIMATED_COST_USD=0.010`
- `LLM_ADAPTER_DELIVERY_EXHAUSTED_ACTION=degrade`
- `LLM_ADAPTER_BUDGET_WARNING_RATIO=0.80`
- `LLM_ADAPTER_GEMINI_BASE_URL=https://generativelanguage.googleapis.com`
- `LLM_ADAPTER_GEMINI_API_VERSION=v1beta`
- `LLM_ADAPTER_GEMINI_INTERPRET_MODEL=gemini-2.0-flash`
- `LLM_ADAPTER_GEMINI_DELIVERY_MODEL=gemini-2.0-flash`
- `LLM_ADAPTER_LOG_LEVEL=info`

### 4.3 Optional OpenAI Readiness

- `LLM_ADAPTER_INTERPRETATION_FALLBACK_PROVIDER=openai`
- `LLM_ADAPTER_DELIVERY_FALLBACK_PROVIDER=openai`
- `LLM_ADAPTER_OPENAI_BASE_URL=https://api.openai.com`
- `LLM_ADAPTER_OPENAI_INTERPRET_MODEL=gpt-5.4`
- `LLM_ADAPTER_OPENAI_DELIVERY_MODEL=gpt-5.4`
- `LLM_ADAPTER_OPENAI_ORGANIZATION=`
- `LLM_ADAPTER_OPENAI_PROJECT=`

Catatan:

- Untuk deploy pertama, `LLM_ADAPTER_DATABASE_AUTO_MIGRATE=true` paling praktis karena migration akan dicoba saat startup.
- Setelah migration stabil dan semua environment sudah matang, nilai ini boleh dipertahankan atau diubah ke `false` bila ingin startup lebih konservatif.

## Step 5 - Trigger Deploy atau Restart Space

Setelah `Secrets` dan `Variables` terisi:

1. Simpan semua env.
2. Trigger rebuild atau restart Space.
3. Tunggu container boot selesai.
4. Periksa logs Space bila startup gagal.

## Step 6 - Verifikasi Health Adapter

Setelah Space selesai boot, cek health endpoint berikut:

```bash
curl -fsS https://isanzy1-klass-mobile-llm-adapter.hf.space/health
curl -fsS https://isanzy1-klass-mobile-llm-adapter.hf.space/v1/health
```

Expected:

- HTTP `200`
- `schema_version=llm_adapter_health.v1`
- `status=ready`
- `ready=true`
- `dependencies.postgres.ready=true`
- `dependencies.providers.interpretation.provider=gemini`
- `dependencies.providers.interpretation.ready=true`
- `dependencies.providers.delivery.provider=gemini`
- `dependencies.providers.delivery.ready=true`
- `auth.ready=true`

Kalau masih `503`, cek body response. Error yang paling umum:

- `database_url_missing`: `LLM_ADAPTER_DATABASE_URL` belum terisi
- `database_unreachable`: DSN salah, password salah, atau host tidak bisa diakses
- `provider_config_missing`: `LLM_ADAPTER_GEMINI_API_KEY` belum terisi
- `auth.configured=false`: `LLM_ADAPTER_SHARED_SECRET` belum terisi

## Step 7 - Verifikasi Python Service Tetap Sehat

Sebelum cutover backend, pastikan Python renderer tetap sehat:

```bash
curl -fsS https://isanzy1-klass-mobile-python-service.hf.space/health
curl -fsS https://isanzy1-klass-mobile-python-service.hf.space/v1/health
```

Expected:

- HTTP `200`
- `status=ok`
- `supported_formats` berisi `docx`, `pdf`, `pptx`
- `auth.configured=true`

## Step 8 - Cutover Backend ke Adapter Live

Setelah adapter sehat, isi env backend deployment dengan nilai berikut:

```text
MEDIA_GENERATION_LLM_ADAPTER_BASE_URL=https://isanzy1-klass-mobile-llm-adapter.hf.space
MEDIA_GENERATION_LLM_ADAPTER_HEALTH_PATH=/v1/health
MEDIA_GENERATION_LLM_ADAPTER_SHARED_SECRET=<sama dengan LLM_ADAPTER_SHARED_SECRET>
MEDIA_GENERATION_INTERPRETER_PROVIDER=llm-adapter
MEDIA_GENERATION_INTERPRETER_MODEL=adapter-managed
MEDIA_GENERATION_DELIVERY_PROVIDER=llm-adapter
MEDIA_GENERATION_DELIVERY_MODEL=adapter-managed
MEDIA_GENERATION_PYTHON_BASE_URL=https://isanzy1-klass-mobile-python-service.hf.space
```

Jika backend memakai config cache atau worker yang sudah lama hidup:

1. Update env deployment backend.
2. Restart backend application.
3. Restart queue worker.
4. Pastikan config runtime memuat env terbaru.

## Step 9 - Jalankan Smoke Test dari Backend

Setelah backend diarahkan ke adapter live, jalankan dari folder `backend/`:

```bash
php artisan media-generation:smoke-llm-adapter
php artisan media-generation:smoke-llm-adapter --exercise-routes --expect-provider=gemini
php artisan media-generation:smoke-python-service
```

Expected:

- `media-generation:smoke-llm-adapter` lolos
- `media-generation:smoke-llm-adapter --exercise-routes --expect-provider=gemini` lolos
- `media-generation:smoke-python-service` lolos

Interpretasi failure yang umum:

- Health lolos, route exercise gagal `401` atau `403`: shared secret backend dan adapter tidak sama
- Health lolos, route exercise gagal `502`: provider hidup tapi contract response atau upstream Gemini masih bermasalah
- Python smoke gagal: backend belum diarahkan ke host Python renderer yang benar atau secret Python mismatch

## Step 10 - Jalankan End-to-End Manual Verification

Setelah smoke test service boundary lolos:

1. Login sebagai teacher/guru.
2. Submit prompt dari section `Generate Learning Topics`.
3. Pastikan record `media_generations` dibuat.
4. Pastikan status berjalan `queued -> interpreting -> classified -> generating -> uploading -> publishing -> completed`.
5. Pastikan `interpretation_payload`, `generation_spec_payload`, dan `delivery_payload` tersimpan.
6. Pastikan Python renderer menghasilkan file final.
7. Pastikan artifact ter-upload ke storage dan thumbnail tersedia bila format mendukung.
8. Pastikan hasil masuk ke Workspace.
9. Pastikan hasil masuk ke Homepage recommendation feed sebagai item `ai_generated`.
10. Pastikan teacher bisa `download`, `open`, dan `share` hasil file.

Untuk langkah lebih detail, lihat juga `backend/MEDIA_GENERATION_MANUAL_VERIFICATION.md`.

## Step 11 - Pantau Operasional Setelah Cutover

Setelah adapter live dan backend sudah diarahkan:

1. Pantau health endpoint adapter.
2. Pantau `GET /ops/summary` atau `GET /v1/ops/summary`.
3. Pantau deny rate, cache hit ratio, fallback volume, dan daily cost.
4. Pantau log backend dan log adapter untuk request id yang sama bila ada incident.

Endpoint ops:

```bash
curl -fsS https://isanzy1-klass-mobile-llm-adapter.hf.space/ops/summary
curl -fsS https://isanzy1-klass-mobile-llm-adapter.hf.space/v1/ops/summary
```

## Step 12 - Rollout Safety

Urutan rollout yang aman:

1. Pastikan adapter health sudah `ready`.
2. Lakukan smoke test interpretation dulu.
3. Lakukan smoke test delivery sesudah artifact generation stabil.
4. Jalankan satu atau dua prompt guru yang representatif untuk verifikasi end-to-end.
5. Pantau ops summary dan logs sesudah traffic mulai masuk.

## Step 13 - Rollback Plan yang Aman

Rollback yang aman untuk kode saat ini adalah mengembalikan backend ke adapter deployment yang masih sehat atau menahan cutover sampai adapter live sehat.

Catatan penting:

- Kode backend saat ini mengharapkan kontrak adapter untuk interpretation dan delivery.
- Jangan arahkan backend langsung ke raw vendor endpoint Gemini atau OpenAI kecuali backend code dan contract juga direvert ke versi lama yang kompatibel.

Rollback praktis:

1. Ubah `MEDIA_GENERATION_LLM_ADAPTER_BASE_URL` backend ke deployment adapter sebelumnya yang sehat, bila ada.
2. Restart backend dan queue worker.
3. Jalankan ulang smoke test backend.

## Checklist Singkat

Gunakan checklist ini saat deploy nyata.

- [ ] Supabase database adapter sudah dibuat
- [ ] `LLM_ADAPTER_DATABASE_URL` sudah diisi di Hugging Face Space sebagai secret
- [ ] `LLM_ADAPTER_GEMINI_API_KEY` sudah diisi di Hugging Face Space sebagai secret
- [ ] `LLM_ADAPTER_SHARED_SECRET` sudah diisi di Hugging Face Space sebagai secret
- [ ] `LLM_ADAPTER_DATABASE_AUTO_MIGRATE=true` sudah diset untuk first boot
- [ ] Adapter health `GET /health` sudah `200`
- [ ] Adapter health `GET /v1/health` sudah `200`
- [ ] Backend env sudah diarahkan ke adapter live
- [ ] Shared secret backend sama persis dengan shared secret adapter
- [ ] `php artisan media-generation:smoke-llm-adapter` lolos
- [ ] `php artisan media-generation:smoke-llm-adapter --exercise-routes --expect-provider=gemini` lolos
- [ ] `php artisan media-generation:smoke-python-service` lolos
- [ ] Manual end-to-end flow teacher lolos
