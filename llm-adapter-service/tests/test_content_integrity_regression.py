import pytest
import time
from app.content_integrity_classifier import ContentIntegrityClassifier

@pytest.fixture
def classifier():
    return ContentIntegrityClassifier()

# --- 5.6 Regression Test Suite ---

def test_regression_known_good_payload(classifier):
    """Payload pedagogis bersih harus selalu mendapat skor tinggi (>= 0.90)."""
    known_good = {
        "title": "Fotosintesis pada Tumbuhan",
        "sections": [
            {
                "title": "Pengertian Fotosintesis",
                "content": "Fotosintesis adalah proses pembuatan makanan oleh tumbuhan hijau dengan bantuan energi cahaya matahari."
            },
            {
                "title": "Proses Fotosintesis",
                "content": "Klorofil menyerap energi cahaya matahari untuk mengubah air dan karbon dioksida menjadi glukosa dan oksigen."
            }
        ]
    }
    
    result = classifier.classify_payload(known_good, "pdf")
    assert result["integrity_score"] >= 0.90
    assert len(result["violations"]) == 0

def test_regression_known_bad_payload(classifier):
    """Payload dengan instruksi meta harus selalu terdeteksi dan skor rendah."""
    known_bad = {
        "content": "Here is your material. Follow these steps to teach the class: 1. Distribute handouts. 2. Explain the diagram."
    }
    
    result = classifier.classify_payload(known_bad, "pdf")
    # Should detect conversational filler AND procedural instruction
    assert result["integrity_score"] < 0.80
    pattern_names = [v["pattern_name"] for v in result["violations"]]
    assert "conversational_filler" in pattern_names
    assert "procedural_instruction" in pattern_names

def test_latency_performance(classifier):
    """Validasi integritas harus selesai dalam waktu < 200ms (Requirement 5.6)."""
    large_payload = {
        "title": "Test Latency",
        "sections": [{"title": f"Section {i}", "content": "Pedagogical content " * 50} for i in range(20)]
    }
    
    start_time = time.time()
    classifier.classify_payload(large_payload, "pdf")
    end_time = time.time()
    
    latency_ms = (end_time - start_time) * 1000
    print(f"Latency: {latency_ms:.2f}ms")
    assert latency_ms < 200, f"Latency too high: {latency_ms:.2f}ms"

def test_score_stability(classifier):
    """Memastikan skor konsisten untuk input yang sama."""
    payload = {
        "content": "This section is designed to introduce the topic. Follow these steps."
    }
    
    result1 = classifier.classify_payload(payload, "pdf")
    result2 = classifier.classify_payload(payload, "pdf")
    
    assert result1["integrity_score"] == result2["integrity_score"]
    assert len(result1["violations"]) == len(result2["violations"])
