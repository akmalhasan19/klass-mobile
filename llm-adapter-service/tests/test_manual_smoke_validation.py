import pytest
from app.content_integrity_classifier import ContentIntegrityClassifier

@pytest.fixture
def classifier():
    return ContentIntegrityClassifier()

def test_smoke_rpp_baseline_validation(classifier):
    """
    Smoke Test: Menggunakan konten dari RPP-IPA-SD.pdf sebagai baseline.
    Konten asli harus mendapat skor sangat tinggi dan tidak ada deteksi pelanggaran.
    """
    # Cuplikan teks dari RPP-IPA-SD.pdf
    rpp_content = {
        "title": "RENCANA PELAKSANAAN PEMBELAJARAN (RPP)",
        "context": {
            "satuan_pendidikan": "SD NEGERI 29 IDAI",
            "tema": "Benda Hewan dan Tanaman di Sekitarku",
            "sub_tema": "Tumbuhan di Sekitarku"
        },
        "sections": [
            {
                "title": "TUJUAN PEMBELAJARAN",
                "bullets": [
                    "Setelah membaca teks, siswa dapat menyebutkan tanaman yang hidup di air dengan benar.",
                    "Setelah membaca teks, siswa dapat menyebutkan minimal dua tanaman yang hidup di air dengan benar.",
                    "Setelah mengamati lingkungan sekitar, siswa dapat menyebutkan jenis tanaman berdasarkan tempat tinggal dengan benar."
                ]
            },
            {
                "title": "MATERI PEMBELAJARAN",
                "content": "Kelompok Tanaman Darat dan Tanaman Air. Membaca Grafik Gambar."
            }
        ]
    }
    
    result = classifier.classify_payload(rpp_content, "pdf")
    
    # Baseline pedagogis murni harus >= 0.95
    assert result["integrity_score"] >= 0.95
    assert len(result["violations"]) == 0
    print(f"RPP Baseline Score: {result['integrity_score']}")

def test_cross_curriculum_math_smv_mock(classifier):
    """Simulasi konten Matematika SMP (SPLDV) sesuai rencana 5.7."""
    math_content = {
        "title": "Sistem Persamaan Linear Dua Variabel (SPLDV)",
        "learning_objectives": [
            "Siswa dapat mendefinisikan persamaan linear dua variabel.",
            "Siswa dapat menentukan penyelesaian SPLDV dengan metode eliminasi."
        ],
        "sections": [
            {
                "title": "Konsep Dasar",
                "content": "Bentuk umum SPLDV adalah ax + by = c dan dx + ey = f."
            },
            {
                "title": "Contoh Soal",
                "content": "Tentukan nilai x dan y dari: x + y = 5 dan x - y = 1."
            }
        ]
    }
    
    result = classifier.classify_payload(math_content, "pdf")
    assert result["integrity_score"] >= 0.95
    assert "procedural_instruction" not in [v["pattern_name"] for v in result["violations"]]
