# Personalized Project Recommendations Implementation Plan

## Ringkasan

Dokumen ini merinci implementasi fitur personalized Project Recommendations untuk Klass App, sekaligus penambahan section baru di Homepage Configurator pada Admin Panel yang menampilkan system-generated recommendation terpopuler per sub-subject.

Target akhir implementasi:

- Homepage recommendation untuk user yang login menjadi benar-benar personalized.
- Sistem menyimpan distribusi recommendation per user agar bisa dihitung secara agregat.
- Admin Panel menampilkan dua section terpisah:
  - Recommended Projects (Admin Curated)
  - Top Distributed System Recommendations by Sub-Subject
- Tiap sub-subject di section baru hanya menampilkan satu item system recommendation dengan distribusi user tertinggi dan jumlah user penerima lebih dari satu.

## Prinsip Implementasi

- Existing admin-curated recommendation flow harus tetap utuh dan tidak berubah perilakunya.
- Existing mobile API contract untuk curated recommendations harus tetap kompatibel semaksimal mungkin.
- Personalization untuk system recommendation harus berbasis data nyata user, bukan inferensi dari judul semata.
- Perhitungan distribusi harus berbasis distinct users, bukan raw page refresh atau impression count yang berulang.
- Guest user tetap memakai fallback feed yang aman sampai ada konteks user terautentikasi.

## Phase 0 - Discovery Lock

- [x] Finalisasi nama file, endpoint, dan istilah UI untuk section baru di Admin Panel.
- [x] Finalisasi aturan bisnis untuk top distributed item per sub-subject:
  - [x] Hanya `system-generated` items yang dihitung.
  - [x] Hanya item dengan `distinct_user_count > 1` yang eligible.
  - [x] Satu sub-subject hanya boleh punya satu item terpilih.
  - [x] Tie-breaker ditentukan secara deterministic.
- [x] Finalisasi fallback behavior untuk user tanpa data personalization yang cukup.
- [x] Finalisasi strategi guest behavior agar tidak mengganggu current homepage feed.

## Phase 1 - Normalisasi Data dan Taksonomi

### 1.1 Subject dan Sub-Subject Taxonomy

- [x] Tambahkan persistence untuk subject taxonomy.
- [x] Tambahkan persistence untuk sub-subject taxonomy.
- [x] Definisikan relasi subject -> sub-subject.
- [x] Tambahkan seed data awal atau baseline records untuk taxonomy bila diperlukan.
- [x] Tambahkan factory/seeder support untuk taxonomy baru agar testing lebih mudah.

### 1.2 Normalisasi Topic Ownership

- [x] Tambahkan field relasional baru pada topic untuk menghubungkan topic ke user yang valid.
- [x] Pertahankan `teacher_id` lama untuk backward compatibility selama masa transisi.
- [x] Buat migration/backfill untuk mencoba memetakan legacy `teacher_id` ke user yang benar.
- [x] Definisikan rule untuk legacy record yang gagal dipetakan.
- [x] Pastikan personalization hanya memakai data ownership yang valid dan ter-normalisasi.

### 1.3 Pengaitan Topic ke Taxonomy

- [x] Tambahkan relasi topic ke subject atau sub-subject yang relevan.
- [x] Tentukan apakah topic cukup mengacu ke `sub_subject_id` atau perlu `subject_id` juga.
- [x] Update model Topic agar support relation baru.
- [x] Update resource/API response Topic agar taxonomy baru bisa dibaca saat dibutuhkan.

### 1.4 User Profile Anchor

- [x] Tambahkan field profile user untuk subject utama yang diajarkan.
- [x] Tambahkan relasi model User ke subject utama.
- [x] Tentukan apakah profile subject wajib atau optional.
- [x] Gunakan profile subject sebagai signal prioritas pertama untuk personalization.
- [x] Gunakan authored-topic activity sebagai fallback signal bila profile subject belum tersedia.

## Phase 2 - Update Topic Read/Write Flow

### 2.1 Backend Topic API

- [x] Update validation request untuk create topic agar menerima taxonomy baru.
- [x] Update validation request untuk update topic agar menerima taxonomy baru.
- [x] Update controller create topic agar ownership user terisi otomatis bila request berasal dari teacher yang login.
- [x] Update controller update topic agar field taxonomy dan ownership tetap konsisten.
- [x] Pastikan endpoint read topic tetap backward compatible untuk consumer yang lama.

### 2.2 Mobile Topic Creation Compatibility

- [x] Audit payload `POST /topics` dari Flutter flow yang sudah ada.
- [x] Tentukan field tambahan minimum agar topic baru bisa masuk ke personalization pipeline.
- [x] Update Flutter `project_service` hanya jika backend contract memang berubah secara wajib.
- [x] Pastikan workspace topic list tetap bisa memuat topic lama dan topic baru tanpa regression.

### 2.3 Data Quality Guardrails

- [x] Tambahkan guard agar topic tanpa taxonomy yang memadai tidak merusak personalization.
- [x] Tentukan fallback untuk topic yang belum punya sub-subject.
- [x] Tentukan apakah topic tanpa ownership valid tetap boleh tampil di feed umum.

## Phase 3 - Personalized Recommendation Engine

### 3.1 User-Aware Recommendation Resolution

- [x] Ubah recommendation flow agar dapat membaca user terautentikasi secara opsional.
- [x] Pertahankan endpoint `GET /api/homepage-recommendations` sebagai contract utama.
- [x] Bedakan behavior untuk authenticated user dan guest user.
- [x] Pastikan admin-curated recommendations tetap ikut dimunculkan seperti sebelumnya.

### 3.2 Personalization Signals

- [x] Gunakan `users.primary_subject_id` sebagai signal utama.
- [x] Hitung authored-topic activity per sub-subject untuk user terkait.
- [x] Tentukan ranking authored-topic activity berdasarkan frekuensi dan recency.
- [x] Gunakan kombinasi subject profile dan authored-topic activity untuk memilih candidate sub-subject.
- [x] Tentukan fallback ranking bila signal user minim atau kosong.

### 3.3 System Recommendation Candidate Selection

- [x] Filter system-generated recommendation candidates berdasarkan sub-subject yang relevan untuk user.
- [x] Pertahankan curated admin items di luar filter personalization ini.
- [x] Definisikan aturan urutan candidate yang deterministic.
- [x] Pastikan override/suppression behavior yang existing tetap jalan.
- [x] Pastikan personalized result tetap aman bila sebagian source gagal dinormalisasi.

## Phase 4 - Distribution Tracking dan Persistence

### 4.1 Assignment Tracking Model

- [ ] Tambahkan tabel persistence untuk assignment system recommendation ke user.
- [ ] Simpan relasi user, recommendation item, source reference, subject, dan sub-subject yang relevan.
- [ ] Simpan timestamp distribusi pertama dan distribusi terakhir.
- [ ] Simpan counter atau metadata tambahan hanya bila memang diperlukan.

### 4.2 Upsert dan Deduplikasi

- [ ] Pastikan satu user dan satu recommendation item tidak membuat distinct count ganda.
- [ ] Gunakan mekanisme upsert atau unique key yang sesuai.
- [ ] Pastikan repeated homepage refresh tidak menaikkan distinct user count.
- [ ] Tentukan apakah last served timestamp tetap diperbarui pada refresh berikutnya.

### 4.3 Tracking Trigger

- [ ] Rekam assignment ketika homepage recommendation endpoint mengembalikan system-generated items ke authenticated user.
- [ ] Jangan rekam assignment untuk guest request.
- [ ] Jangan ganggu delivery curated admin items dengan tracking baru ini.
- [ ] Pastikan tracking error tidak menjatuhkan homepage response utama.

## Phase 5 - Aggregation Logic untuk Admin Panel

### 5.1 Summary Rules

- [ ] Buat query/service khusus untuk summary system recommendation per sub-subject.
- [ ] Group data berdasarkan sub-subject.
- [ ] Hitung `distinct_user_count` untuk tiap item di dalam satu sub-subject.
- [ ] Exclude item dengan `distinct_user_count <= 1`.
- [ ] Pilih hanya item dengan distribusi user tertinggi pada tiap sub-subject.

### 5.2 Deterministic Tie-Breaking

- [ ] Finalisasi tie-breaker pertama, misalnya `latest_distribution_at`.
- [ ] Finalisasi tie-breaker kedua, misalnya source item terbaru atau urutan ID.
- [ ] Pastikan hasil summary stabil antara request yang identik.

### 5.3 Output Contract untuk Admin UI

- [ ] Definisikan payload summary yang minimal memuat:
  - [ ] Title item.
  - [ ] Subject.
  - [ ] Sub-subject.
  - [ ] Source type/source reference.
  - [ ] Distinct user count.
  - [ ] Latest distribution timestamp.
- [ ] Tambahkan empty state contract bila belum ada item eligible.

## Phase 6 - Admin Panel Homepage Configurator

### 6.1 Controller dan View Model

- [ ] Extend data loader untuk Homepage Configurator agar memuat curated projects seperti biasa.
- [ ] Tambahkan fetch terpisah untuk aggregated system recommendation summary.
- [ ] Pastikan data section baru tidak mengubah flow CRUD curated project.
- [ ] Pastikan admin page tetap bisa dibuka walau summary system recommendation kosong.

### 6.2 UI Section Baru

- [ ] Tambahkan section baru di bawah `Recommended Projects (Admin Curated)`.
- [ ] Gunakan label yang jelas, misalnya `Top Distributed System Recommendations by Sub-Subject`.
- [ ] Tampilkan satu row/item per sub-subject.
- [ ] Tampilkan detail penting: title, subject, sub-subject, jumlah user, dan waktu distribusi terakhir.
- [ ] Tambahkan empty state yang menjelaskan belum ada item system recommendation yang didistribusikan ke lebih dari satu user.

### 6.3 Non-Regression pada Curated Section

- [ ] Pastikan tombol add/edit/delete/toggle curated project tetap bekerja tanpa perubahan behavior.
- [ ] Pastikan existing curated table tidak berubah logika bisnisnya.
- [ ] Pastikan curated project uploads tetap tidak terpengaruh oleh feature baru.

## Phase 7 - Testing dan Quality Gates

### 7.1 Backend Automated Tests

- [ ] Tambahkan test untuk taxonomy dan normalized ownership migration/backfill.
- [x] Tambahkan test untuk personalized homepage feed pada authenticated teacher.
- [x] Tambahkan test untuk guest fallback behavior.
- [ ] Tambahkan test untuk assignment upsert/deduplication.
- [ ] Tambahkan test untuk aggregation selection satu item per sub-subject.
- [ ] Tambahkan test untuk exclusion rule `distinct_user_count <= 1`.
- [x] Pastikan existing curated recommendation tests tetap hijau.

### 7.2 Admin Feature Tests

- [ ] Tambahkan assertion bahwa Homepage Configurator menampilkan curated section dan system section secara terpisah.
- [ ] Tambahkan assertion urutan section: system section harus berada di bawah curated section.
- [ ] Tambahkan assertion empty state untuk system section.
- [ ] Tambahkan access-control regression bila ada route/admin loader baru.

### 7.3 Manual Verification

- [ ] Verifikasi `GET /api/homepage-recommendations` tanpa auth masih aman.
- [ ] Verifikasi `GET /api/homepage-recommendations` dengan auth menghasilkan system recommendation yang lebih relevan terhadap subject/sub-subject user.
- [ ] Verifikasi repeated refresh tidak menaikkan distinct user count secara salah.
- [ ] Verifikasi Admin Panel hanya menampilkan satu item per sub-subject.
- [ ] Verifikasi item di Admin Panel memang item dengan distribusi user tertinggi pada sub-subject tersebut.
- [ ] Verifikasi curated project flow tetap normal end-to-end.

## Phase 8 - Dokumentasi dan Operasional

- [ ] Update backend notes atau README yang relevan untuk menjelaskan personalization flow baru.
- [ ] Dokumentasikan schema baru dan tujuan masing-masing table/field.
- [ ] Dokumentasikan behavior fallback untuk guest dan user tanpa signal personalization.
- [ ] Dokumentasikan aturan agregasi yang dipakai Admin Panel.
- [ ] Dokumentasikan langkah seed/backfill bila deployment membutuhkan migrasi data existing.

## File yang Paling Mungkin Tersentuh

- [ ] `backend/app/Services/RecommendationAggregationService.php`
- [ ] `backend/app/Http/Controllers/Api/HomepageRecommendationController.php`
- [ ] `backend/app/Http/Controllers/Admin/AdminHomepageSectionController.php`
- [ ] `backend/resources/views/admin/homepage-sections/index.blade.php`
- [ ] `backend/app/Models/Topic.php`
- [ ] `backend/app/Http/Controllers/Api/TopicController.php`
- [ ] `backend/app/Http/Requests/StoreTopicRequest.php`
- [ ] `backend/app/Http/Requests/UpdateTopicRequest.php`
- [ ] `backend/app/Models/User.php`
- [ ] `backend/app/Http/Resources/UserResource.php`
- [ ] `backend/routes/api.php`
- [ ] `backend/routes/web.php`
- [ ] `backend/tests/Feature/RecommendationAggregationServiceTest.php`
- [ ] `backend/tests/Feature/HomepageRecommendationApiTest.php`
- [ ] `backend/tests/Feature/AdminHomepageSectionConfigurationTest.php`
- [ ] `backend/tests/Feature/AdminRecommendedProjectManagementTest.php`
- [ ] `frontend/lib/services/project_service.dart`
- [ ] `frontend/lib/services/home_service.dart`

## Keputusan yang Sudah Dikunci

- [x] System recommendation harus benar-benar personalized untuk user yang login.
- [x] Taxonomy subject/sub-subject harus explicit, bukan hasil parsing judul.
- [x] Personalization harus mengambil signal dari profile user dan authored-topic activity.
- [x] Topic ownership harus dinormalisasi ke relasi user yang valid.
- [ ] Distibusi dihitung sebagai jumlah distinct users.
- [x] Existing admin-curated recommendation section harus tetap utuh.

## Catatan Implementasi Penting

- Backfill `topics.teacher_id` sebaiknya mencoba mapping ke `users.id` bila nilainya numerik, dan ke `users.email` bila formatnya mirip email.
- Record legacy yang gagal dipetakan sebaiknya tidak langsung dihapus; cukup dikecualikan dari personalization signal sampai datanya dibenahi.
- Empty state admin section harus eksplisit menyatakan bahwa belum ada system recommendation yang didistribusikan ke lebih dari satu user.
- Jika tracking gagal, homepage response sebaiknya tetap sukses agar UX mobile tidak rusak.

## Definition of Done

- [ ] Authenticated user menerima personalized system recommendation yang relevan.
- [ ] Guest user tetap menerima fallback recommendation flow yang aman.
- [ ] System recommendation delivery tercatat tanpa double counting distinct users.
- [ ] Homepage Configurator menampilkan section baru di bawah curated section.
- [ ] Section baru hanya menampilkan satu top-distributed item per sub-subject.
- [ ] Existing curated recommendation flow tetap tidak regress.
- [ ] Automated tests dan manual smoke checks selesai.