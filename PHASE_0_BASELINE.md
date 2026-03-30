# Phase 0: Baseline dan Guardrail

Dokumen ini mendefinisikan standar implementasi, acceptance criteria, dan exit criteria sebelum coding migrasi dari Static Mode (dummy data) ke Logic Nyata (API Laravel + Supabase) dimulai.

## 1. Inventaris Static Mode per Layar
Berikut adalah inventaris komponen utama per layar yang saat ini masih menggunakan static data (hardcoded) dan perlu disambungkan dengan sumber data API di tahap berikutnya:
- **Home Feed:** Daftar project, daftar mentor/teacher yang difeature, dan aktivitas terbaru.
- **Search:** Mekanisme pencarian teks, filter berdasarkan kategori, dan hasil pencarian.
- **Bookmark:** Daftar item atau project yang telah ditandai/dibookmark user.
- **Gallery:** Grid image, file materi pelajaran, preview aset dan interaksi buka file.
- **Profile:** Data diri pengguna (nama, detail profesi, statistik pencapaian, avatar, dan project milestones).
- **Settings:** Preferensi general, mode/gaya belajar, dan project complexity default.
- **Account Settings:** Preferensi akun, email, notifikasi, serta detail password placeholder.

## 2. Acceptance Criteria (AC) Tiap Layar
Semua layar yang mengambil data secara asinkron dari API harus menangani 5 state berikut secara konsisten:
1. **Loading:** Harus menampilkan progress skeleton, shimmer view, atau loading indicator yang ramah dan tidak menyebabkan kedipan saat perpindahan state.
2. **Empty:** Harus menampilkan ilustrasi / pesan teks informatif jika tidak ada data yang dikembalikan server (contoh: "Belum ada project" atau "Hasil pencarian tidak ditemukan").
3. **Error:** Harus menampilkan pesan kesalahan general yang bisa dipahami user (contoh: "Koneksi terputus" atau "Gagal mengambil data") dan bukan berupa raw stack trace/exception.
4. **Retry:** Harus ada tombol "Coba Lagi" atau mekanisme pull-to-refresh untuk memicu request ulang apabila terjadi kondisi state Error.
5. **Success:** Harus mampu me-render data dari API tanpa isu rendering, layout overflow, dan dapat menangani remote aset (dari Bucket Supabase) dengan graceful fallback.

## 3. Urutan Rollout Prioritas Fitur
Implementasi migrasi akan digulirkan bertahap mengikuti urutan berikut:
1. **Infrastruktur Backend:** Konfigurasi server Laravel API, koneksi Supabase PostgreSQL, dan konfigurasi Supabase Storage.
2. **Auth & Profile:** Fungsi registrasi/login standar dan pengolahan profil user termasuk upload image (Avatar) ke cloud.
3. **Home Feed & Display:** Pengambilan data utama aplikasi (project lists, cards) lewat query langsung ke backend.
4. **Gallery & Materials:** Menampilkan aset (gambar/file) secara asinkron dari public URL yang digenerate oleh backend.
5. **Search & Bookmark:** Integrasi query search teks ke API serta mencatat/read state persistensi bookmark dari DB.
6. **Setting Integration:** Integrasi patch user preferences agar sinkron dengan database backend.

## 4. Definition of Done (DoD) per Fase
Sebuah fase dianggap 100% selesai dan siap dilanjutkan ke fase berikutnya apabila:
- Pengembangan logic kode selesai terimplementasi (Frontend Flutter & Backend Laravel).
- Semua variable _hardcoded_ / list dummy data di UI untuk fitur terkait telah dihapus secara menyeluruh.
- Melewati pengujian manual (Acceptance Testing) untuk alur `Loading, Empty, Error, Retry, dan Success`.
- File dokumentasi dan checklist `IMPLEMENTATION_PLAN.md` telah di-update secara rinci.
- Tidak terdapat warning linter kritis, type errors, dan layout bug seperti "Overflow Exception" di layar tersebut.

## 5. Policy Branch / Review / Testing
- **Branching Policy:**
  - Bekerja menggunakan convention seperti `feat/<fitur-baru>`, `fix/<perbaikan-bug>`, `chore/<technical-debt>`.
  - Branch `main` menjadi tujuan merge akhir (Single source of truth).
- **Review Policy:**
  - Kode harus melalui proses code/self-review dengan melihat diff file yang diubah sebelum merge. Memastikan tak ada sisa kode static yang mengambang.
- **Testing Policy:**
  - Setiap flow screen wajib diuji secara lokal, baik flow optimal (Success) maupun flow terburuk (Offline mode / Timeout / Error response) dan tombol re-fetch dipastikan bekerja.

---
_Dokumen Guardrail ini telah disepakati dan menjadi landasan dalam pengerjaan teknis berikutnya._
