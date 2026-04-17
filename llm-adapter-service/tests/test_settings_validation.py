import os
import pytest
from decimal import Decimal
from app.settings import get_settings, clear_settings_cache

def test_default_content_integrity_threshold():
    """Validasi nilai default untuk content_integrity_threshold."""
    clear_settings_cache()
    if "LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD" in os.environ:
        del os.environ["LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD"]
        
    settings = get_settings()
    assert settings.content_integrity_threshold == Decimal("0.75")

def test_env_override_content_integrity_threshold():
    """Validasi override variabel lingkungan untuk content_integrity_threshold."""
    os.environ["LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD"] = "0.85"
    clear_settings_cache()
    
    settings = get_settings()
    assert settings.content_integrity_threshold == Decimal("0.85")
    
    # Cleanup
    del os.environ["LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD"]
    clear_settings_cache()

def test_invalid_content_integrity_threshold_uses_default():
    """Validasi nilai tidak valid akan kembali ke default (via _clean_decimal)."""
    os.environ["LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD"] = "invalid"
    clear_settings_cache()
    
    settings = get_settings()
    assert settings.content_integrity_threshold == Decimal("0.75")
    
    # Cleanup
    del os.environ["LLM_ADAPTER_CONTENT_INTEGRITY_THRESHOLD"]
    clear_settings_cache()
