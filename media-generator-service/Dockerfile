FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=7860 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers

# ── Node.js 20 ─────────────────────────────────────────────────────────
# Installed early so both npm and npx are available for sidecar deps.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Sidecar deps + Chromium ────────────────────────────────────────────
# Copy package.json to the *actual* script location so `npm install`
# places node_modules/ where ESM resolution expects them (same directory
# as chromium_sidecar.js).  `--with-deps` lets Playwright install both
# the Chromium binary and its OS-level library dependencies in one step
# (replacing the manual apt list).
COPY app/engines/chromium_sidecar/sidecar/package.json \
     ./app/engines/chromium_sidecar/sidecar/
RUN cd app/engines/chromium_sidecar/sidecar \
    && npm install --omit=dev \
    && npx playwright install --with-deps chromium

# ── Python deps ────────────────────────────────────────────────────────
COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# ── Application code ───────────────────────────────────────────────────
# node_modules/ already in place from the earlier RUN; COPY merges into
# the existing tree without clobbering (the source .dockerignore
# excludes the local node_modules/ from the build context).
COPY app ./app
COPY README.md ./README.md

EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT:-7860}/health || exit 1

CMD ["sh", "-lc", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
