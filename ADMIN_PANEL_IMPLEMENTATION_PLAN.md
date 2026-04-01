# Admin Panel Implementation Plan

Dokumen ini dipakai untuk tracking progres implementasi admin panel berbasis web pada project `klass-mobile`.

Arsitektur yang dipakai:
- Admin panel di-host di Laravel backend yang sudah ada.
- Akses admin panel melalui web pada area `/admin`.
- Autentikasi admin menggunakan session-based web auth, terpisah dari flow token mobile.
- Mobile app Flutter tetap menjadi aplikasi end-user, sedangkan admin panel menjadi back-office untuk monitoring dan management.
- Konfigurasi section homepage/app-feed disimpan di backend agar admin bisa rename dan reorder section tanpa hardcode di Flutter.

Tanggal penyusunan: 1 April 2026.

## Tujuan Utama

- Menyediakan admin panel yang proper, aman, dan mudah dipakai untuk memonitor aktivitas penting aplikasi.
- Memberikan kontrol administratif untuk user, content, marketplace task, media, audit trail, dan pengaturan section aplikasi.
- Menyediakan tracking progress implementasi yang jelas agar rollout dapat dikendalikan dengan baik.

## Keputusan Arsitektur

- [x] Admin panel dibangun di Laravel backend yang sudah ada.
- [x] Admin panel hanya dapat diakses oleh role `admin`.
- [x] Versi pertama fokus pada business monitoring + admin audit logs.
- [x] Scope section mencakup content sections dan homepage/app-feed sections.
- [x] Bottom navigation mobile tidak masuk scope dinamis V1.
- [x] Student progress admin module tidak masuk scope V1.

## Scope V1 yang Disepakati

- [x] Dashboard / overview
- [x] User management
- [x] Topics and content management
- [x] Marketplace task management
- [x] File / media management
- [x] Activity log / audit trail
- [x] System settings
- [x] Homepage section configuration untuk mobile app

## Status Ringkas

- [x] Phase 0 selesai
- [x] Phase 1 selesai
- [ ] Phase 2 selesai
- [ ] Phase 3 selesai
- [ ] Phase 4 selesai
- [ ] Phase 5 selesai
- [ ] Phase 6 selesai
- [ ] Phase 7 selesai
- [ ] Go-live readiness tercapai

---

## Phase 0 - Scope Alignment dan Guardrail

### Tujuan
Memfinalkan scope V1, batasan implementasi, dan acceptance criteria sebelum coding utama dimulai.

### Checklist
- [x] Finalisasi modul admin V1 yang akan dirilis
- [x] Finalisasi definisi role `admin` dan batas aksesnya
- [x] Finalisasi daftar aksi yang wajib tercatat pada audit log
- [x] Finalisasi definisi section yang dapat di-rename dan di-reorder
- [x] Finalisasi rule out-of-scope V1 agar implementasi tetap fokus
- [x] Finalisasi acceptance criteria untuk dashboard, management screens, dan settings

### Hasil Finalisasi Phase 0

#### Modul Admin V1

- Dashboard / overview untuk ringkasan operasional harian
- User management untuk list user, detail user, dan perubahan role admin bila diperlukan
- Topics and content management untuk rename, reorder, visibility, dan edit metadata inti
- Marketplace task management untuk list, filter, moderasi status, dan penghapusan task bermasalah
- File / media management untuk melihat file yang terindeks, kategori upload, dan penghapusan aman
- Activity log / audit trail untuk melihat histori tindakan admin dan event bisnis penting
- System settings untuk konfigurasi ringan yang memang perlu dikontrol admin
- Homepage section configuration untuk rename dan reorder section homepage/app-feed pada mobile app

#### Definisi Role `admin` dan Batas Akses

- Role `admin` adalah satu-satunya role back-office pada V1
- Admin memiliki akses penuh ke seluruh route, view, controller action, dan settings di area `/admin`
- Admin dapat melihat data operasional lintas user, content, task, media, dan activity log
- Admin dapat melakukan aksi create, update, reorder, moderate, dan delete pada modul yang masuk scope V1
- User non-admin tidak boleh mengakses halaman admin, endpoint admin, maupun aksi write khusus admin
- Flow autentikasi admin memakai session-based web auth dan tidak memakai bearer token mobile sebagai primary browser auth
- API mobile yang sifatnya public read tetap boleh dipakai mobile app, tetapi write action yang masuk kewenangan admin harus diproteksi pada fase berikutnya

#### Aksi Minimum yang Wajib Tercatat pada Audit Log

- Admin login
- Admin logout
- Pembuatan, perubahan, dan penghapusan user yang dilakukan admin
- Perubahan role user
- Perubahan status aktif / suspend user jika fitur itu jadi diimplementasikan
- Pembuatan, perubahan, reorder, publish / unpublish, dan penghapusan topic
- Pembuatan, perubahan, reorder, publish / unpublish, dan penghapusan content
- Perubahan status dan penghapusan marketplace task
- Upload dan penghapusan file / media melalui jalur admin atau jalur sistem yang relevan
- Perubahan system settings
- Perubahan homepage section configuration

Catatan audit log V1:
- Event minimal menyimpan actor, action, subject_type, subject_id, timestamp, dan metadata ringkas
- Untuk perubahan penting, metadata before/after ditargetkan bila implementasinya feasible tanpa membuat scope Phase 3 membengkak
- Request logging berbasis file yang sudah ada tetap dipertahankan, tetapi tidak dianggap cukup untuk admin audit UI

#### Definisi Section yang Bisa Di-Rename dan Di-Reorder

- Content sections mencakup struktur domain yang tampil sebagai topic / content grouping yang memang perlu diatur urutan atau label presentasinya
- Homepage / app-feed sections mencakup section yang saat ini tampil tetap pada home screen Flutter, khususnya section rekomendasi project dan section freelancer / teacher feed
- V1 hanya mencakup section-level rename dan reorder, bukan layout builder bebas
- V1 tidak mencakup dynamic bottom navigation, dynamic route navigation, atau perubahan struktur shell utama mobile app
- Setiap section homepage harus memiliki identitas konfigurasi yang stabil: key, label, position, enabled, dan data_source

#### Out of Scope V1 yang Ditetapkan

- Student progress management module
- Multi-role back-office selain `admin`
- Dynamic bottom navigation mobile
- Full technical observability dashboard untuk CPU, memory, infra, tracing, dan metrics server yang mendalam
- CMS visual builder yang memungkinkan admin menyusun layout halaman secara bebas
- Rework total arsitektur frontend mobile di luar integrasi section configuration

#### Acceptance Criteria yang Disepakati

Dashboard:
- Menampilkan ringkasan data penting aplikasi yang relevan untuk monitoring harian
- Menampilkan recent activity yang benar-benar berasal dari data sistem, bukan hardcoded
- Menangani loading, empty, error, dan success state secara jelas

Management screens:
- Setiap modul utama memiliki flow list dan detail yang jelas
- Search dan filter tersedia minimal pada modul yang memang membutuhkan volume data lebih besar
- Aksi destruktif atau moderasi memiliki guardrail seperti konfirmasi dan feedback hasil aksi
- Setiap aksi admin penting menghasilkan audit log

Settings:
- Admin dapat rename homepage section yang disetujui scope V1
- Admin dapat reorder homepage section yang disetujui scope V1
- Perubahan settings tersimpan konsisten dan dapat dibaca ulang oleh sistem
- Integrasi settings tidak merusak flow existing pada mobile app

Usability dan quality:
- Akses admin harus aman, konsisten, dan tidak bocor ke user non-admin
- Bahasa UI, penamaan menu, dan grouping modul harus jelas untuk operasional admin
- Implementasi harus mengikuti pendekatan minimal namun benar, tanpa memperluas scope secara liar pada fase awal

#### Dependency Antar Fase

- Phase 1 bergantung pada hasil finalisasi scope, role, access boundary, dan acceptance criteria dari Phase 0
- Phase 2 bergantung pada Phase 1 karena admin shell tidak boleh dibuka tanpa fondasi auth dan RBAC yang jelas
- Phase 3 bisa dimulai paralel sebagian dengan Phase 2 setelah schema activity log, section config, dan ordering field disepakati
- Phase 4 bergantung pada Phase 2 dan Phase 3 karena dashboard butuh admin shell sekaligus data model monitoring
- Phase 5 bergantung pada Phase 2 dan Phase 3 karena management modules perlu shell admin dan persistence yang benar
- Phase 6 bergantung pada fondasi data dari Phase 3 dan akan menghubungkan hasilnya ke UI admin serta mobile app
- Phase 7 bergantung pada selesainya fitur fase sebelumnya untuk verifikasi menyeluruh

### Exit Criteria
- [x] Scope V1 disepakati
- [x] Acceptance criteria utama disepakati
- [x] Dependency antar fase jelas

---

## Phase 1 - Security, Role, dan Access Foundation

### Tujuan
Menyiapkan fondasi akses admin agar panel aman dan semua aksi administratif dapat dikontrol dengan benar.

### Checklist
- [x] Tambahkan field role pada tabel users
- [x] Evaluasi kebutuhan field status aktif / suspend pada user
- [x] Update model `User` dengan helper/check untuk role admin
- [x] Update resource / serialization user agar metadata admin tersedia bila diperlukan
- [x] Tambahkan middleware / gate / policy untuk akses admin-only
- [x] Pisahkan jalur akses admin dari flow mobile user biasa
- [x] Audit endpoint write existing agar tidak tetap terbuka untuk publik
- [x] Pastikan non-admin tidak bisa mengakses area admin maupun action admin

### Hasil Implementasi Phase 1

- Role `role` ditambahkan ke user model dengan default `user` dan dukungan `admin`
- Helper `isAdmin()` ditambahkan pada model `User`
- Resource user sekarang mengekspose `role` dan `is_admin` untuk kebutuhan otorisasi client/admin
- Middleware admin-only dan gate `access-admin-panel` ditambahkan di backend
- Jalur web `/admin` dipisahkan sebagai area admin dan saat ini memakai placeholder route yang sudah diproteksi
- Endpoint write yang sebelumnya public tidak lagi terbuka untuk publik
- Write access dibagi sebagai berikut:
	- write topic create: authenticated user
	- write topic update/delete: admin only
	- write content/task/student-progress dan generic upload routes: admin only
	- avatar upload: authenticated user

Catatan evaluasi status aktif / suspend:
- Field aktif / suspend dievaluasi pada Phase 1 dan sengaja belum ditambahkan
- Keputusan saat ini: defer ke fase user management agar kebutuhan operasional dan UX suspend tidak diimplementasikan setengah jadi
- Fondasi akses admin tetap aman tanpa field ini karena boundary akses utama sudah ditangani lewat role dan route protection

Verifikasi Phase 1:
- `php artisan test --filter=AdminAccessFoundationTest --testdox` lulus
- `php artisan test` lulus penuh dengan 10 test dan 58 assertions

### Exit Criteria
- [x] Role admin dapat dibedakan secara eksplisit di backend
- [x] Admin-only access enforcement berjalan konsisten
- [x] Endpoint sensitif tidak dapat diakses user non-admin

---

## Phase 2 - Admin Authentication dan Admin Shell

### Tujuan
Membangun entry point admin panel berbasis web beserta layout utama yang akan dipakai semua modul.

### Checklist
- [x] Tambahkan route group admin pada web routes
- [ ] Implementasi halaman login admin berbasis session
- [ ] Implementasi logout admin
- [ ] Buat layout dasar admin panel
- [ ] Buat navigasi utama untuk Dashboard, Users, Content, Tasks, Media, Activity, Settings
- [ ] Tambahkan shared component untuk table, filter, badge status, empty state, error state, dan flash message
- [ ] Rapikan styling admin menggunakan pipeline Vite + Tailwind yang sudah ada

### Exit Criteria
- [ ] Admin dapat login dan logout melalui web
- [ ] Admin shell siap dipakai modul lain
- [ ] Navigasi utama stabil dan usable

---

## Phase 3 - Data Model Extensions untuk Monitoring dan Management

### Tujuan
Menambahkan tabel, field, dan struktur data yang dibutuhkan agar monitoring dan management dapat berjalan secara queryable dan maintainable.

### Checklist
- [ ] Tambahkan tabel activity logs untuk menyimpan event yang bisa ditampilkan di admin panel
- [ ] Definisikan struktur activity log: actor, action, subject_type, subject_id, metadata, timestamp
- [ ] Tambahkan field ordering / position pada entitas yang perlu di-reorder
- [ ] Tambahkan field visibility / publish state pada entitas content yang perlu dikontrol
- [ ] Tambahkan konfigurasi settings untuk homepage/app-feed sections
- [ ] Definisikan schema settings section: key, label, position, enabled, data_source
- [ ] Tambahkan persistence/index untuk media agar file dapat dikelola dari admin panel
- [ ] Tentukan strategi backfill bila ada file lama yang belum terindeks

### Exit Criteria
- [ ] Data model admin V1 lengkap
- [ ] Activity log bisa di-query dari database
- [ ] Section config bisa disimpan dan diambil dari backend

---

## Phase 4 - Modul Dashboard dan Monitoring

### Tujuan
Menyediakan tampilan monitoring utama agar admin dapat melihat gambaran kondisi aplikasi dan aktivitas penting secara cepat.

### Checklist
- [ ] Tampilkan summary cards untuk users, topics, contents, tasks, media, dan recent activity
- [ ] Tampilkan recent user registrations
- [ ] Tampilkan recent content changes
- [ ] Tampilkan recent marketplace task changes
- [ ] Tampilkan recent uploads / media events
- [ ] Tampilkan recent admin actions dari audit log
- [ ] Tambahkan filter waktu / recent window bila diperlukan
- [ ] Tangani loading, empty, error, dan retry state dengan baik

### Exit Criteria
- [ ] Dashboard menampilkan data monitoring utama yang relevan
- [ ] Audit log recent activity muncul dengan benar
- [ ] Dashboard usable untuk daily admin monitoring

---

## Phase 5 - Management Modules

### Tujuan
Menyediakan fitur kontrol operasional agar admin dapat mengelola entitas penting dalam aplikasi.

### Checklist Global
- [ ] Terapkan pattern list, search, filter, detail, edit, delete/moderate secara konsisten
- [ ] Tambahkan konfirmasi untuk aksi destruktif
- [ ] Pastikan setiap aksi admin penting masuk ke audit log

### 5.1 User Management
- [ ] List users dengan search dan filter dasar
- [ ] Lihat detail user
- [ ] Ubah role user bila diperlukan
- [ ] Aktifkan / nonaktifkan user jika fitur suspend masuk scope

### 5.2 Topics and Content Management
- [ ] List topics dan contents
- [ ] Rename topics
- [ ] Rename contents
- [ ] Reorder topics / contents sesuai kebutuhan domain
- [ ] Ubah publish / visibility state
- [ ] Edit metadata utama yang relevan

### 5.3 Marketplace Task Management
- [ ] List marketplace tasks
- [ ] Filter task berdasarkan status / content
- [ ] Lihat detail task
- [ ] Ubah status task
- [ ] Hapus / moderasi task yang tidak valid

### 5.4 File / Media Management
- [ ] List file berdasarkan kategori upload
- [ ] Preview metadata / reference file
- [ ] Hapus file secara aman melalui service storage yang ada
- [ ] Pastikan file yang dihapus tidak memutus referensi penting tanpa peringatan

### Exit Criteria
- [ ] Modul users usable
- [ ] Modul content usable
- [ ] Modul marketplace tasks usable
- [ ] Modul media usable

---

## Phase 6 - Activity Logging dan Homepage Section Configuration

### Tujuan
Menjadikan admin panel benar-benar berguna untuk supervisi dan pengendalian aplikasi, termasuk konfigurasi section yang mempengaruhi mobile app.

### Checklist
- [ ] Integrasikan pencatatan admin actions ke database activity log
- [ ] Integrasikan pencatatan event penting aplikasi ke activity log
- [ ] Tentukan daftar minimum event yang wajib tercatat: auth, content mutation, task mutation, upload, settings changes
- [ ] Simpan metadata before/after untuk perubahan penting bila feasible
- [ ] Buat halaman activity log dengan filter actor, action, entity, dan waktu
- [ ] Buat UI settings untuk rename homepage sections
- [ ] Buat UI settings untuk reorder homepage sections
- [ ] Buat endpoint read-only untuk mobile app mengambil konfigurasi section
- [ ] Refactor mobile home agar label dan urutan section berasal dari backend config
- [ ] Pastikan fallback mobile tetap aman bila config gagal dimuat

### Exit Criteria
- [ ] Audit trail cukup informatif untuk investigasi operasional
- [ ] Admin dapat rename dan reorder homepage sections dari panel
- [ ] Perubahan section tercermin di mobile app sesuai desain V1

---

## Phase 7 - Testing, Verification, dan Go-Live Readiness

### Tujuan
Memastikan seluruh flow admin panel stabil, aman, dan siap dipakai untuk operasional nyata.

### Checklist
- [ ] Tambahkan feature test untuk admin login / logout
- [x] Tambahkan feature test untuk admin-only access restriction
- [ ] Tambahkan feature test untuk dashboard query utama
- [ ] Tambahkan feature test untuk user management actions
- [ ] Tambahkan feature test untuk content rename / reorder / visibility update
- [ ] Tambahkan feature test untuk task moderation
- [ ] Tambahkan feature test untuk settings section config
- [ ] Tambahkan feature test untuk activity log creation
- [ ] Tambahkan test Flutter untuk homepage section config rendering
- [ ] Lakukan manual QA untuk dashboard, users, content, tasks, media, activity, settings
- [ ] Lakukan regression test untuk flow mobile yang existing
- [ ] Validasi non-admin tetap tidak dapat mengakses fitur admin

### Exit Criteria
- [ ] Alur kritikal admin panel lulus test
- [ ] Integrasi config section ke mobile tervalidasi
- [ ] Admin panel siap masuk release candidate / internal rollout

---

## Acceptance Criteria V1 yang Disepakati

- [x] Admin dapat login ke panel melalui web dengan akses yang aman
- [x] Admin dapat memonitor data penting aplikasi dari dashboard
- [x] Admin dapat mengelola user, content, task, dan media dengan flow yang jelas
- [x] Admin dapat melihat audit trail untuk aktivitas penting
- [x] Admin dapat rename dan reorder section homepage/app-feed dari panel
- [x] Mobile app dapat membaca konfigurasi section tanpa merusak flow existing
- [x] Error, empty, loading, dan success state tertangani dengan baik pada halaman admin utama

## Out of Scope V1

- Student progress management module
- Dynamic bottom navigation mobile
- Full technical observability dashboard untuk server metrics / infra metrics
- Multi-role back-office selain `admin`

## Tracking Milestone

- [x] M0: Scope dan guardrail final
- [x] M1: Role + admin access foundation selesai
- [ ] M2: Admin auth + shell selesai
- [ ] M3: Data model admin + activity log foundation selesai
- [ ] M4: Dashboard monitoring selesai
- [ ] M5: Management modules selesai
- [ ] M6: Section config + mobile integration selesai
- [ ] M7: Verification dan go-live readiness selesai

## Catatan Eksekusi

- Update checklist ini setiap ada PR atau implementasi utama yang selesai.
- Satu item checklist idealnya dipetakan ke minimal satu issue, branch, atau PR.
- Jika ada perubahan scope, update dokumen ini terlebih dahulu sebelum implementasi dilanjutkan.
- Jika ada item yang sengaja ditunda, beri catatan singkat alasan dan target fasenya.