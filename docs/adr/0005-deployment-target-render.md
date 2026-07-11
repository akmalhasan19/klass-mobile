# ADR-005: Deployment Target — Render Web Service

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-07-11 |
| **Deciders** | Engineering Team |
| **Supersedes** | — |

---

## Context

Gateway Rust memerlukan hosting yang:
- Region sama dengan Neon PostgreSQL (Singapore `ap-southeast-1`) untuk latency <5ms DB connection
- Support Docker deployment (multi-stage build, binary <30MB)
- Health check endpoint (`GET /health`) untuk auto-recovery
- GitHub-integrated CI/CD (auto-deploy dari `main` branch)
- Biaya ≤ baseline Laravel ($0-20/mo) + margin 50%

3 HF Space akan berkurang menjadi 1 (Media Gen only), sehingga budget infrastruktur harus dioptimalkan.

## Decision

**Render Web Service — Starter tier ($7/bln), Singapore region.**

```
Deployment pipeline:
  GitHub Push (main)  →  GitHub Actions (lint → test → build)  →  Render Deploy
                                                                     │
                                                              Render Web Service
                                                              (Docker container)
                                                              Port: 8080 (REST)
                                                              Port: 50051 (gRPC)
                                                              Health: GET /health
```

### Render Spec

| Parameter | Value |
|-----------|-------|
| Tier | Starter |
| Cost | **$7/bulan** |
| RAM | 512 MB |
| CPU | 0.5 vCPU (shared) |
| Bandwidth | 100 GB outgoing (cukup untuk API JSON) |
| Region | `ap-southeast-1` (Singapore) — same as Neon |
| Deployment | Dockerfile (multi-stage) |
| Auto-deploy | Yes (GitHub integration) |
| Health check | `GET /health` → 200 OK |

## Alternatives Considered

### Fly.io

| Pro | Kontra |
|-----|--------|
| Free tier tersedia (3 shared VMs) | Free tier limit ketat: 256MB RAM — Gateway butuh ~50MB idle, tight margin |
| Region Singapore tersedia | Deployment lebih kompleks: `fly.toml` + `flyctl` CLI |
| Auto-scaling built-in | Cold start dari suspend (free tier) — latency spike |
| | Billable lebih mahal di atas free tier |

### Railway

| Pro | Kontra |
|-----|--------|
| GitHub integration seamless | Starter $5/mo tapi 512MB RAM, 0.25 vCPU — lebih rendah dari Render |
| Simple, developer-friendly | Tidak ada Singapore region! Hanya `us-west4` + `us-east4` — latency ke Neon >100ms |
| | Belum mature untuk production workload |

### AWS (ECS Fargate + ALB)

| Pro | Kontra |
|-----|--------|
| Infra paling flexible | **Biaya minimum ~$35-50/bulan** (ALB $22 + Fargate $15 + NAT) |
| Singapore region (`ap-southeast-1`) | Overkill untuk single binary Rust |
| Auto-scaling, monitoring built-in | Setup kompleks: VPC, security groups, IAM roles, ECR |

### Self-hosted (VPS: Vultr / DigitalOcean)

| Pro | Kontra |
|-----|--------|
| $6/bulan, 1GB RAM, 1 vCPU | Tidak ada auto-deploy dari GitHub (perlu setup webhook manual) |
| Singapore region tersedia | Harus manage OS, Docker daemon, SSL cert, firewall sendiri |
| Resource dedicated (tidak shared CPU) | Operational overhead — tidak sepadan dengan $1 selisih dari Render |

### Kenapa Render menang

| Faktor | Render |
|--------|--------|
| Cost | $7/bulan — dalam budget, netral/turun dari baseline |
| Region | Singapore — same as Neon (<5ms latency) |
| DX | GitHub auto-deploy, Dockerfile-native, zero infra config |
| Health check | Built-in HTTP health check → auto-restart jika fail |
| Logging | Stdout/stderr `tracing` JSON → Render log viewer |
| Scale | Bisa upgrade ke `Standard` ($25/mo) tanpa migrasi jika traffic naik |

## Cost Comparison

| Komponen | Before | After | Delta |
|----------|--------|-------|-------|
| HF Space #1 (Laravel) | $0-20 | $0 | -$0-20 |
| HF Space #2 (LLM Adapter) | $0-20 | $0 | -$0-20 |
| HF Space #3 (Media Gen) | $0-20 | $0-20 | 0 |
| Neon PostgreSQL | $0 (free) | $0 (free) | 0 |
| Cloudflare R2 | $0-5 | $0-5 | 0 |
| Upstash Redis | $0 | $0 (free) | 0 |
| **Render Web Service** | **$0** | **$7** | **+$7** |
| **Total** | **~$0-65** | **~$7-32** | **hemat $0-33** |

## Consequences

### Positive

- **Cost**: Hemat $0-33/bulan vs baseline (2 HF Space dihapus)
- **Latency**: <5ms ke Neon PostgreSQL (same Singapore region)
- **Simplicity**: 1 service, 1 Dockerfile, 1 deployment target
- **Auto-recovery**: Render health check auto-restart jika Gateway crash

### Negative / Mitigation

| Risk | Mitigation |
|------|-----------|
| Render Starter CPU shared → noisy neighbor | Rust binary ringan (<50MB RSS idle) — tidak CPU-intensive; jika perlu, upgrade ke $25 Standard |
| 512MB RAM tight untuk concurrent connections | Rust memory efisien (~50MB baseline); 1000 idle connections ≈ 30-50MB — ample headroom |
| Cold start setelah idle period | Render health check ping → Gateway selalu warm; cold start <5s untuk binary Rust |
| Tidak ada built-in DDoS protection | Cloudflare proxy di depan Render (opsional, $0 untuk basic) |

---

## References

- `IMPLEMENTATION_PLAN.md` — Infrastructure Cost table
- `IMPLEMENTATION_PLAN.md` — Task 3.3 (Infrastructure Setup)
- `render.com` — Starter tier specs
