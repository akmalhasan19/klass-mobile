from __future__ import annotations

GENERATION_SPEC_VERSION = "media_generation_spec.v1"
INTERPRETATION_SCHEMA_VERSION = "media_prompt_understanding.v1"
ARTIFACT_METADATA_VERSION = "media_generator_output_metadata.v1"
HEALTH_SCHEMA_VERSION = "media_generator_health.v1"
RESPONSE_SCHEMA_VERSION = "media_generator_response.v1"
SIGNATURE_ALGORITHM = "hmac-sha256"

SUPPORTED_EXPORT_FORMATS = ("docx", "pdf", "pptx")
IMPLEMENTED_EXPORT_FORMATS = ("docx", "pdf", "pptx")

DOCX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
PDF_MIME_TYPE = "application/pdf"

MIME_TYPES = {
    "docx": DOCX_MIME_TYPE,
    "pdf": PDF_MIME_TYPE,
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}

LARAVEL_ERROR_ARTIFACT_INVALID = "artifact_invalid"
LARAVEL_ERROR_PYTHON_SERVICE_UNAVAILABLE = "python_service_unavailable"
