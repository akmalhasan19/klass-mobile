# Continuous Deployment: Render Web Service

> **Plan ref**: Task 3.2 (CI/CD Pipeline), Task 3.3 (Infrastructure Setup)
> **Date**: 2026-07-11

---

## GitHub Environment Setup

### 1. Create Environments

```
Repository Settings → Environments → New Environment

Environment: staging
  - No protection rules (auto-deploy from main)

Environment: production
  - Required reviewers: ≥ 1 (this provides "manual approval" gate)
  - Wait timer: 0 minutes
  - Deployment branches: main
```

### 2. Configure Environment Secrets

| Environment | Secret Name | Value Source |
|-------------|-------------|-------------|
| `staging` | `RENDER_STAGING_DEPLOY_HOOK_URL` | Render Dashboard → Staging Service → Settings → Deploy Hook |
| `staging` | `STAGING_URL` | Render Dashboard → Staging Service URL |
| `production` | `RENDER_DEPLOY_HOOK_URL` | Render Dashboard → Production Service → Settings → Deploy Hook |

### 3. Configure Repository Secrets

| Secret | Value |
|--------|-------|
| `CODECOV_TOKEN` | Codecov upload token |
| `GITHUB_TOKEN` | Auto-available (GitHub Actions) |

---

## Render Web Service Setup

### Service 1: Production (`klass-gateway-prod`)

```yaml
# Settings → Render Dashboard
Name:              klass-gateway-prod
Type:              Web Service
Runtime:           Docker
Region:            Singapore (ap-southeast-1)
Plan:              Starter ($7/month)
Branch:            main
Auto-Deploy:       Off (controlled by GitHub Actions)
Health Check Path: /health

Environment Variables:
  DATABASE_URL:        ${{ from Neon connection string }}
  RUST_LOG:            info,klass_gateway=debug
  # ... (full list from .env.local template)
```

### Service 2: Staging (`klass-gateway-staging`)

```yaml
Name:              klass-gateway-staging
Type:              Web Service
Runtime:           Docker
Region:            Singapore (ap-southeast-1)
Plan:              Starter ($7/month)  # or use Free tier if available
Branch:            main
Auto-Deploy:       On (every push to main)
Health Check Path: /health

Environment Variables:
  DATABASE_URL:        ${{ from Neon staging branch }}
  RUST_LOG:            debug
  # ... (same set as production, pointed to staging infra)
```

---

## Pipeline Flow

```
PR opened
  │
  ▼
  ├── fmt-check  (parallel) ──► pass/fail
  ├── clippy     (parallel) ──► pass/fail
  └── sqlx-check (parallel) ──► pass/fail
        │
        ▼ (all pass)
      test (cargo nextest + DB migrations)
        │
        ▼ (pass)
      audit (cargo audit) — weekly only
        │
        ▼ (on merge to main)
      build (Docker image: cargo build --release)
        │
        ▼
      deploy-staging (auto)
        │
        ▼
      deploy-prod (manual approval via GitHub Environment → "Review deployments")
        │
        ▼
      ✓ Live at https://api.klass.app/health → {"status":"ok","version":"1.0.0"}
```

---

## Rollback Procedure

If production deploy fails:

1. **Immediate**: Git revert the offending commit, push to `main`
2. **GitHub UI**: Go to Deployments → latest production deployment → "Re-deploy" (uses previous commit)
3. **Render Dashboard**: Render → Services → Rollback to previous deploy

Laravel keep-alive: 7 days post-cutover (Fase 6). If Rust Gateway fails within 7 days of cutover, DNS is pointed back to Laravel which is still running in read-only mode.

---

## Deployment Verification Checklist

After each production deploy, verify:

- [ ] `GET /health` returns 200 with `{"status":"ok"}`
- [ ] `GET /v1/topics` returns paginated topics (public endpoint, no auth)
- [ ] `POST /v1/auth/login` with test credentials returns token
- [ ] `GET /v1/auth/me` with Bearer token returns user data
- [ ] Redis `XADD` test: enqueue dummy job, verify `XREADGROUP` returns it
- [ ] Neon DB pool: ≤ 5 connections active (monitor via Neon dashboard)
- [ ] Render logs: no `ERROR` entries in first 5 minutes
- [ ] p99 latency < 200ms for `GET /health`

---

## References

- `IMPLEMENTATION_PLAN.md` — Task 3.2 (CI/CD Pipeline), Task 3.3 (Infrastructure Setup)
- `.github/workflows/gateway-ci.yml` — Full CI/CD workflow definition
- `gateway/Dockerfile` — Multi-stage Docker build
- `gateway/.env.local` — Environment variable template
- ADR-005 (`docs/adr/0005-deployment-target-render.md`) — Render decision
