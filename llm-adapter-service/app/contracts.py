HEALTH_SCHEMA_VERSION = "llm_adapter_health.v1"
OPS_SUMMARY_SCHEMA_VERSION = "llm_adapter_ops.v1"
SIGNATURE_ALGORITHM = "hmac-sha256"
DEFAULT_INTERPRETATION_PROVIDER = "gemini"
DEFAULT_DELIVERY_PROVIDER = "gemini"
SUPPORTED_PROVIDERS = ("gemini", "openai")
SUPPORTED_OUTPUT_FORMATS = ("docx", "pdf", "pptx")
SUPPORTED_PREFERRED_OUTPUT_TYPES = ("auto", *SUPPORTED_OUTPUT_FORMATS)
INTERPRET_ROUTE = "interpret"
RESPOND_ROUTE = "respond"
INTERPRET_REQUEST_TYPE = "media_prompt_interpretation"
RESPOND_REQUEST_TYPE = "media_delivery_response"
INTERPRETATION_SCHEMA_VERSION = "media_prompt_understanding.v1"
DELIVERY_RESPONSE_SCHEMA_VERSION = "media_delivery_response.v1"
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com"
GEMINI_API_VERSION = "v1beta"
GEMINI_DEFAULT_INTERPRETATION_MODEL = "gemini-2.0-flash"
GEMINI_DEFAULT_DELIVERY_MODEL = "gemini-2.0-flash"
OPENAI_BASE_URL = "https://api.openai.com"
OPENAI_RESPONSES_PATH = "/v1/responses"
OPENAI_DEFAULT_INTERPRETATION_MODEL = "gpt-5.4"
OPENAI_DEFAULT_DELIVERY_MODEL = "gpt-5.4"
DEFAULT_CACHE_KEY_SCHEMA_VERSION = "llm_adapter_cache.v1"
DEFAULT_PROVIDER_FALLBACK_ERROR_CODES = (
	"provider_timeout",
	"provider_connection_failed",
	"provider_rate_limited",
	"provider_unavailable",
)
LOGGER_NAME = "klass-llm-adapter"
REQUEST_ID_HEADER = "X-Request-Id"
GENERATION_ID_HEADER = "X-Klass-Generation-Id"
TIMESTAMP_HEADER = "X-Klass-Request-Timestamp"
SIGNATURE_ALGORITHM_HEADER = "X-Klass-Signature-Algorithm"
SIGNATURE_HEADER = "X-Klass-Signature"
LLM_PROVIDER_HEADER = "X-Klass-LLM-Provider"
LLM_MODEL_HEADER = "X-Klass-LLM-Model"
LLM_PRIMARY_PROVIDER_HEADER = "X-Klass-LLM-Primary-Provider"
LLM_FALLBACK_USED_HEADER = "X-Klass-LLM-Fallback-Used"
LLM_FALLBACK_REASON_HEADER = "X-Klass-LLM-Fallback-Reason"
