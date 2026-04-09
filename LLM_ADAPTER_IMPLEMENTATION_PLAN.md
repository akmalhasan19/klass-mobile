# LLM Adapter Implementation Plan

## Ringkasan

Dokumen ini merinci implementation plan untuk arsitektur `3 deployable` pada fitur `Media Generator` di Klass App.

Target arsitektur baru:

- `backend` Laravel tetap menjadi orchestration layer utama untuk flow `Generate Learning Topics`.
- `media-generator-service` Python tetap fokus untuk rendering artifact `.docx`, `.pdf`, dan `.pptx`.
- Deployable baru `llm-adapter-service` menjadi boundary tunggal untuk kebutuhan LLM seperti interpretation, delivery response, provider switching, rate limiting, caching, dan cost tracking.

Target akhir implementasi:

- Guru tetap mengirim prompt dari Homepage melalui flow `POST /api/media-generations` yang sudah ada.
- Backend tetap memproses lifecycle async media generation melalui queue worker yang sudah ada.
- Backend tidak lagi terhubung langsung ke vendor LLM seperti Gemini atau OpenAI.
- Semua komunikasi LLM diarahkan ke `llm-adapter-service` melalui kontrak internal yang stabil.
- Adapter mendukung multi-provider strategy sejak awal, dengan implementasi awal menggunakan Gemini dan kesiapan pindah ke OpenAI.
- Adapter memiliki Postgres terpisah untuk state operasional seperti cache, rate limiting, cost ledger, dan agregasi usage.
- Backend, frontend, dan Python renderer tetap memakai kontrak domain yang stabil sehingga perubahan vendor LLM tidak memaksa perubahan UI atau publication flow.

## Prinsip Implementasi

- Existing hero prompt UI di Homepage harus tetap dipertahankan sebisa mungkin dan tidak dirombak tanpa kebutuhan kuat.
- Existing flow `topics`, `contents`, `recommended_projects`, dan homepage recommendation harus tetap direuse.
- Orkestrasi bisnis utama tetap berada di backend Laravel.
- Python renderer tetap tidak mengambil keputusan bisnis interpretation atau publication.
- `llm-adapter-service` hanya menjadi boundary provider, observability, cache, quota, dan cost governance.
- Kontrak internal `interpretation` dan `delivery` harus deterministic, versioned, dan tervalidasi.
- Cache, rate limiting, dan cost tracking harus dipisah dari infrastruktur backend.
- State operasional adapter menggunakan Postgres, bukan Redis.
- Provider switching dari Gemini ke OpenAI harus terjadi lewat config adapter, bukan lewat refactor backend atau frontend.

## Keputusan Arsitektur

- [x] Arsitektur target menggunakan 3 deployable: `backend`, `media-generator-service`, dan `llm-adapter-service`.
- [x] `llm-adapter-service` akan menjadi service terpisah, bukan embedded module di backend.
- [x] Scope awal adapter langsung mencakup `interpretation` dan `delivery`.
- [x] Deploy target awal adapter adalah Docker-based Hugging Face Space.
- [x] State store adapter dipisah dari backend dan menggunakan Postgres.
- [x] Backend tetap menjadi source of truth untuk lifecycle, ownership, storage, dan publication.
- [x] Python service tetap hanya fokus pada generation/rendering artifact.
- [x] Provider awal adalah Gemini, namun desain harus siap untuk OpenAI.
- [x] `Generate Learning Topics` di Home Screen tetap masuk ke backend API yang sama dan tidak memanggil adapter secara langsung dari frontend.

## Phase 1 - Freeze Internal Contracts

### 1.1 Freeze Interpretation Contract

- [x] Bekukan shape request `POST /v1/interpret` yang dikirim backend.
- [x] Pastikan field `request_type`, `generation_id`, `model`, `instruction`, dan `input` tetap stabil.
- [x] Pastikan `input.teacher_prompt`, `preferred_output_type`, `subject_context`, dan `sub_subject_context` tetap konsisten.
- [x] Pastikan adapter wajib mengembalikan payload yang lolos validator `MediaPromptInterpretationSchema`.
- [x] Pastikan adapter tidak mengembalikan prose tambahan, markdown fence, atau format non-JSON.

### 1.2 Freeze Delivery Contract

- [x] Bekukan shape request `POST /v1/respond` yang dikirim backend.
- [x] Pastikan request delivery hanya berisi metadata artifact, publication data, preview summary, dan context terkait.
- [x] Pastikan binary mentah atau base64 tidak menjadi bagian mandatory dari flow awal.
- [x] Pastikan adapter wajib mengembalikan payload yang lolos validator `MediaDeliveryResponseSchema`.
- [x] Pastikan response delivery tetap aman digunakan saat provider berganti.

### 1.3 Preserve Backend and Frontend Behavior

- [x] Pastikan endpoint frontend ke backend tetap `POST /api/media-generations` dan `GET /api/media-generations/{id}`.
- [x] Pastikan `MediaGenerationWorkflowService` tetap menjadi orkestrator utama.
- [x] Pastikan `MediaGenerationResource` tidak berubah shape secara breaking bagi frontend.
- [x] Pastikan polling flow di frontend tidak perlu diubah karena perpindahan ke adapter.

## Phase 2 - New Deployable Service Skeleton

### 2.1 Create Service Structure

- [x] Tambahkan folder baru `llm-adapter-service/` di root `klass-mobile`.
- [x] Tambahkan `Dockerfile` untuk runtime adapter.
- [x] Tambahkan `README.md` untuk deployment dan operational notes.
- [x] Tambahkan `requirements.txt` atau dependency manifest yang relevan.
- [x] Tambahkan struktur `app/` untuk router, auth, settings, database, dan provider client.
- [x] Tambahkan struktur `tests/` untuk contract dan behavior tests.

### 2.2 FastAPI Runtime Baseline

- [x] Gunakan pola FastAPI yang konsisten dengan `media-generator-service`.
- [x] Tambahkan app entrypoint utama seperti `app.main:app`.
- [x] Pastikan service mendengarkan `PORT=7860` secara default agar cocok dengan Hugging Face Spaces.
- [x] Pastikan logging terstruktur aktif sejak awal.
- [x] Tambahkan request id pada setiap request untuk traceability.

### 2.3 Health and Readiness Endpoints

- [x] Tambahkan `GET /health`.
- [x] Tambahkan `GET /v1/health`.
- [x] Tambahkan readiness check untuk koneksi Postgres.
- [x] Tambahkan readiness check untuk provider config yang aktif.
- [x] Tambahkan metadata `service_name`, `service_version`, dan status auth readiness.

## Phase 3 - Inter-Service Auth and Security

### 3.1 Signed Request Authentication

- [x] Definisikan shared-secret auth antara backend dan adapter.
- [x] Gunakan timestamp + signature untuk mencegah replay.
- [x] Tambahkan max-age validation untuk request antar-service.
- [x] Pastikan adapter menolak request tanpa signature valid.
- [x] Pastikan backend dapat mengirim request signed ke adapter untuk interpretation dan delivery.

### 3.2 Secret Rotation Strategy

- [x] Tambahkan env secret aktif untuk adapter.
- [x] Tambahkan env secret previous untuk zero-downtime rotation.
- [x] Definisikan prosedur rollout secret baru tanpa memutus job in-flight.
- [x] Tambahkan indikator health untuk jumlah secret yang diterima saat masa rotasi.

### 3.3 Request Trace and Governance

- [x] Pastikan setiap request membawa request id yang konsisten.
- [x] Simpan actor metadata minimum yang aman seperti generation id dan route type.
- [x] Hindari penyimpanan provider API key di backend selain secret auth ke adapter.
- [x] Pastikan adapter memegang provider secret secara eksklusif.

## Phase 4 - Provider Abstraction Layer

### 4.1 Unified Provider Interface

- [x] Buat interface internal provider client yang netral vendor.
- [x] Normalisasi request interpretation ke format internal adapter.
- [x] Normalisasi request delivery ke format internal adapter.
- [x] Normalisasi response provider menjadi raw completion yang dapat divalidasi terhadap schema internal.
- [x] Normalisasi metadata usage seperti tokens, latency, upstream request id, dan finish reason.

### 4.2 Gemini Implementation

- [x] Implementasikan provider Gemini sebagai provider awal.
- [x] Petakan request internal ke format API Gemini.
- [x] Tangani extraction text/content Gemini ke string JSON yang bisa divalidasi.
- [x] Tangani error mapping Gemini ke error class adapter yang stabil.
- [x] Simpan metadata usage dan provider response reference untuk cost tracking.

### 4.3 OpenAI Readiness

- [x] Tambahkan abstraction points agar OpenAI bisa diaktifkan tanpa refactor kontrak adapter.
- [x] Siapkan env placeholders untuk OpenAI walau belum dipakai.
- [x] Definisikan mapping response OpenAI ke normalized adapter shape.
- [x] Pastikan provider switch cukup lewat config active provider.

### 4.4 Provider Routing Policy

- [x] Tentukan provider default untuk interpretation.
- [x] Tentukan provider default untuk delivery.
- [x] Tentukan apakah interpretation dan delivery boleh memakai provider berbeda.
- [x] Tentukan fallback policy bila provider utama down atau rate-limited.

## Phase 5 - Postgres State Layer

### 5.1 Database Topology

- [x] Sediakan Postgres terpisah untuk adapter service.
- [x] Pastikan adapter tidak memakai database backend sebagai state store operasional.
- [x] Tambahkan migration mechanism untuk adapter.
- [x] Tambahkan database settings dan connection pooling yang sesuai untuk Hugging Face deployment.

### 5.2 Cache Tables

- [x] Buat tabel cache untuk response interpretation.
- [x] Buat tabel cache untuk response delivery.
- [x] Definisikan `cache_key` berbasis normalized semantic request.
- [x] Pastikan `generation_id` tidak menjadi bagian cache key utama.
- [x] Simpan `response_payload`, `created_at`, `expires_at`, `hit_count`, dan `last_hit_at`.
- [x] Tambahkan index untuk TTL cleanup dan lookup cepat.

### 5.3 Rate Limit Tables

- [x] Buat tabel rate-limit bucket berbasis provider/model/route.
- [x] Definisikan token bucket atau fixed-window strategy di Postgres.
- [x] Gunakan row locking atau atomic upsert untuk update aman saat multi-replica.
- [x] Tambahkan scope quota global, per provider, per model, dan per route type.
- [x] Tambahkan hard ceiling untuk daily usage atau cost ceiling.

### 5.4 Cost Ledger Tables

- [x] Buat tabel request ledger untuk semua upstream LLM call.
- [x] Simpan request id, generation id, route type, provider, model, latency, retry count, cache hit/miss, dan status akhir.
- [x] Simpan token usage bila provider mengembalikannya.
- [x] Simpan estimated cost per request.
- [x] Simpan error class dan fallback indicator untuk analisis biaya vs kegagalan.

### 5.5 Pricing and Aggregation Tables

- [x] Buat tabel price catalog untuk provider/model pricing.
- [x] Tambahkan mekanisme agregasi harian atau view untuk pelaporan biaya.
- [x] Tambahkan agregasi per route type (`interpret`, `respond`).
- [x] Tambahkan agregasi cache effectiveness dan retry volume.

## Phase 6 - Caching Strategy Without Redis

### 6.1 Cache Key and TTL Policy

- [x] Definisikan cache key yang memasukkan schema version, provider alias, model, instruction, dan normalized input.
- [x] Pisahkan TTL interpretation dan delivery sesuai karakter workload.
- [x] Tentukan rule invalidation ketika schema version naik.
- [x] Tentukan rule invalidation ketika provider/model berubah.

### 6.2 Cache Stampede Protection

- [x] Tambahkan mekanisme in-flight lock menggunakan Postgres advisory lock atau row uniqueness.
- [x] Pastikan hanya satu upstream request berjalan untuk cache key yang sama pada saat yang sama.
- [x] Pastikan request lain dapat menunggu hasil in-flight atau gagal cepat dengan alasan yang jelas.

### 6.3 Cache Cleanup Strategy

- [x] Tambahkan lazy cleanup untuk entri yang expired.
- [x] Tambahkan maintenance task atau endpoint opsional untuk cleanup manual.
- [x] Pastikan cleanup tidak menjadi syarat cron eksternal yang rapuh.

## Phase 7 - Postgres-Based Rate Limiting

### 7.1 Interpretation Rate Limiting

- [x] Tentukan limit per menit dan per jam untuk route interpretation.
- [x] Tambahkan guard sebelum provider call dilakukan.
- [x] Pastikan exceed quota menghasilkan response error yang terstruktur.
- [x] Pastikan retry backend tidak memperburuk limit drift secara tidak terkontrol.

### 7.2 Delivery Rate Limiting

- [x] Tentukan limit terpisah untuk route delivery.
- [x] Pertimbangkan bahwa delivery bisa lebih ringan atau lebih murah daripada interpretation.
- [x] Pastikan delivery route dapat dimatikan sementara tanpa memutus flow backend karena fallback sudah ada.

### 7.3 Budget Enforcement

- [x] Tambahkan daily budget ceiling berbasis cost estimate.
- [x] Tambahkan rule deny atau degrade mode jika budget habis.
- [x] Tambahkan observability agar operator tahu kapan budget mendekati limit.

## Phase 8 - Cost Tracking and Observability

### 8.1 Request Ledger Write Path

- [x] Catat request ledger untuk success path.
- [x] Catat request ledger untuk failure path.
- [x] Catat request ledger untuk cache hit path.
- [x] Catat request ledger untuk fallback path.
- [x] Catat upstream request id jika tersedia.

### 8.2 Usage and Cost Model

- [x] Normalisasi token usage dari Gemini.
- [x] Siapkan field yang kompatibel untuk OpenAI usage model.
- [x] Hitung estimated cost berdasarkan price catalog.
- [x] Bedakan cost aktual provider vs estimated cost internal jika diperlukan.

### 8.3 Operator Visibility

- [x] Tambahkan metrics minimal untuk latency, cache hit ratio, deny rate, dan cost volume.
- [x] Tambahkan endpoint atau query pattern untuk dashboard operasional.
- [x] Pastikan operator dapat melihat provider mana yang aktif untuk interpretation dan delivery.

## Phase 9 - Interpretation Endpoint Implementation

### 9.1 Request Validation

- [x] Validasi `request_type = media_prompt_interpretation`.
- [x] Validasi shape field `input` sesuai kontrak backend.
- [x] Validasi presence `teacher_prompt` dan `preferred_output_type`.
- [x] Validasi bahwa unsupported output type ditolak lebih awal.

### 9.2 Processing Flow

- [x] Terapkan rate-limit check sebelum provider call.
- [x] Cek cache sebelum provider call.
- [x] Jika miss, panggil provider aktif.
- [x] Normalisasi raw provider response menjadi string JSON kandidat.
- [x] Validasi hasil terhadap `MediaPromptInterpretationSchema`.
- [x] Jika valid, simpan cache dan ledger.
- [x] Jika tidak valid, kembalikan response yang membuat backend memicu fallback schema lokal sesuai kontrak sekarang.

### 9.3 Error Handling

- [x] Petakan timeout provider ke error adapter yang eksplisit.
- [x] Petakan auth/provider config failure ke error adapter yang eksplisit.
- [x] Pastikan response gagal tetap cukup informatif untuk audit backend tanpa membocorkan credential.

## Phase 10 - Delivery Endpoint Implementation

### 10.1 Request Validation

- [x] Validasi `request_type = media_delivery_response`.
- [x] Validasi shape `artifact`, `publication`, `preview_summary`, dan context lainnya.
- [x] Pastikan binary/raw file tidak diterima sebagai mandatory input.

### 10.2 Processing Flow

- [x] Terapkan rate-limit check sebelum provider call.
- [x] Cek cache delivery sebelum provider call.
- [x] Jika miss, panggil provider aktif.
- [x] Normalisasi raw provider response ke JSON kandidat.
- [x] Validasi hasil terhadap `MediaDeliveryResponseSchema`.
- [x] Simpan cache dan ledger untuk hasil yang valid.

### 10.3 Fallback Compatibility

- [x] Pastikan adapter dapat mengembalikan failure terstruktur bila delivery gagal.
- [x] Pastikan backend tetap bisa menggunakan fallback lokal yang sudah ada bila adapter unavailable atau response invalid.

## Phase 11 - Backend Integration Changes

### 11.1 Config Refactor

- [x] Refactor `backend/config/services.php` agar interpretation dan delivery mengarah ke adapter service yang sama.
- [x] Tambahkan env baru untuk adapter base URL.
- [x] Tambahkan env baru untuk auth secret adapter.
- [x] Tambahkan env request max age atau auth skew settings.
- [x] Tambahkan env service name/version bila diperlukan untuk observability.

### 11.2 .env Example Update

- [x] Tambahkan env adapter ke `backend/.env.example`.
- [x] Jelaskan hubungan antara backend, adapter, dan python renderer pada comment block env.
- [x] Tambahkan contoh host adapter Hugging Face Space.

### 11.3 Service Layer Update

- [x] Ubah `MediaPromptInterpretationService` agar berbicara ke adapter, bukan ke vendor LLM langsung.
- [x] Ubah `MediaDeliveryResponseService` agar berbicara ke adapter yang sama.
- [x] Pertimbangkan migrasi dari Bearer auth ke signed request auth untuk adapter.
- [x] Pastikan audit payload backend tetap mencatat provider dan model yang dilaporkan adapter.

### 11.4 Non-Breaking Backend Flow

- [x] Pastikan `MediaGenerationWorkflowService` tetap tidak berubah secara domain.
- [x] Pastikan queue worker backend tetap satu mekanisme utama untuk async orchestration.
- [x] Pastikan backend tetap tidak perlu mengetahui detail implementasi Gemini atau OpenAI.

## Phase 12 - Testing and Quality Gates

### 12.1 Adapter Automated Tests

- [x] Tambahkan contract test untuk `/v1/interpret`.
- [x] Tambahkan contract test untuk `/v1/respond`.
- [x] Tambahkan test untuk signed auth success dan failure.
- [x] Tambahkan test untuk cache hit/miss.
- [x] Tambahkan test untuk rate limit deny.
- [x] Tambahkan test untuk ledger write success/failure.
- [x] Tambahkan test untuk provider normalization Gemini.
- [x] Tambahkan test untuk provider switch readiness ke OpenAI.

### 12.2 Backend Test Updates

- [ ] Update `MediaGenerationOrchestrationServiceTest` agar mengunci boundary adapter.
- [ ] Update `MediaGenerationPublicationAndDeliveryTest` agar mengunci boundary adapter.
- [ ] Pastikan backend test tetap tidak mengasumsikan vendor LLM tertentu.
- [ ] Tambahkan test bahwa provider swap tidak memerlukan perubahan di backend contract.

### 12.3 Smoke and Manual Verification

- [ ] Verifikasi adapter `GET /health` dan `GET /v1/health`.
- [ ] Verifikasi adapter dapat reach Postgres eksternal.
- [ ] Verifikasi adapter dapat memanggil Gemini end-to-end.
- [ ] Verifikasi backend dapat reach adapter untuk interpretation.
- [ ] Verifikasi backend dapat reach adapter untuk delivery.
- [ ] Verifikasi worker backend tetap berjalan normal.
- [ ] Verifikasi python renderer tetap menerima generation spec dari backend tanpa perubahan kontrak.
- [ ] Verifikasi submit prompt dari Home Screen tetap menghasilkan artifact, publication, dan final result card.

## Phase 13 - Deployment and Cutover

### 13.1 Adapter Deployment

- [ ] Deploy `llm-adapter-service` sebagai Docker-based Hugging Face Space.
- [ ] Pasang secrets untuk auth adapter dan provider API key.
- [ ] Pasang env untuk Postgres eksternal.
- [ ] Jalankan migration adapter pada environment target.

### 13.2 Backend Cutover

- [ ] Arahkan env interpretation backend ke adapter.
- [ ] Arahkan env delivery backend ke adapter.
- [ ] Restart backend agar config cache memuat setting baru.
- [ ] Verifikasi backend tidak lagi berbicara langsung ke vendor LLM.

### 13.3 Rollout Safety

- [ ] Lakukan smoke test interpretation dulu.
- [ ] Lakukan smoke test delivery sesudah artifact generation stabil.
- [ ] Pantau deny rate, cache hit ratio, dan daily cost sesudah cutover.
- [ ] Siapkan rollback path dengan mengembalikan backend ke LLM endpoint lama jika perlu.

## File dan Area Implementasi yang Terdampak

### Root Workspace

- [x] Tambahkan `llm-adapter-service/` di root `klass-mobile`.
- [x] Tambahkan `README.md` dan `Dockerfile` untuk adapter.

### Backend Laravel

- [x] `backend/config/services.php`
- [x] `backend/.env.example`
- [x] `backend/app/Services/MediaPromptInterpretationService.php`
- [x] `backend/app/Services/MediaDeliveryResponseService.php`
- [x] `backend/tests/Feature/MediaGenerationOrchestrationServiceTest.php`
- [x] `backend/tests/Feature/MediaGenerationPublicationAndDeliveryTest.php`

### New LLM Adapter Service

- [x] App entrypoint/router.
- [x] Auth layer.
- [x] Provider abstraction layer.
- [x] Gemini client.
- [x] OpenAI-ready client abstraction.
- [x] Postgres models/migrations.
- [x] Cache service.
- [x] Rate limiting service.
- [x] Cost tracking service.
- [x] Health checks.
- [x] Tests.

### Existing Python Renderer

- [ ] Tidak perlu perubahan kontrak generation spec kecuali ditemukan kebutuhan baru saat integrasi penuh.
- [ ] Verifikasi deployment pattern dapat direuse untuk adapter service baru.

### Frontend

- [ ] Tidak ada perubahan kontrak mandatory untuk frontend.
- [ ] Verifikasi polling dan result hydration tetap bekerja tanpa perubahan shape response backend.

## Definition of Done

- [ ] `llm-adapter-service` berhasil menjadi deployable ketiga yang terpisah dari backend dan python renderer.
- [ ] Backend tidak lagi memanggil vendor LLM secara langsung.
- [ ] Adapter melayani `interpretation` dan `delivery` dari hari pertama.
- [ ] Adapter mendukung Gemini sebagai provider awal.
- [ ] Adapter siap secara desain untuk provider OpenAI tanpa refactor backend.
- [ ] Adapter memiliki Postgres terpisah untuk cache, rate limiting, dan cost tracking.
- [ ] Rate limiting berjalan tanpa Redis.
- [ ] Cache adapter dapat reuse request semantik yang identik.
- [ ] Cost tracking dapat menunjukkan usage per provider/model/route.
- [ ] Home Screen `Generate Learning Topics` tetap bekerja melalui backend flow yang sama.
- [ ] Publication ke Workspace dan Homepage recommendation feed tetap berjalan.
- [ ] Backend, frontend, dan adapter lulus test utama dan smoke test deployment.

## Out of Scope untuk Fase Awal

- [ ] Mengganti workflow domain media generation dari Laravel ke adapter.
- [ ] Memindahkan publication logic ke adapter.
- [ ] Memindahkan rendering artifact dari Python ke adapter.
- [ ] Generic cross-product AI gateway untuk seluruh fitur AI di luar media generation.
- [ ] Redis-based caching atau Redis-based rate limiting.
- [ ] Dashboard billing penuh untuk end user.
- [ ] Real-time streaming token ke frontend.
- [ ] Binary attachment ke LLM sebagai default flow untuk delivery.