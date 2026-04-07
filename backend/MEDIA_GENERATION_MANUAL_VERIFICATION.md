# Media Generation Manual Verification

Dokumen ini dipakai untuk phase 10.3 agar verifikasi end-to-end media generator bisa diulang di local, staging, atau target deploy.

## Prasyarat

1. Backend Laravel, queue worker, dan Python media generator service sudah aktif.
2. Environment media generation sudah terisi, termasuk interpreter URL, delivery URL, Python base URL, dan shared secret.
3. Teacher account sudah tersedia.

## Langkah Verifikasi

1. Login ke aplikasi menggunakan akun teacher/guru.
2. Buka Home dan kirim prompt dari section `Generate Learning Topics`.
   Contoh: `Buatkan deck termodinamika untuk kelas 11 dengan latihan singkat di akhir.`
3. Verifikasi backend membuat record `media_generations`.
   Contoh query: `SELECT id, status, preferred_output_type, resolved_output_type FROM media_generations ORDER BY created_at DESC LIMIT 5;`
4. Verifikasi payload interpretasi tersimpan dan valid.
   Kolom yang perlu dicek: `interpretation_payload`, `generation_spec_payload`, `decision_payload`.
5. Verifikasi resolved output type mengikuti keputusan sistem atau override teacher.
   Jika request memakai override, pastikan `resolved_output_type` sama dengan override.
6. Verifikasi Python service menghasilkan artifact sesuai format target.
   Cek `generator_service_response.response.artifact_metadata` dan endpoint health Python.
7. Verifikasi artifact ter-upload ke storage dan thumbnail tersedia bila format mendukung.
   Kolom yang perlu dicek: `storage_path`, `file_url`, `thumbnail_url`, `mime_type`.
8. Verifikasi hasil masuk ke Workspace.
   Cek `GET /api/topics?search=<judul hasil>` atau buka daftar workspace di aplikasi.
9. Verifikasi hasil masuk ke Homepage recommendation feed sebagai item `ai_generated`.
   Cek `GET /api/homepage-recommendations` dan pastikan `source_type=ai_generated`.
10. Verifikasi kartu hasil teacher menampilkan CTA `download`, `open`, dan `share`, lalu jalankan ketiganya dari aplikasi.

## Smoke Checks Tambahan

1. Jalankan `php artisan media-generation:smoke-python-service` dari folder `backend/` untuk memastikan Laravel bisa reach Python service.
2. Jalankan `php artisan test --testdox tests/Feature/Phase10EndToEndVerificationTest.php` untuk harness verifikasi backend.
3. Jalankan `flutter test test/screens/home_screen_media_generation_flow_test.dart test/widgets/media_generation_status_card_test.dart test/screens/home_screen_media_generation_role_test.dart` dari folder `frontend/` untuk regression UI teacher flow.