CREATE TABLE IF NOT EXISTS rate_limit_policies (
    id BIGSERIAL PRIMARY KEY,
    scope_type VARCHAR(32) NOT NULL,
    strategy VARCHAR(32) NOT NULL DEFAULT 'fixed_window',
    route VARCHAR(32) NOT NULL DEFAULT 'all',
    provider VARCHAR(100) NOT NULL DEFAULT '*',
    model VARCHAR(200) NOT NULL DEFAULT '*',
    window_unit VARCHAR(16) NOT NULL,
    max_requests BIGINT NULL,
    max_input_tokens BIGINT NULL,
    max_output_tokens BIGINT NULL,
    max_total_tokens BIGINT NULL,
    max_estimated_cost_usd NUMERIC(20, 8) NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (scope_type IN ('global', 'provider', 'model', 'route')),
    CHECK (strategy IN ('fixed_window')),
    CHECK (route IN ('all', 'interpret', 'respond')),
    CHECK (window_unit IN ('minute', 'hour', 'day')),
    CHECK (
        max_requests IS NOT NULL
        OR max_input_tokens IS NOT NULL
        OR max_output_tokens IS NOT NULL
        OR max_total_tokens IS NOT NULL
        OR max_estimated_cost_usd IS NOT NULL
    ),
    CHECK (max_requests IS NULL OR max_requests >= 0),
    CHECK (max_input_tokens IS NULL OR max_input_tokens >= 0),
    CHECK (max_output_tokens IS NULL OR max_output_tokens >= 0),
    CHECK (max_total_tokens IS NULL OR max_total_tokens >= 0),
    CHECK (max_estimated_cost_usd IS NULL OR max_estimated_cost_usd >= 0),
    CHECK (
        (scope_type <> 'global')
        OR (route = 'all' AND provider = '*' AND model = '*')
    ),
    CHECK (
        (scope_type <> 'route')
        OR (route <> 'all' AND provider = '*' AND model = '*')
    ),
    CHECK (
        (scope_type <> 'provider')
        OR (provider <> '*' AND model = '*')
    ),
    CHECK (
        (scope_type <> 'model')
        OR model <> '*'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_limit_policies_scope_window
    ON rate_limit_policies (scope_type, route, provider, model, window_unit);

CREATE INDEX IF NOT EXISTS idx_rate_limit_policies_lookup
    ON rate_limit_policies (enabled, route, provider, model, window_unit);

CREATE TABLE IF NOT EXISTS rate_limit_buckets (
    id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES rate_limit_policies (id) ON DELETE CASCADE,
    scope_type VARCHAR(32) NOT NULL,
    strategy VARCHAR(32) NOT NULL DEFAULT 'fixed_window',
    route VARCHAR(32) NOT NULL,
    provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    window_unit VARCHAR(16) NOT NULL,
    window_started_at TIMESTAMPTZ NOT NULL,
    window_ends_at TIMESTAMPTZ NOT NULL,
    request_count BIGINT NOT NULL DEFAULT 0,
    input_tokens BIGINT NOT NULL DEFAULT 0,
    output_tokens BIGINT NOT NULL DEFAULT 0,
    total_tokens BIGINT NOT NULL DEFAULT 0,
    estimated_cost_usd NUMERIC(20, 8) NOT NULL DEFAULT 0,
    deny_count BIGINT NOT NULL DEFAULT 0,
    last_request_id VARCHAR(255) NULL,
    last_generation_id VARCHAR(100) NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (scope_type IN ('global', 'provider', 'model', 'route')),
    CHECK (strategy IN ('fixed_window')),
    CHECK (route IN ('all', 'interpret', 'respond')),
    CHECK (window_unit IN ('minute', 'hour', 'day')),
    CHECK (window_ends_at > window_started_at),
    CHECK (request_count >= 0),
    CHECK (input_tokens >= 0),
    CHECK (output_tokens >= 0),
    CHECK (total_tokens >= 0),
    CHECK (estimated_cost_usd >= 0),
    CHECK (deny_count >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_rate_limit_buckets_policy_window_started_at
    ON rate_limit_buckets (policy_id, window_started_at);

CREATE INDEX IF NOT EXISTS idx_rate_limit_buckets_lookup
    ON rate_limit_buckets (route, provider, model, window_unit, window_started_at DESC);

CREATE INDEX IF NOT EXISTS idx_rate_limit_buckets_window_ends_at
    ON rate_limit_buckets (window_ends_at);

CREATE TABLE IF NOT EXISTS llm_request_ledger (
    id BIGSERIAL PRIMARY KEY,
    request_id VARCHAR(255) NOT NULL,
    generation_id VARCHAR(100) NOT NULL,
    route VARCHAR(32) NOT NULL,
    request_type VARCHAR(100) NOT NULL,
    provider VARCHAR(100) NOT NULL,
    primary_provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    requested_model VARCHAR(200) NOT NULL,
    latency_ms NUMERIC(12, 2) NULL,
    retry_count INTEGER NOT NULL DEFAULT 0,
    cache_status VARCHAR(16) NOT NULL,
    final_status VARCHAR(32) NOT NULL,
    error_class VARCHAR(255) NULL,
    error_code VARCHAR(100) NULL,
    fallback_used BOOLEAN NOT NULL DEFAULT FALSE,
    fallback_reason VARCHAR(100) NULL,
    attempted_providers JSONB NOT NULL DEFAULT '[]'::jsonb,
    upstream_request_id VARCHAR(255) NULL,
    provider_response_id VARCHAR(255) NULL,
    provider_model_version VARCHAR(200) NULL,
    finish_reason VARCHAR(100) NULL,
    candidate_index INTEGER NULL,
    input_tokens BIGINT NULL,
    output_tokens BIGINT NULL,
    total_tokens BIGINT NULL,
    estimated_cost_usd NUMERIC(20, 8) NULL,
    cache_key CHAR(64) NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ NULL,
    CHECK (route IN ('interpret', 'respond')),
    CHECK (cache_status IN ('hit', 'miss', 'bypass')),
    CHECK (retry_count >= 0),
    CHECK (input_tokens IS NULL OR input_tokens >= 0),
    CHECK (output_tokens IS NULL OR output_tokens >= 0),
    CHECK (total_tokens IS NULL OR total_tokens >= 0),
    CHECK (estimated_cost_usd IS NULL OR estimated_cost_usd >= 0),
    CHECK (jsonb_typeof(attempted_providers) = 'array'),
    CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_llm_request_ledger_request_id
    ON llm_request_ledger (request_id);

CREATE INDEX IF NOT EXISTS idx_llm_request_ledger_created_at
    ON llm_request_ledger (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_llm_request_ledger_route_created_at
    ON llm_request_ledger (route, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_llm_request_ledger_provider_model_created_at
    ON llm_request_ledger (provider, model, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_llm_request_ledger_generation_id
    ON llm_request_ledger (generation_id);

CREATE TABLE IF NOT EXISTS price_catalog_entries (
    id BIGSERIAL PRIMARY KEY,
    provider VARCHAR(100) NOT NULL,
    model VARCHAR(200) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    cost_unit VARCHAR(16) NOT NULL DEFAULT '1k_tokens',
    input_cost_per_unit_usd NUMERIC(20, 8) NULL,
    output_cost_per_unit_usd NUMERIC(20, 8) NULL,
    request_cost_usd NUMERIC(20, 8) NULL,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (cost_unit IN ('1k_tokens')),
    CHECK (
        input_cost_per_unit_usd IS NOT NULL
        OR output_cost_per_unit_usd IS NOT NULL
        OR request_cost_usd IS NOT NULL
    ),
    CHECK (input_cost_per_unit_usd IS NULL OR input_cost_per_unit_usd >= 0),
    CHECK (output_cost_per_unit_usd IS NULL OR output_cost_per_unit_usd >= 0),
    CHECK (request_cost_usd IS NULL OR request_cost_usd >= 0),
    CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_price_catalog_entries_effective_from
    ON price_catalog_entries (provider, model, effective_from);

CREATE INDEX IF NOT EXISTS idx_price_catalog_entries_lookup
    ON price_catalog_entries (provider, model, is_active, effective_from DESC);

CREATE OR REPLACE VIEW llm_request_daily_aggregates AS
SELECT
    DATE_TRUNC('day', created_at)::date AS usage_date,
    route,
    provider,
    model,
    COUNT(*) AS request_count,
    COUNT(*) FILTER (WHERE cache_status = 'hit') AS cache_hit_count,
    COUNT(*) FILTER (WHERE cache_status = 'miss') AS cache_miss_count,
    COUNT(*) FILTER (WHERE cache_status = 'bypass') AS cache_bypass_count,
    ROUND(
        CASE
            WHEN COUNT(*) = 0 THEN 0::numeric
            ELSE (COUNT(*) FILTER (WHERE cache_status = 'hit'))::numeric / COUNT(*)::numeric
        END,
        6
    ) AS cache_hit_ratio,
    COALESCE(SUM(retry_count), 0) AS retry_volume,
    COUNT(*) FILTER (WHERE fallback_used) AS fallback_count,
    COUNT(*) FILTER (WHERE final_status <> 'success') AS error_count,
    COALESCE(SUM(input_tokens), 0) AS input_tokens,
    COALESCE(SUM(output_tokens), 0) AS output_tokens,
    COALESCE(SUM(total_tokens), 0) AS total_tokens,
    COALESCE(SUM(COALESCE(estimated_cost_usd, 0)), 0)::NUMERIC(20, 8) AS estimated_cost_usd,
    MAX(created_at) AS last_request_at
FROM llm_request_ledger
GROUP BY DATE_TRUNC('day', created_at)::date, route, provider, model;

CREATE OR REPLACE VIEW llm_request_daily_route_aggregates AS
SELECT
    usage_date,
    route,
    SUM(request_count) AS request_count,
    SUM(cache_hit_count) AS cache_hit_count,
    SUM(cache_miss_count) AS cache_miss_count,
    SUM(cache_bypass_count) AS cache_bypass_count,
    ROUND(
        CASE
            WHEN SUM(request_count) = 0 THEN 0::numeric
            ELSE SUM(cache_hit_count)::numeric / SUM(request_count)::numeric
        END,
        6
    ) AS cache_hit_ratio,
    SUM(retry_volume) AS retry_volume,
    SUM(fallback_count) AS fallback_count,
    SUM(error_count) AS error_count,
    SUM(input_tokens) AS input_tokens,
    SUM(output_tokens) AS output_tokens,
    SUM(total_tokens) AS total_tokens,
    SUM(estimated_cost_usd)::NUMERIC(20, 8) AS estimated_cost_usd,
    MAX(last_request_at) AS last_request_at
FROM llm_request_daily_aggregates
GROUP BY usage_date, route;