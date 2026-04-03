# Homepage Configurator - Recommended Projects Implementation Tracker

Dokumen ini dipakai untuk tracking implementasi fitur Homepage Configurator yang akan diposisikan sebagai workspace untuk upload, kurasi, dan monitoring Recommended Projects yang tampil pada section Project Recommendation di Klass App.

Tanggal penyusunan: 3 April 2026
Status dokumen: active tracker

## Tujuan Utama

- Menjadikan tab Homepage Configurator di Admin Panel benar-benar berfungsi.
- Memungkinkan admin meng-upload project showcase buatan tim Klass.
- Menampilkan project upload admin di section Project Recommendation bersama recommendation lain dari sistem/app.
- Membuka status Coming Soon agar fitur dapat diakses dan dioperasikan.
- Menyediakan checklist implementasi yang bisa dipakai untuk tracking progres secara rapi.

## Keputusan yang Sudah Disepakati

- [x] Project hasil upload admin tidak memakai Topic sebagai model utama.
- [x] Akan dibuat entitas baru khusus untuk showcase atau recommended project.
- [x] Project upload admin harus dicampur otomatis ke section Project Recommendation yang sama.
- [x] Homepage Configurator difokuskan untuk upload, kurasi, dan monitoring Recommended Projects.
- [x] Konfigurasi `homepage_sections` tetap dipertahankan untuk visibility dan ordering section, tetapi bukan lagi fungsi utama tab ini.
- [x] Integrasi source dari sistem/app dan AI disiapkan sebagai hook, tanpa mewajibkan ranking engine AI dibangun pada fase awal.

## Success Criteria

- [ ] Admin bisa membuka Homepage Configurator tanpa halaman placeholder Coming Soon.
- [ ] Admin bisa membuat, mengedit, mengaktifkan, menonaktifkan, dan menghapus Recommended Project.
- [ ] Admin bisa meng-upload thumbnail atau asset project dari Homepage Configurator.
- [ ] Feed recommendation di mobile menampilkan project admin upload dan recommendation non-admin dalam satu section yang sama.
- [ ] UI mobile tetap aman saat salah satu source kosong atau gagal dimuat.
- [ ] Semua aksi penting admin tercatat ke activity logs.
- [ ] Dokumentasi dan automated tests sinkron dengan perilaku akhir fitur.

## Milestone Summary

- [x] Phase 0 - Scope dan keputusan produk dikunci
- [x] Phase 1 - Domain model dan API contract finalized
- [x] Phase 2 - Backend persistence dan aggregation service selesai
- [x] Phase 3 - Admin Homepage Configurator usable
- [x] Phase 4 - Public API homepage recommendation siap dipakai mobile
- [ ] Phase 5 - Flutter home integration selesai
- [ ] Phase 6 - Testing, QA, dan documentation sync selesai

---

## Phase 0 - Scope Lock

### Outcome
Menyamakan definisi fitur sebelum implementasi teknis dimulai.

### Checklist

- [x] Tetapkan Homepage Configurator sebagai workspace Recommended Projects.
- [x] Tetapkan penggunaan entitas baru terpisah dari Topic.
- [x] Tetapkan strategi merge otomatis untuk admin upload dan recommendation non-admin.
- [x] Tetapkan bahwa section target di mobile adalah Project Recommendation yang sudah ada.
- [x] Tetapkan bahwa source AI hanya perlu di-hook terlebih dahulu pada fase awal.

### Exit Criteria

- [x] Scope implementasi disepakati.
- [x] Arah arsitektur dasar disepakati.

---

## Phase 1 - Domain Model dan Contract Design

### Outcome
Menentukan bentuk data final agar backend admin, API, dan Flutter memakai kontrak yang sama.

### Checklist

- [x] Definisikan schema entitas baru untuk Recommended Project.
- [x] Finalisasi field minimum: `title`, `description`, `thumbnail_url`, `ratio`, `project_type`, `tags`, `modules`, `source_type`, `source_reference`, `display_priority`, `is_active`, `starts_at`, `ends_at`, `created_by`, `updated_by`.
- [x] Tentukan enum atau daftar nilai untuk `source_type` seperti `admin_upload`, `system_topic`, dan `ai_generated`.
- [x] Tentukan aturan merge dan sorting final untuk feed recommendation.
- [x] Tentukan fallback contract bila `modules`, `tags`, atau media detail tidak tersedia.
- [x] Tentukan payload response final yang dipakai mobile untuk card dan bottom sheet.
- [x] Tentukan aturan visibility item: aktif, nonaktif, terjadwal, atau kedaluwarsa.
- [x] Tetapkan strategi mapping recommendation non-admin lama ke kontrak baru.

### Deliverables

- [x] Draft schema tabel dan relasi.
- [x] Draft response JSON endpoint recommendation.
- [x] Dokumen aturan merge, visibility, dan fallback.

### Exit Criteria

- [x] Kontrak data final disepakati.
- [x] Tidak ada ambiguity antara kebutuhan admin panel dan kebutuhan UI mobile.

---

## Phase 2 - Backend Persistence dan Aggregation Service

### Outcome
Menyediakan fondasi backend untuk menyimpan curated items dan menggabungkannya dengan source recommendation lain.

### Checklist

- [x] Buat migration untuk tabel Recommended Projects baru.
- [x] Tambahkan model Eloquent untuk Recommended Project.
- [x] Tambahkan factory atau seed helper bila dibutuhkan untuk test.
- [x] Tambahkan resource/transformer khusus untuk payload recommendation.
- [x] Buat service agregasi recommendation untuk menggabungkan curated admin items dan recommendation non-admin.
- [x] Implementasikan normalisasi source non-admin yang saat ini berasal dari Topics.
- [x] Tambahkan dukungan `source_payload` atau metadata sejenis bila diperlukan untuk monitoring source AI/system.
- [x] Terapkan filtering item aktif dan visibility window pada service agregasi.
- [x] Terapkan aturan sorting final berdasarkan priority, score, dan fallback timestamp.
- [x] Siapkan query yang aman bila salah satu source kosong.

### Deliverables

- [x] Migration dan model Recommended Project.
- [x] Recommendation aggregation service.
- [x] Resource/serializer final untuk mobile feed.

### Exit Criteria

- [x] Backend dapat menghasilkan feed recommendation campuran secara konsisten.
- [x] Curated items admin sudah bisa disimpan dan dibaca ulang.

---

## Phase 3 - Admin Homepage Configurator

### Outcome
Mengganti placeholder Coming Soon dengan halaman kerja nyata untuk operasional admin.

### Checklist

- [x] Ganti halaman placeholder di Homepage Configurator dengan UI fungsional.
- [x] Pertahankan menu dan route admin yang sudah ada agar navigasi tidak berubah.
- [x] Tambahkan daftar Recommended Projects yang sudah dibuat admin.
- [x] Tambahkan status badge untuk active, inactive, scheduled, dan expired.
- [x] Tambahkan filter berdasarkan `source_type` dan status tampil.
- [x] Tambahkan form create Recommended Project.
- [x] Tambahkan form edit Recommended Project.
- [x] Tambahkan aksi activate atau deactivate item.
- [x] Tambahkan aksi hapus item dengan guardrail konfirmasi.
- [x] Tambahkan aksi atur priority atau ordering curated items.
- [x] Tambahkan upload thumbnail atau media project dari halaman ini.
- [x] Reuse media upload flow yang sudah ada agar tidak menduplikasi logic storage.
- [x] Tambahkan monitoring table untuk feed yang sedang eligible tampil di app.
- [x] Tampilkan asal item pada monitoring table: admin upload, system/app, atau AI.
- [x] Catat semua aksi penting ke Activity Log.

### Deliverables

- [x] View Homepage Configurator baru.
- [x] Controller actions untuk create, update, delete, activate, dan reorder.
- [x] Integrasi upload asset dari admin panel.
- [x] Monitoring panel untuk recommendation feed.

### Exit Criteria

- [x] Admin bisa mengelola curated recommendation item end-to-end tanpa placeholder.
- [x] Semua perubahan penting tercatat ke audit log.

---

## Phase 4 - Public API Homepage Recommendation

### Outcome
Menyediakan endpoint publik yang menjadi satu sumber kebenaran untuk recommendation feed di mobile.

### Checklist

- [x] Tambahkan endpoint API khusus untuk homepage recommendation feed.
- [x] Pastikan endpoint memanggil aggregation service, bukan query manual terpisah di controller.
- [x] Pastikan response sudah dalam shape final yang siap dipakai Flutter.
- [x] Pastikan project admin upload dan recommendation non-admin dikembalikan dalam satu list yang sama.
- [x] Pastikan section Project Recommendation tetap mengikuti visibility dari `homepage_sections`.
- [x] Pastikan endpoint aman bila source non-admin belum tersedia atau gagal dinormalisasi.
- [x] Tambahkan dukungan pagination atau limiting bila memang diperlukan untuk home feed.
- [x] Tambahkan metadata source yang cukup untuk monitoring tanpa membebani UI mobile.

### Deliverables

- [x] Route API baru.
- [x] Controller atau action untuk recommendation feed.
- [x] JSON contract final untuk mobile.

### Exit Criteria

- [x] Mobile bisa mengambil recommendation feed campuran dari satu endpoint.
- [x] Perilaku merge dan sort konsisten antara admin monitoring dan mobile app.

---

## Phase 5 - Flutter Home Integration

### Outcome
Mengarahkan home screen Klass App agar memakai feed rekomendasi campuran dari backend.

### Checklist

- [x] Update HomeService agar fetch Project Recommendation memakai endpoint recommendation baru.
- [x] Tambahkan normalizer payload recommendation pada lapisan service API Flutter.
- [x] Pertahankan fallback aman bila config homepage sections gagal dimuat.
- [x] Update HomeScreen agar section `project_recommendations` memakai feed campuran baru.
- [x] Pastikan tidak dibuat section baru terpisah untuk admin upload.
- [x] Pastikan card project tetap aman untuk source item yang berbeda-beda.
- [x] Update detail bottom sheet agar aman bila tags, modules, atau image source tidak lengkap.
- [x] Tambahkan badge atau penanda source bila memang diputuskan perlu di UI.
- [x] Pastikan empty state tetap benar jika tidak ada recommendation sama sekali.
- [x] Pastikan error state tidak membuat home screen blank total.

### Deliverables

- [x] Update service layer Flutter.
- [x] Update home screen recommendation flow.
- [x] Update card/detail components sesuai kontrak baru.

### Exit Criteria

- [x] Section Project Recommendation di mobile memakai feed campuran final.
- [x] UI mobile tetap stabil untuk semua state utama.

---

## Phase 6 - Testing, QA, dan Documentation Sync

### Outcome
Memastikan implementasi siap dioperasikan dan dokumentasi sesuai dengan perilaku sistem yang sebenarnya.

### Checklist

- [ ] Tambahkan backend feature test untuk CRUD Recommended Project.
- [ ] Tambahkan backend feature test untuk upload thumbnail atau media project.
- [x] Tambahkan backend feature test untuk aggregation feed campuran.
- [x] Tambahkan backend feature test untuk filtering active, inactive, scheduled, dan expired.
- [ ] Tambahkan backend regression test untuk non-admin access restriction.
- [ ] Tambahkan Flutter test untuk render section Project Recommendation dari endpoint baru.
- [ ] Tambahkan Flutter test untuk empty state dan error state recommendation feed.
- [ ] Lakukan manual QA pada admin flow: create, edit, upload, activate, deactivate, delete, reorder, dan monitoring.
- [ ] Lakukan manual QA pada Android flow: project admin upload muncul bersama recommendation lain dan detail project tetap aman dibuka.
- [ ] Sinkronkan dokumentasi implementasi admin panel dengan perilaku terbaru Homepage Configurator.
- [ ] Sinkronkan test lama yang masih mengasumsikan Homepage Configurator lama atau placeholder.

### Deliverables

- [ ] Test coverage backend yang relevan.
- [ ] Test coverage Flutter yang relevan.
- [ ] Dokumentasi implementasi yang sudah diperbarui.

### Exit Criteria

- [ ] Seluruh alur kritikal lulus test.
- [ ] Manual QA utama selesai tanpa blocker release.
- [ ] Dokumentasi dan kode tidak lagi saling bertentangan.

---

## Out of Scope Untuk Fase Awal

- [ ] Full ranking engine AI untuk recommendation.
- [ ] Dynamic homepage layout builder bebas.
- [ ] Section baru terpisah khusus admin upload di mobile home.
- [ ] Perombakan total domain Topic agar menjadi model utama showcase project.
- [ ] Full observability dashboard untuk scoring atau recommendation analytics tingkat lanjut.

## Catatan Implementasi

- Gunakan merge di backend, bukan di Flutter, agar aturan sort dan visibility tetap konsisten.
- Reuse upload pipeline yang sudah ada untuk meminimalkan duplikasi logic storage.
- Jaga agar `homepage_sections` tetap menjadi sumber visibility section, walau Homepage Configurator berubah fokus.
- Pastikan rollout awal tetap aman ketika curated admin item belum ada, sehingga recommendation non-admin tetap tampil.