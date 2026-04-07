# Media Generator Implementation Plan

## Ringkasan

Dokumen ini merinci implementation plan untuk fitur `Media Generator` di Klass App yang berjalan saat `user as Teacher/Guru` mengisi prompt pada prompt input container di section `Generate Learning Topics`.

Target akhir implementasi:

- Guru mengirim prompt dari Homepage dan sistem memprosesnya sebagai intent pembuatan media pembelajaran.
- LLM memahami prompt guru secara mendalam dan menghasilkan JSON terstruktur, versioned, dan tervalidasi.
- Backend Klass App membaca JSON tersebut untuk menentukan langkah sistem berikutnya.
- Sistem memilih tipe output terbaik secara otomatis (`.docx`, `.pdf`, atau `.pptx`) dengan opsi override dari guru.
- Sistem memanggil Python service terpisah yang me-route request ke file generator khusus sesuai tipe output.
- File hasil di-upload ke storage resmi aplikasi, diberi thumbnail bila memungkinkan, lalu dipublikasikan ke Workspace dan Homepage recommendation feed.
- Sistem memberi respons hasil ke guru melalui kartu hasil di aplikasi, lengkap dengan file yang bisa di-download, dibuka, atau dibagikan.

## Prinsip Implementasi

- Existing hero prompt UI di Homepage harus tetap dipertahankan sebisa mungkin dan tidak dirombak tanpa kebutuhan kuat.
- Existing flow `topics`, `contents`, `recommended_projects`, dan homepage recommendation harus direuse, bukan diganti total.
- LLM dipakai untuk interpretasi intent dan penyusunan respons akhir, bukan sebagai tempat utama penyimpanan state proses.
- Orkestrasi utama harus tetap berada di backend Laravel agar auditability, ownership, storage, dan publication flow tetap konsisten.
- Proses pembuatan file harus asynchronous untuk menghindari timeout dan memberi UX progress yang jelas.
- Python generator harus dipisah dari container Laravel karena dependency dokumen cenderung berat dan deployment backend saat ini sengaja lean.
- Semua kontrak JSON, lifecycle status, dan error classes harus deterministic, versioned, dan mudah divalidasi.

## Keputusan Arsitektur

- [x] Mode proses: gunakan async job + polling, bukan synchronous request tunggal.
- [ ] Pemilihan tipe file: default `auto`, namun guru dapat override ke `docx`, `pdf`, atau `pptx`.
- [ ] Delivery hasil: tampilkan kartu hasil di app dan publish hasil ke Workspace serta Homepage recommendation feed.
- [ ] Arsitektur generator: gunakan Python service terpisah, bukan embed Python langsung ke container Laravel.
- [ ] Scope fase awal: hanya mendukung `.docx`, `.pdf`, dan `.pptx`.
- [ ] LLM final response menggunakan metadata, preview summary, dan file URL; raw binary attachment ke LLM hanya opsional untuk fase lanjutan.

## Phase 1 - Contract dan Lifecycle Lock

### 1.1 Finalisasi Lifecycle Status

- [x] Definisikan state machine utama untuk media generation.
- [x] Finalisasi status minimum: `queued`, `interpreting`, `classified`, `generating`, `uploading`, `publishing`, `completed`, `failed`.
- [x] Tentukan apakah status `cancelled` perlu disiapkan sejak fase awal.
- [x] Tentukan terminal states yang valid dan behavior retry pada masing-masing status.
- [ ] Pastikan frontend, backend, dan Python service mengacu ke lifecycle yang sama.

### 1.2 Finalisasi Prompt Understanding JSON Schema

- [x] Definisikan schema versioned untuk JSON hasil interpretasi LLM.
- [x] Tetapkan field wajib seperti `schema_version`, `teacher_prompt`, `language`, `teacher_intent`, `learning_objectives`, `constraints`, `output_type_candidates`, `resolved_output_type_reasoning`, dan `document_blueprint`.
- [x] Tetapkan field konteks seperti `subject_context`, `sub_subject_context`, `target_audience`, dan `requested_media_characteristics`.
- [x] Tambahkan field untuk `assets`, `assessment_or_activity_blocks`, `teacher_delivery_summary`, dan `confidence`.
- [x] Pastikan prompt ke LLM memaksa output JSON only tanpa prose tambahan.
- [x] Tentukan fallback bila JSON dari LLM invalid atau tidak sesuai schema.

### 1.3 Finalisasi Generation Spec Contract

- [x] Pisahkan `interpretation_payload` dari `generation_spec_payload`.
- [x] Definisikan generation spec sebagai kontrak normalized yang akan dikirim ke Python service.
- [x] Pastikan generation spec tidak bergantung pada raw prompt mentah lagi.
- [x] Tentukan field wajib untuk renderer seperti `title`, `sections`, `layout_hints`, `style_hints`, `page_or_slide_structure`, dan `export_format`.
- [x] Tetapkan format metadata output yang harus dikembalikan oleh Python service.

## Phase 2 - Persistence dan Publication Model

### 2.1 Entity Media Generation Khusus

- [x] Tambahkan tabel `media_generations` sebagai persistence utama untuk state async.
- [x] Simpan relasi `teacher_id`, `topic_id`, `content_id`, dan `recommended_project_id` bila sudah dipublikasikan.
- [x] Simpan `raw_prompt`, `preferred_output_type`, `resolved_output_type`, `status`, dan provider/model metadata.
- [x] Simpan `interpretation_payload`, `generation_spec_payload`, `delivery_payload`, dan `generator_service_response`.
- [x] Simpan `storage_path`, `file_url`, `thumbnail_url`, `mime_type`, `error_code`, dan `error_message`.
- [x] Tambahkan indeks yang diperlukan untuk status lookup, ownership, dan recency listing.

### 2.2 Publication ke Domain Model yang Sudah Ada

- [x] Finalisasi strategi publish hasil ke `topics` untuk Workspace visibility.
- [x] Buat `contents` row yang merepresentasikan media hasil generation.
- [x] Gunakan `contents.type = brief` untuk fase awal bila belum ada content type baru yang benar-benar dibutuhkan.
- [x] Simpan `media_url` pada content agar file bisa direuse oleh UI yang sudah ada.
- [x] Buat `recommended_projects` row dengan `source_type = ai_generated` agar hasil masuk ke Homepage feed.
- [x] Pastikan metadata penting disimpan di `source_payload` dan/atau `contents.data`.

### 2.3 Idempotency dan Duplicate Protection

- [x] Tentukan job key atau idempotency strategy per media generation.
- [x] Pastikan retry worker tidak membuat Topic, Content, atau RecommendedProject ganda.
- [x] Tambahkan guard sebelum publication jika entity target sudah terbentuk.
- [x] Definisikan rule duplicate handling bila guru men-submit prompt identik beberapa kali.

## Phase 3 - Backend API Surface

### 3.1 Teacher-Only Media Generation API

- [x] Tambahkan endpoint `POST /api/media-generations` untuk submit prompt generation.
- [x] Tambahkan endpoint `GET /api/media-generations/{id}` untuk polling status.
- [ ] Pertimbangkan endpoint `GET /api/media-generations` untuk history guru pada fase berikutnya.
- [x] Batasi endpoint hanya untuk role teacher/guru.
- [x] Pastikan ownership check diterapkan saat teacher mengambil detail generation miliknya.

### 3.2 Request Validation dan Response Contract

- [x] Definisikan request validation untuk `prompt`, `preferred_output_type`, `subject_id`, dan `sub_subject_id`.
- [x] Pastikan `preferred_output_type` menerima `auto`, `docx`, `pdf`, dan `pptx`.
- [x] Kembalikan `202 Accepted` untuk create request.
- [x] Kembalikan payload status yang cukup untuk immediate polling.
- [x] Tetapkan response schema yang konsisten untuk success, in-progress, dan failed states.

### 3.3 Error Contract

- [x] Definisikan error code yang stabil seperti `validation_failed`, `llm_contract_failed`, `python_service_unavailable`, `artifact_invalid`, `upload_failed`, dan `publication_failed`.
- [x] Pastikan frontend bisa menampilkan pesan retry yang bermakna tanpa membaca stack trace backend.
- [x] Tentukan error fields yang aman diekspos ke client.

## Phase 4 - Backend Orchestration Services

### 4.1 Prompt Interpretation Layer

- [x] Tambahkan `MediaPromptInterpretationService` untuk memanggil LLM pertama.
- [x] Validasi JSON hasil interpretasi sebelum melanjutkan ke tahap berikutnya.
- [x] Simpan raw response dan normalized response untuk audit seperlunya.
- [x] Definisikan fallback behavior bila LLM mengembalikan struktur parsial.

### 4.2 Output Type Resolution Layer

- [x] Tambahkan `MediaGenerationDecisionService` untuk memilih output final.
- [x] Terapkan prioritas override teacher di atas auto-classification bila override diberikan.
- [x] Tentukan rule deterministic untuk memilih antara `docx`, `pdf`, dan `pptx`.
- [x] Simpan alasan resolusi output untuk debugging dan observability.

### 4.3 Python Client Layer

- [x] Tambahkan `PythonMediaGeneratorClient` untuk memanggil Python service.
- [x] Gunakan authentication secret atau signed request antar-service.
- [x] Tentukan timeout, retry policy, dan failure classification untuk koneksi ke Python service.
- [x] Pastikan request payload yang dikirim ke Python adalah generation spec yang sudah dinormalisasi.

### 4.4 Publication Layer

- [x] Tambahkan `MediaPublicationService` untuk upload file, generate thumbnail, dan publish entity hasil.
- [x] Reuse `FileUploadService` untuk upload artifact final ke kategori `materials`.
- [x] Reuse `ThumbnailGeneratorService` untuk membuat preview bila format mendukung.
- [x] Publish Topic, Content, dan RecommendedProject dalam urutan yang aman.
- [x] Tentukan rollback atau compensating strategy bila publish gagal di tengah jalan.

### 4.5 Final Delivery Response Layer

- [x] Tambahkan `MediaDeliveryResponseService` untuk menyusun respons akhir bagi guru.
- [x] Gunakan LLM kedua hanya setelah artifact final tersedia.
- [x] Kirim metadata hasil, preview summary, dan file URL ke LLM, bukan binary mentah sebagai default flow.
- [x] Simpan delivery payload final agar bisa dipakai ulang oleh frontend.

## Phase 5 - Async Jobs dan Queue Execution

### 5.1 Job Orchestration

- [x] Tambahkan job utama seperti `ProcessMediaGenerationJob`.
- [x] Pastikan job mengubah status sesuai lifecycle secara berurutan.
- [x] Pisahkan step-step berat ke service layer agar job tetap tipis dan mudah dites.
- [x] Pastikan job aman di-retry tanpa menimbulkan duplikasi publication.

### 5.2 Queue Infrastructure

- [x] Tambahkan proses queue worker di supervisor backend.
- [x] Pastikan runtime environment menyediakan konfigurasi queue yang benar.
- [x] Tentukan concurrency, timeout, dan retry count yang aman untuk generation job.
- [x] Pastikan failure tidak menjatuhkan web request utama.

### 5.3 Observability dan Audit Trail

- [x] Log perubahan status generation secara terstruktur.
- [x] Catat model/provider LLM yang dipakai per generation.
- [x] Catat resolved output type, durasi proses, dan error class.
- [x] Pastikan audit trail cukup untuk debugging tanpa membocorkan data sensitif.

## Phase 6 - Python Media Generator Service

### 6.1 Arsitektur Service Python

- [x] Buat Python service terpisah dengan API yang tipis dan fokus.
- [x] Tambahkan router/entrypoint yang menerima generation spec dari Laravel.
- [x] Pastikan Python service tidak mengambil keputusan bisnis utama yang seharusnya milik Laravel.
- [x] Definisikan health check endpoint untuk deployment smoke test.

### 6.2 DOCX Generator

- [x] Buat file Python khusus untuk generator `.docx`.
- [x] Pastikan generator menerima generation spec terstruktur, bukan prompt mentah.
- [x] Tentukan library Python yang akan dipakai untuk pembuatan `.docx`.
- [x] Pastikan output metadata minimal memuat title, extension, mime type, dan page count bila tersedia.

### 6.3 PDF Generator

- [x] Buat file Python khusus untuk generator `.pdf`.
- [x] Tentukan apakah PDF dihasilkan langsung atau melalui intermediate document model.
- [x] Pastikan styling dasar dan layout hasil stabil untuk materi pembelajaran.
- [x] Kembalikan metadata yang diperlukan untuk preview dan thumbnail flow.

### 6.4 PPTX Generator

- [x] Buat file Python khusus untuk generator `.pptx`.
- [x] Pastikan generator mendukung struktur slide yang berasal dari generation spec.
- [x] Definisikan pendekatan layout, title slide, content slide, dan optional assessment slide.
- [x] Kembalikan metadata minimal termasuk jumlah slide.

### 6.5 Response Contract ke Laravel

- [x] Definisikan response sukses dari Python service.
- [x] Definisikan response gagal yang terstruktur dan mudah dipetakan ke error code Laravel.
- [x] Tentukan bagaimana artifact dikirim balik: path lokal sementara, byte stream, atau upload token.
- [x] Finalisasi format metadata yang wajib dikonsumsi backend Laravel.

## Phase 7 - Storage, File Validation, dan Thumbnailing

### 7.1 Artifact Storage

- [x] Upload artifact final ke storage Supabase via `FileUploadService`.
- [x] Gunakan kategori `materials` untuk file generator.
- [x] Pastikan filename strategy aman terhadap collision.
- [x] Simpan public URL hasil upload di `media_generations`, `contents`, dan `recommended_projects`.

### 7.2 Artifact Validation

- [x] Validasi bahwa file final benar-benar sesuai dengan extension yang diharapkan.
- [x] Validasi mime type hasil generator sebelum upload.
- [x] Pastikan file tidak kosong atau corrupt sebelum dipublikasikan.
- [x] Tentukan fallback jika artifact valid untuk disimpan tetapi gagal dipreview.

### 7.3 Thumbnail Strategy

- [x] Reuse `ThumbnailGeneratorService` untuk `.pdf`, `.docx`, dan `.pptx`.
- [x] Pastikan temp file dibersihkan setelah thumbnail berhasil/gagal dibuat.
- [x] Simpan thumbnail URL untuk kebutuhan Workspace card dan Homepage feed bila tersedia.
- [x] Tentukan fallback visual saat thumbnail tidak bisa dihasilkan.

## Phase 8 - Frontend Teacher Flow

### 8.1 Submit Flow dari Home Hero

- [x] Ganti stub `debugPrint('Prompt submitted: ...')` pada hero prompt dengan call ke API media generation.
- [x] Pertahankan `PromptInputWidget` sebagai input utama.
- [x] Pastikan teacher harus login sebelum submit generation request.
- [x] Disable submit selama request awal sedang diproses bila diperlukan.

### 8.2 Frontend State Management

- [x] Tambahkan service atau provider khusus untuk media generation.
- [x] Pisahkan state generation dari `ProjectService` dan `HomeService` agar tanggung jawab tetap jelas.
- [x] Simpan generation ID untuk keperluan polling.
- [x] Tambahkan state untuk `loading`, `in_progress`, `success`, dan `error`.

### 8.3 Polling dan Result Hydration

- [x] Tambahkan polling status generation sampai terminal state.
- [x] Tentukan interval polling yang aman terhadap backend load.
- [x] Hentikan polling saat screen dibuang atau status sudah terminal.
- [x] Hydrate result card dengan delivery payload final dari backend.

### 8.4 Teacher Result Card UX

- [ ] Tampilkan progress steps seperti `understanding prompt`, `deciding format`, `generating file`, dan `publishing result`.
- [ ] Tampilkan hasil akhir sebagai kartu dengan CTA `download`, `open`, dan `share`.
- [ ] Tampilkan ringkasan AI yang menjelaskan file yang telah dibuat.
- [ ] Tampilkan error state yang jelas bila generation gagal.
- [ ] Pertimbangkan reuse visual pattern dari success screen yang sudah ada bila sesuai.

### 8.5 Feed dan Workspace Refresh

- [ ] Refresh `ProjectService` setelah publish sukses agar Workspace langsung menampilkan hasil.
- [ ] Refresh `HomeService` setelah publish sukses agar Homepage recommendation feed ikut terbarui.
- [ ] Pastikan hasil baru bisa terlihat tanpa app restart.

## Phase 9 - Security, Governance, dan Deployment

### 9.1 Access Control

- [ ] Pastikan hanya teacher yang bisa membuat media generation.
- [ ] Pastikan teacher hanya bisa melihat generation miliknya sendiri.
- [ ] Pastikan publication ownership mengarah ke teacher yang benar.

### 9.2 Inter-Service Security

- [ ] Lindungi komunikasi Laravel ke Python service dengan secret atau signature.
- [ ] Pastikan endpoint Python tidak terbuka bebas tanpa autentikasi.
- [ ] Tentukan strategi rotasi credential antar-service.

### 9.3 Deployment Readiness

- [ ] Tambahkan konfigurasi environment untuk base URL Python service, auth secret, timeout, dan retry.
- [ ] Tambahkan queue worker ke `supervisord.conf` backend.
- [ ] Pastikan perubahan deployment tidak melanggar constraint image backend yang ada.
- [ ] Tambahkan smoke test untuk memastikan Laravel dapat reach Python service.

## Phase 10 - Testing dan Quality Gates

### 10.1 Backend Automated Tests

- [ ] Tambahkan feature test untuk create media generation request.
- [ ] Tambahkan feature test untuk polling status generation.
- [ ] Tambahkan unit test untuk output type resolution.
- [ ] Tambahkan unit test untuk schema validation hasil interpretasi LLM.
- [ ] Tambahkan test untuk publication ke Topic, Content, dan RecommendedProject.
- [ ] Tambahkan test untuk failure path Python service, upload failure, dan publication failure.

### 10.2 Frontend Tests

- [ ] Tambahkan widget test untuk submit flow dari hero prompt.
- [ ] Tambahkan widget test untuk loading/progress/result/error states.
- [ ] Tambahkan test untuk refresh Workspace dan Homepage setelah generation sukses.
- [ ] Pastikan flow teacher tidak merusak UI role lain.

### 10.3 Manual End-to-End Verification

- [ ] Login sebagai teacher/guru.
- [ ] Submit prompt dari section `Generate Learning Topics`.
- [ ] Verifikasi backend membuat record `media_generations`.
- [ ] Verifikasi LLM menghasilkan JSON interpretasi yang valid.
- [ ] Verifikasi sistem memilih output type yang benar atau mengikuti override teacher.
- [ ] Verifikasi Python service menghasilkan file yang sesuai.
- [ ] Verifikasi artifact ter-upload ke storage dan thumbnail dibuat bila memungkinkan.
- [ ] Verifikasi hasil masuk ke Workspace.
- [ ] Verifikasi hasil masuk ke Homepage recommendation feed sebagai `ai_generated` item.
- [ ] Verifikasi guru dapat download, open, dan share hasil file.

## File dan Area Implementasi yang Terdampak

### Frontend

- [ ] `frontend/lib/screens/home_screen.dart`
- [ ] `frontend/lib/widgets/prompt_input_widget.dart`
- [ ] `frontend/lib/services/project_service.dart`
- [ ] `frontend/lib/services/home_service.dart`
- [ ] Service/provider baru untuk media generation.
- [ ] Optional success/result UI screen atau inline card baru.

### Backend Laravel

- [ ] `backend/routes/api.php`
- [ ] Controller baru untuk media generation.
- [ ] Request validation baru untuk media generation.
- [ ] Service orchestration baru untuk interpretation, decision, Python client, publication, dan delivery response.
- [ ] Job/queue class untuk async processing.
- [ ] Migration dan model untuk `media_generations`.
- [ ] Reuse `FileUploadService` dan `ThumbnailGeneratorService`.

### Python Service

- [ ] API entrypoint/router.
- [ ] File generator `.docx`.
- [ ] File generator `.pdf`.
- [ ] File generator `.pptx`.
- [ ] Health check dan response contract.

## Definition of Done

- [ ] Guru dapat submit prompt dari Homepage tanpa mengubah pola UX utama.
- [ ] Sistem dapat menghasilkan JSON hasil pemahaman prompt yang tervalidasi.
- [ ] Sistem dapat menentukan format output dengan benar dan dapat dioverride guru.
- [ ] Sistem dapat memanggil generator Python yang sesuai dengan format output.
- [ ] Sistem dapat menghasilkan dan menyimpan file `.docx`, `.pdf`, atau `.pptx` secara aman.
- [ ] Sistem dapat mempublikasikan hasil ke Workspace dan Homepage recommendation feed.
- [ ] Guru menerima hasil akhir melalui kartu hasil di app dengan CTA file yang berfungsi.
- [ ] Test utama backend dan frontend lulus.
- [ ] Deployment backend dan Python service siap dijalankan pada environment target.

## Out of Scope untuk Fase Awal

- [ ] Video generation.
- [ ] Audio generation.
- [ ] OCR atau ekstraksi isi dari file yang di-upload guru.
- [ ] Real-time collaborative editing pada dokumen hasil.
- [ ] Full conversational file editing loop setelah file selesai dibuat.
- [ ] Generic binary handoff ke LLM sebagai mekanisme utama delivery.