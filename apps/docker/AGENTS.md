# AGENTS.md

This file is generated from .ai/rules. Edit the source templates there, then run scripts/sync-agent-docs.ps1 or scripts/sync-agent-docs.sh.

> Covers all Docker and Docker Compose configuration for this project.
> Docker configs live here. Never put environment-specific logic in the base compose file.

---

## Service Layout

| Service | Container name | Notes |
|---|---|---|
| Backend (NestJS) | `api` | |
| Frontend (Next.js / Expo web) | `web` | |
| Database (PostgreSQL) | `db` | |
| Cache (Redis) | `redis` | Only if the project uses it |

---

## Compose File Structure

```
docker-compose.yml           <- base: shared structure, no env-specific values
docker-compose.dev.yml       <- dev: bind mounts, debug ports, no restart policy
docker-compose.test.yml      <- test: isolated DB, no persistent volume, seed on start
docker-compose.staging.yml   <- staging: named volumes, stricter resource limits
docker-compose.prod.yml      <- prod: restart policies, no exposed debug ports, resource limits
```

**Rules:**
- The base file defines services, networks, and volumes - nothing else.
- Env-specific values (ports, volumes, replicas, restart policy) belong in the override file only.
- Never use `docker-compose.override.yml` - it applies automatically and silently, making it hard to reason about what is active.

**How to run per environment:**

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Test
docker compose -f docker-compose.yml -f docker-compose.test.yml up

# Staging / Prod
docker compose -f docker-compose.yml -f docker-compose.staging.yml up
```

---

## Development Setup

During active development, run **only infrastructure** in Docker. Run the app directly on the host.

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up db redis
pnpm dev   # runs api and web on host
```

Running the full stack in Docker during development slows down hot reload and makes breakpoints harder to attach.

---

## Health Checks

Every service must define a health check. Without it, Docker marks a container as `running` before the process is ready, causing dependent services to connect too early.

```yaml
# api
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 15s

# db (PostgreSQL)
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
  interval: 10s
  timeout: 5s
  retries: 5
```

Use `depends_on: condition: service_healthy` - not just `depends_on` - so startup order is guaranteed.

```yaml
api:
  depends_on:
    db:
      condition: service_healthy
```

---

## Volumes

| Use case | Volume type | Why |
|---|---|---|
| Source code in dev | Bind mount | Live reload without rebuild |
| Database data | Named volume | Persists across restarts, never lost on `down` |
| Build artifacts | No volume | Rebuilt on container start |

```yaml
# Named volume - always use for DB data
volumes:
  db_data:

services:
  db:
    volumes:
      - db_data:/var/lib/postgresql/data   <- named

  api:
    volumes:
      - ../apps/api:/app                   <- bind mount (dev only, in dev override file)
```

**Never use anonymous volumes for DB data** - they are destroyed on `docker compose down` and cannot be referenced by name.

---

## Environment Variables

- Services read env vars from the relevant `.env.*` file - never hardcode values in compose files.
- Use `env_file` in the compose service definition to load the correct file.
- The `.env.*` files are gitignored - only `.env.example` is committed.

```yaml
services:
  api:
    env_file:
      - ../../.env.development   # path relative to compose file location
```

---

## Production Rules

- No bind mounts in prod - source code must be baked into the image.
- All services must have `restart: unless-stopped`.
- No debug ports exposed (e.g. `9229` for Node inspector).
- Set memory and CPU limits on all services to prevent one container starving the host.

```yaml
deploy:
  resources:
    limits:
      memory: 512m
      cpus: "0.5"
```
