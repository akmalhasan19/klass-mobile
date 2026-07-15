FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=7860

# ── System deps for Playwright Chromium ────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libdbus-1-3 libxkbcommon0 libatspi2.0-0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 ─────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Sidecar deps + Chromium ────────────────────────────────────────────
COPY app/engines/chromium_sidecar/sidecar/package.json ./sidecar/
RUN cd sidecar && npm install --omit=dev && npx playwright install chromium

# ── Python deps ────────────────────────────────────────────────────────
COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# ── Application code ───────────────────────────────────────────────────
COPY app ./app
COPY README.md ./README.md

EXPOSE 7860

CMD ["sh", "-lc", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
