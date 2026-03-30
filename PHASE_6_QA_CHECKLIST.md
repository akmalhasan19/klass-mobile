# Phase 6 Manual QA Checklist (Android & iOS)

Dokumen ini adalah checklist eksekusi QA manual untuk validasi akhir flow kritikal pada device nyata.
Tanggal penyusunan: 31 Maret 2026.

## Scope

- Login -> Home feed
- Profile update + avatar upload
- Bookmark create/read/delete
- Gallery load + preview
- Search + filter
- Uji jaringan lambat/putus
- Regression: tidak ada layar utama membaca dummy data

## Prasyarat

- Backend Laravel aktif dan bisa diakses device.
- Database berisi seed minimum untuk Topic, Content, MarketplaceTask.
- Bucket storage aktif dan public URL dapat diakses.
- Build terbaru terpasang di Android dan iOS.
- Akun uji tersedia: user baru dan user existing.

## Matrix Eksekusi

| Platform | OS/Version | Device | Build | Tester | Tanggal | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Android |  |  |  |  |  | ☐ |
| iOS |  |  |  |  |  | ☐ |

## Test Case Detail

### TC-01 Login ke Home Feed

Langkah:
1. Buka aplikasi pada kondisi fresh install.
2. Login dengan akun valid.
3. Pastikan diarahkan ke Home.
4. Verifikasi section Project Suggestions tampil data API.
5. Verifikasi section Top Freelancers tampil data API atau empty state yang valid.

Expected:
- Login sukses.
- Token tersimpan dan sesi aktif.
- Home menampilkan loading -> success/empty/error state dengan benar.
- Tidak ada crash.

Evidence:
- Screenshot Home setelah login.
- Capture log error (jika ada).

Status: ☐ Pass / ☐ Fail

### TC-02 Update Profile + Upload Avatar

Langkah:
1. Masuk ke Account Settings.
2. Upload avatar baru dari gallery device.
3. Simpan perubahan profile jika ada field lain.
4. Kembali ke Profile dan refresh app.

Expected:
- Avatar upload berhasil.
- URL avatar baru muncul di profile.
- Avatar tetap sama setelah app restart.

Evidence:
- Screenshot sebelum/sesudah upload.
- Bukti URL avatar berubah.

Status: ☐ Pass / ☐ Fail

### TC-03 Bookmark Create/Read/Delete

Langkah:
1. Buat item bookmark/workspace baru.
2. Pastikan item muncul pada list.
3. Tutup dan buka ulang aplikasi.
4. Verifikasi item tetap ada.
5. Hapus item.

Expected:
- Create/read/delete berhasil.
- Data tetap konsisten setelah restart.
- Tidak ada duplikasi atau stale state.

Evidence:
- Screenshot list sebelum/selesai delete.

Status: ☐ Pass / ☐ Fail

### TC-04 Gallery Load dan Preview

Langkah:
1. Buka Gallery dari Workspace.
2. Verifikasi grid tampil dari API.
3. Coba buka item gambar dan non-gambar.
4. Verifikasi fallback tampil saat image gagal dimuat.

Expected:
- Data gallery tampil.
- Preview berfungsi.
- Fallback broken image tampil rapi saat URL tidak valid.

Evidence:
- Screenshot gallery loaded.
- Screenshot fallback (jika ada).

Status: ☐ Pass / ☐ Fail

### TC-05 Search + Filter

Langkah:
1. Buka Search screen.
2. Input keyword yang pasti ada.
3. Terapkan filter kategori.
4. Ulangi dengan keyword yang tidak ada.

Expected:
- Hasil sesuai query server.
- Filter mempersempit hasil.
- No result state informatif.

Evidence:
- Screenshot hasil ada dan no result.

Status: ☐ Pass / ☐ Fail

### TC-06 Simulasi Jaringan Lambat/Putus

Android:
1. Aktifkan emulator network throttling (Slow 3G) atau gunakan Android Studio Network Profiler.
2. Ulangi TC-01 dan TC-04.
3. Putuskan jaringan total (Airplane mode / disable network).

iOS:
1. Gunakan Network Link Conditioner (Very Bad Network).
2. Ulangi TC-01 dan TC-04.
3. Putuskan jaringan total.

Expected:
- Timeout/retry behavior berjalan.
- UI menampilkan error state + tombol retry.
- Saat jaringan kembali, retry berhasil.

Evidence:
- Screenshot loading lama, error state, dan recovery success.

Status: ☐ Pass / ☐ Fail

### TC-07 Regression Dummy Data

Langkah:
1. Navigasi Home, Search, Workspace, Gallery, Profile.
2. Audit visual apakah ada avatar/image default dummy statis.
3. Audit data list apakah masih hardcoded domain data utama.

Expected:
- Tidak ada ketergantungan data domain utama dari dummy list.
- Jika media URL kosong, tampil placeholder netral, bukan dummy asset hardcoded.

Evidence:
- Screenshot tiap layar utama.
- Catatan item yang masih perlu cleanup (jika ada).

Status: ☐ Pass / ☐ Fail

## Ringkasan Hasil QA

- Android: ☐ Pass / ☐ Fail
- iOS: ☐ Pass / ☐ Fail
- Blocking issue: ______________________
- Non-blocking issue: __________________
- Rekomendasi release candidate: ☐ Go / ☐ No-Go
