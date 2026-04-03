# Recommended Projects - Domain Model dan Contract Design

Dokumen ini berisi definisi schema, API contract, dan aturan bisnis untuk fitur Recommended Projects yang akan digunakan oleh Homepage Configurator, backend API, dan Flutter app.

## 1. Schema Entitas `recommended_projects`

Tabel ini akan menyimpan project showcase yang di-upload oleh admin maupun referensi ke rekomendasi dari sistem/AI.

### Kolom Minimum:
- `id` (bigint, unsigned, auto_increment, primary key)
- `title` (string, max 255) - Judul project
- `description` (text, nullable) - Deskripsi singkat project
- `thumbnail_url` (string, nullable) - URL gambar thumbnail project
- `ratio` (string, default '16:9') - Rasio aspek thumbnail (misal: '16:9', '1:1', '4:3')
- `project_type` (string, nullable) - Tipe project (misal: 'mobile', 'web', 'ui_ux')
- `tags` (json, nullable) - Array of strings untuk tag teknologi/kategori
- `modules` (json, nullable) - Array of strings/objects untuk modul/fitur yang ada di project
- `source_type` (enum) - Sumber dari rekomendasi ini. Nilai yang diizinkan: `admin_upload`, `system_topic`, `ai_generated`.
- `source_reference` (string/bigint, nullable) - ID referensi ke sumber asli jika `source_type` bukan `admin_upload` (contoh: Topic ID).
- `display_priority` (int, default 0) - Prioritas urutan tampil. Angka lebih tinggi = lebih di atas.
- `is_active` (boolean, default true) - Status aktif/nonaktif secara manual oleh admin.
- `starts_at` (timestamp, nullable) - Waktu mulai project ditampilkan (untuk scheduling).
- `ends_at` (timestamp, nullable) - Waktu berakhir project ditampilkan (untuk expiration).
- `created_by` (bigint, unsigned, nullable) - User ID admin pembuat.
- `updated_by` (bigint, unsigned, nullable) - User ID admin pengubah terakhir.
- `timestamps` (created_at, updated_at)

### Relasi:
- `Creator` (User) melalui `created_by`
- `Updater` (User) melalui `updated_by`

## 2. API Payload Response (Mobile Contract)

Response ini digunakan oleh mobile untuk menampilkan card di feed dan detail bottom sheet. Semua item dari `admin_upload` maupun `system_topic` akan dinormalisasi ke format ini.

```json
{
  "data": [
    {
      "id": "1",
      "title": "Aplikasi Kasir UMKM",
      "description": "Sistem Point of Sales lengkap dengan fitur inventory dan laporan keuangan.",
      "thumbnail_url": "https://example.com/storage/projects/kasir.jpg",
      "ratio": "16:9",
      "project_type": "mobile",
      "tags": ["Flutter", "Laravel", "PostgreSQL"],
      "modules": ["Auth", "Inventory", "Transaction", "Reports"],
      "source_type": "admin_upload",
      "display_priority": 100,
      "visibility": {
        "is_active": true,
        "starts_at": null,
        "ends_at": null
      }
    },
    {
      "id": "system_topic_5",
      "title": "Belajar React Fundamental",
      "description": "Pahami konsep dasar React dari komponen hingga state management.",
      "thumbnail_url": "https://example.com/storage/topics/react.jpg",
      "ratio": "16:9",
      "project_type": "web",
      "tags": ["React", "JavaScript", "Frontend"],
      "modules": [],
      "source_type": "system_topic",
      "display_priority": 0,
      "visibility": {
        "is_active": true,
        "starts_at": null,
        "ends_at": null
      }
    }
  ],
  "meta": {
    "total": 2,
    "source_breakdown": {
      "admin_upload": 1,
      "system_topic": 1,
      "ai_generated": 0
    }
  }
}
```

## 3. Aturan Bisnis

### A. Fallback Contract
Jika source tidak memiliki data yang lengkap (misalnya `system_topic` tidak punya `modules` atau `tags`), agregator wajib mengembalikan default value:
- `modules`: `[]` (empty array)
- `tags`: `[]` (empty array)
- `thumbnail_url`: `null` (UI mobile harus memiliki placeholder default fallback)
- `description`: `null` (UI mobile menangani nullable text)

### B. Aturan Merge dan Sorting Final
Rekomendasi dari berbagai sumber akan digabung menjadi satu array dan di-sorting berdasarkan:
1. `display_priority` (Descending) - Item dengan priority lebih besar tampil lebih atas.
2. `created_at` (Descending) - Fallback jika priority sama, item terbaru tampil lebih atas.

Strategi Mapping `system_topic`:
- `id` -> `system_topic_{id}`
- `title` -> `name` (dari Topic)
- `description` -> `description` (dari Topic)
- `thumbnail_url` -> di-resolve dari relasi media/gambar Topic.
- `source_type` -> `system_topic`
- `display_priority` -> default `0` (Kecuali ada mekanisme scoring).

### C. Aturan Visibility Item
Sebuah item hanya akan ditampilkan di API feed mobile jika memenuhi **semua** syarat berikut:
1. `is_active` bernilai `true`.
2. Jika `starts_at` tidak null, waktu saat ini (now) harus `>= starts_at`.
3. Jika `ends_at` tidak null, waktu saat ini (now) harus `<= ends_at`.

Status ini berlaku untuk filtering pada sisi agregator backend, sehingga API ke mobile hanya mengembalikan list yang benar-benar siap tayang.
