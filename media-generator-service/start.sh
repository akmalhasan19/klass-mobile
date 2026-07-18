#!/bin/sh
set -e

echo "Starting Arq worker in background..."
python -m app.worker_entrypoint &
WORKER_PID=$!

echo "Starting Uvicorn server in foreground..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-7860}"
