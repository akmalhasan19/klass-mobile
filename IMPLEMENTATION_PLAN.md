# Implementation Plan: Migrasi dari Static Mode ke Logic Nyata

Dokumen ini dipakai untuk tracking progres implementasi logic nyata pada project `klass-mobile`.
Arsitektur yang dipakai:
- Backend logic tetap di Laravel
- Supabase dipakai untuk PostgreSQL database dan Supabase Storage bucket
- Fokus awal mengganti dummy data/dummy image/hardcoded list menjadi data nyata dari API

## Status Ringkas

- [x] Phase 0 selesai
- [x] Phase 1 selesai
- [x] Phase 2 selesai
- [x] Phase 3 selesai
- [x] Phase 4 selesai
- [x] Phase 5 selesai
- [ ] Phase 6 selesai
- [ ] Go-live readiness tercapai

---

## Phase 0 - Baseline dan Guardrail

### Tujuan
Mendefinisikan standar implementasi dan acceptance criteria sebelum coding utama dimulai.

### Checklist
- [x] Finalisasi inventaris static mode per layar (Home, Search, Bookmark, Gallery, Profile, Settings, Account Settings)
- [x] Definisikan acceptance criteria tiap layar: loading, empty, error, retry, success
- [x] Tentukan urutan rollout prioritas fitur
- [x] Tentukan DoD (Definition of Done) untuk tiap fase
- [x] Tetapkan policy branch/review/testing sebelum merge

### Exit Criteria
- [x] Dokumen scope + acceptance criteria disepakati
- [x] Urutan implementasi dan PIC tiap area sudah jelas

---

## Phase 1 - Fondasi Laravel + Supabase (PostgreSQL & Storage)

### Tujuan
Menyiapkan infrastruktur agar Laravel terkoneksi ke Supabase DB dan bucket storage public.

### Checklist
- [x] Konfigurasi Laravel ke Supabase PostgreSQL (`.env`, koneksi database, SSL bila dibutuhkan)
- [x] Jalankan migration ke Supabase dan validasi semua tabel utama
- [x] Tambahkan/rapikan disk storage Supabase di Laravel (`config/filesystems.php`)
- [x] Tentukan naming convention path bucket:
  - [x] `avatars/`
  - [x] `gallery/`
  - [x] `materials/`
  - [x] `attachments/`
- [x] Implementasi sanitasi filename + strategi anti-collision nama file
- [x] Tambahkan validasi upload (mime type + max size)
- [x] Uji generate public URL dari Laravel untuk file di bucket

### Exit Criteria
- [x] Laravel CRUD berjalan di Supabase PostgreSQL
- [x] Upload file ke bucket berhasil dan URL dapat diakses

---

## Phase 2 - Kontrak API Mobile dan Model Data

### Tujuan
Membuat kontrak API stabil agar Flutter bisa migrasi dari static source tanpa sering breaking.

### Checklist
- [x] Audit endpoint existing di `routes/api.php`
- [x] Standarisasi response schema (list/detail/create/update)
- [x] Tambahkan field media URL pada resource yang dibutuhkan UI
- [x] Tambahkan endpoint upload avatar
- [x] Tambahkan endpoint upload material/gallery asset
- [x] Implementasikan search query server-side
- [x] Implementasikan filter query server-side
- [x] Tambahkan pagination untuk list endpoint yang relevan
- [x] Tambahkan validasi request yang konsisten + message error terstruktur

### Exit Criteria
- [x] Semua endpoint prioritas punya kontrak response final
- [x] Search/filter/pagination berjalan sesuai parameter

---

## Phase 3 - Migrasi Dummy Data ke Seed + Bucket

### Tujuan
Menghindari UI kosong saat transisi dengan memindahkan data dummy menjadi seed data nyata.

### Checklist
- [x] Mapping dummy data -> entitas domain database
- [x] Buat/rapikan seeder data awal (topics/contents/tasks/profiles sesuai kebutuhan UI)
- [x] Upload asset dummy relevan ke bucket public
- [x] Simpan URL bucket ke tabel terkait
- [x] Hapus ketergantungan data demo dari widget state hardcoded
- [x] Verifikasi data seed bisa dipakai di endpoint list/detail

### Exit Criteria
- [x] Data awal tersedia dari API (bukan dari hardcoded list)
- [x] Image domain utama dimuat dari URL bucket

---

## Phase 4 - Integrasi Frontend dan Penghapusan Static Source

### Tujuan
Memindahkan sumber data layar prioritas dari in-memory hardcoded ke API Laravel.

### Checklist Global
- [x] Tambahkan dependency HTTP client yang dibutuhkan di Flutter
- [x] Buat API layer (base URL, headers, auth token, error mapping)
- [x] Refactor service agar sumber data berasal dari API
- [x] Terapkan loading/empty/error/retry pattern konsisten di semua layar prioritas

### Prioritas Implementasi Layar

#### 4.1 Auth + Profile + Avatar
- [x] Integrasi login/register dengan endpoint nyata
- [x] Simpan dan gunakan token auth secara aman
- [x] Tampilkan profil dari API
- [x] Implementasi upload avatar -> tampilkan URL hasil upload

#### 4.2 Home Feed
- [x] Ganti hardcoded projects dengan data API
- [x] Ganti hardcoded freelancer/teacher cards dengan data API
- [x] Tambahkan fallback UI jika data kosong/gagal

#### 4.3 Bookmark Persistence
- [x] Ganti persistence in-memory dengan API/database
- [x] Sinkronisasi bookmark create/read/delete
- [x] Pastikan data konsisten setelah app restart

#### 4.4 Gallery dari Bucket
- [x] Ambil list gallery/material dari API (Service ready)
- [x] Render image/file preview menggunakan URL bucket
- [x] Tangani image load failure dengan fallback yang proper

#### 4.5 Search + Filter Nyata
- [x] Kirim query search ke backend (Service ready)
- [x] Kirim parameter filter ke backend (Service ready)
- [x] Render hasil sesuai response server (Teachers feed)
- [x] Tampilkan state "no result" yang informatif

### Exit Criteria
- [x] Semua layar prioritas sudah API-backed
- [x] Tidak ada ketergantungan data domain dari hardcoded list

---

## Phase 5 - Hardening, Observability, dan Cut-over

### Tujuan
Menstabilkan sistem sebelum dianggap production-ready.

### Checklist
- [x] Tambahkan logging terstruktur untuk endpoint prioritas
- [x] Tambahkan timeout dan retry policy di client
- [x] Tambahkan monitoring error rate endpoint utama
- [x] Audit dan hapus file/kode dummy yang sudah tidak dipakai
- [x] Audit ulang bucket policy (tetap public sesuai keputusan fase ini)
- [x] (Opsional) Tambahkan feature flag sederhana untuk rollback aman

### Exit Criteria
- [x] Error handling stabil di backend dan frontend
- [x] Referensi static mode pada domain utama sudah dibersihkan

---

## Phase 6 - End-to-End Verification

### Tujuan
Memastikan seluruh alur utama berjalan dari sisi user nyata.

### Checklist
- [ ] Uji alur login -> home feed
- [ ] Uji alur update profile + upload avatar
- [ ] Uji alur bookmark create/read/delete
- [ ] Uji alur gallery load dan preview
- [ ] Uji alur search + filter
- [ ] Uji pada kondisi jaringan lambat/putus
- [ ] Uji pada Android
- [ ] Uji pada iOS
- [ ] Regression check: tidak ada lagi layar utama membaca dummy data

### Exit Criteria
- [ ] Semua test alur kritikal lulus
- [ ] Aplikasi siap masuk tahap release candidate

---

## Backlog Peningkatan Setelah Fase Awal

- [ ] Evaluasi migrasi bucket tertentu menjadi private + signed URL
- [ ] Tambahkan test otomatis API (feature test) untuk endpoint kritikal
- [ ] Tambahkan integration test Flutter untuk flow utama
- [ ] Optimasi performa query list/search/filter
- [ ] Pertimbangkan CDN/caching policy untuk media yang sering diakses

---

## Tracking Milestone

- [x] M1: Fondasi DB + Storage selesai
- [x] M2: Kontrak API prioritas selesai
- [x] M3: Seed data + media tersedia
- [x] M4: 5 layar prioritas sudah live data
- [x] M5: Hardening + E2E selesai
- [ ] M6: Release Candidate

## Catatan Eksekusi

- Update checklist ini setiap ada PR yang merge.
- Satu item checklist idealnya dipetakan ke minimal satu issue/PR.
- Jika ada perubahan scope, update dokumen ini terlebih dahulu sebelum implementasi lanjutan.
