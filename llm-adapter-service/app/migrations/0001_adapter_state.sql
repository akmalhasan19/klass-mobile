CREATE TABLE IF NOT EXISTS interpretation_cache_entries (
    id BIGSERIAL PRIMARY KEY,
    cache_key CHAR(64) NOT NULL,
    request_payload JSONB NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count BIGINT NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ NULL,
    CHECK (hit_count >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_interpretation_cache_entries_cache_key
    ON interpretation_cache_entries (cache_key);

CREATE INDEX IF NOT EXISTS idx_interpretation_cache_entries_expires_at
    ON interpretation_cache_entries (expires_at);

CREATE TABLE IF NOT EXISTS delivery_cache_entries (
    id BIGSERIAL PRIMARY KEY,
    cache_key CHAR(64) NOT NULL,
    request_payload JSONB NOT NULL,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    hit_count BIGINT NOT NULL DEFAULT 0,
    last_hit_at TIMESTAMPTZ NULL,
    CHECK (hit_count >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_cache_entries_cache_key
    ON delivery_cache_entries (cache_key);

CREATE INDEX IF NOT EXISTS idx_delivery_cache_entries_expires_at
    ON delivery_cache_entries (expires_at);