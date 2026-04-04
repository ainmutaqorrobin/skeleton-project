# Skeleton Project

A **monorepo skeleton** for full-stack applications. This repository defines the architecture, tooling conventions, and coding standards for every layer before any source code is written — so every new project starts from a consistent, production-ready baseline.

> Last updated: 02 April 2026, 12:33 AM MYT

---

## Table of Contents

- [What This Is](#what-this-is)
- [Monorepo Structure](#monorepo-structure)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Common Commands](#common-commands)
- [Architecture Contracts](#architecture-contracts)
  - [API ↔ Frontend via Swagger](#api--frontend-via-swagger)
  - [Shared Error Contract](#shared-error-contract)
- [Per-Layer Guidelines](#per-layer-guidelines)
- [Workflow Rules](#workflow-rules)
- [CI/CD Pipeline](#cicd-pipeline)

---

## What This Is

This is not a runnable application — it is a **blueprint skeleton**. It captures:

- Folder structures for each layer
- Tooling decisions with documented tradeoffs
- Coding contracts that must be upheld across all apps
- Git, CI/CD, Docker, and testing conventions

When starting a new project, clone this repo and fill in the source code. Human developer workflow lives in [GUIDELINE.md](GUIDELINE.md). The generated `AGENTS.md` and `CLAUDE.md` files tell Codex and Claude Code what rules apply for each layer, while `.ai/rules/` remains the shared source of truth. Human review freshness is tracked in [.ai/RULES_STATUS.md](.ai/RULES_STATUS.md).

> Before changing this repository itself, read [GUIDELINE.md](GUIDELINE.md). It is the required contributor workflow for maintaining this skeleton repo.

---

## Monorepo Structure

```
skeleton-project/
├── apps/
│   ├── api/          ← NestJS backend
│   ├── frontend/     ← React frontend (Next.js App Router or Expo Router)
│   ├── docker/       ← Docker Compose configs for all environments
│   └── common/       ← Project-wide practices (TS, lint, git, CI/CD)
├── packages/
│   ├── swag/         ← Orval-generated TypeScript API client
│   ├── schemas/      ← Shared Zod schemas + ErrorCode enum
│   └── tsconfig/     ← Shared TypeScript base configs
├── .ai/
│   └── rules/        ← Shared source templates for AI instruction files
├── GUIDELINE.md      ← Human developer workflow and project rules
├── RULES_STATUS.md   ← Human-maintained last review timestamp for repo rules
├── AGENTS.md         ← Generated instructions for Codex
├── CLAUDE.md         ← Generated instructions for Claude Code
├── scripts/
│   ├── sync-agent-docs.ps1
│   └── sync-agent-docs.sh
└── TEMPLATE.md       ← Full narrative development reference
```

**Dependency flow is strictly one-way:** `apps/ → packages/`. No package may import from `apps/`.

Packages are always built before apps. This is enforced via Turborepo task dependencies in `turbo.json`.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | NestJS, Kysely, better-auth, Pino, PostgreSQL |
| Frontend | React (Next.js App Router or Expo Router) |
| Server state | TanStack React Query |
| UI state | Zustand |
| Forms | react-hook-form + Zod |
| API codegen | Orval (from swagger-spec.json) |
| Monorepo | Turborepo + pnpm workspaces |
| Containerization | Docker + Docker Compose |
| Linting / Formatting | Oxc (oxlint + oxc_formatter) |
| Pre-commit | Husky + lint-staged |
| Error monitoring | Sentry |
| Testing (backend) | Jest |
| Testing (frontend) | Vitest, Playwright (web), Detox (native) |

---

## Getting Started

**1. Install dependencies**

```bash
pnpm install
```

**2. Copy environment files**

```bash
# Run for each app
cp apps/api/.env.example apps/api/.env.development
cp apps/frontend/.env.example apps/frontend/.env.development
```

**3. Start infrastructure (DB + Redis) in Docker**

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up db redis
```

**4. Run apps on host**

```bash
pnpm dev
```

> Run apps directly on the host (not in Docker) during development for fast hot reload and easy debugging.

---

## Common Commands

```bash
# Development
pnpm dev                    # start api and frontend on host

# Linting & Formatting
pnpm fmt                    # format all .ts/.tsx/.js/.jsx/.json files
pnpm lint                   # lint entire monorepo
pnpm lint:fix               # lint and auto-fix

# Type checking
pnpm tsc --noEmit           # type-check all workspaces

# Database
pnpm db:migrate             # run pending Kysely migrations
pnpm db:codegen             # regenerate db/types/ from live schema (DB must be running)
pnpm db:seed                # run idempotent seeders

# API client codegen
pnpm codegen                # regenerate packages/swag/src/api.ts from swagger-spec.json

# Tests
pnpm test                   # run all tests
pnpm test --filter=api      # run tests for a single workspace

# Docker — full stack per environment
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
docker compose -f docker-compose.yml -f docker-compose.test.yml up
docker compose -f docker-compose.yml -f docker-compose.staging.yml up
```

---

## Architecture Contracts

These contracts must be upheld across all layers. Breaking them causes type errors, runtime mismatches, or silent bugs.

### API ↔ Frontend via Swagger

```
NestJS Controller + DTOs
        ↓  (app bootstrap writes this automatically)
swagger-spec.json
        ↓  (pnpm codegen)
packages/swag/src/api.ts
        ↓
apps/frontend/services/*/service.ts
```

**Rules:**
1. Backend changes a controller or DTO → start the app once → `swagger-spec.json` is auto-written.
2. Run `pnpm codegen` → regenerates `packages/swag/src/api.ts`.
3. Commit both `swagger-spec.json` **and** `packages/swag/src/api.ts` in the same PR as the backend change.
4. Frontend uses only the generated client — never hand-writes API types.
5. All DTO properties must have `@ApiProperty()` — undocumented fields are invisible to Orval.

### Shared Error Contract

The backend always returns this exact error shape:

```json
{
  "statusCode": 400,
  "errorCode": "VALIDATION_ERROR",
  "message": "One or more fields are invalid.",
  "details": [{ "field": "email", "message": "Invalid email format" }],
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/api/users",
  "requestId": "uuid"
}
```

- `errorCode` comes from the shared `ErrorCode` enum in `packages/schemas/src/error-codes.ts`.
- Frontend always switches on `errorCode` — never parses `message`.
- Adding a new error code: update the enum first, then use it in both the backend filter and frontend handler.

---

## Per-Layer Guidelines

Each layer has generated `AGENTS.md` and `CLAUDE.md` files with the same shared rules. Edit `.ai/rules/` and re-run the sync script instead of hand-editing the generated files.

| Layer | Guidelines |
|---|---|
| NestJS API | [apps/api/AGENTS.md](apps/api/AGENTS.md), [apps/api/CLAUDE.md](apps/api/CLAUDE.md) |
| React Frontend (Next.js / Expo) | [apps/frontend/AGENTS.md](apps/frontend/AGENTS.md), [apps/frontend/CLAUDE.md](apps/frontend/CLAUDE.md) |
| Shared Packages | [apps/packages/AGENTS.md](apps/packages/AGENTS.md), [apps/packages/CLAUDE.md](apps/packages/CLAUDE.md) |
| Docker / Compose | [apps/docker/AGENTS.md](apps/docker/AGENTS.md), [apps/docker/CLAUDE.md](apps/docker/CLAUDE.md) |
| Cross-cutting practices | [apps/common/AGENTS.md](apps/common/AGENTS.md), [apps/common/CLAUDE.md](apps/common/CLAUDE.md) |

For the full narrative development reference (tradeoffs, decision rationale, examples), see [TEMPLATE.md](TEMPLATE.md).

---

## Workflow Rules

- `main` is always deployable — PRs only, no direct pushes.
- Branch naming: `feature/*`, `fix/*`, `chore/*`, `infra/*`, `docs/*`.
- Commit types: `feat`, `fix`, `chore`, `docs`, `infra`, `style` — `wip` must never land on `main`.
- Pre-commit hook (Husky) runs `pnpm fmt` + `pnpm lint` on staged files — never bypass with `--no-verify`.
- Never edit a migration file after it has been merged to `main` — write a new one instead.
- Never drop a DB column in the same PR that removes it from code — two-step deployment.

---

## CI/CD Pipeline

**Every PR must pass before merge:**

1. Type-check (`tsc --noEmit`)
2. Lint (`oxlint`)
3. Format check
4. Unit / integration tests
5. Build

**Deployment:**

```
PR merge → main     → staging deploy (automatic)
Tag release         → production deploy (manual approval)
```

**PR Changelog:** Every PR receives an AI-generated comment (via GitHub Actions + Claude API) summarising changes grouped by commit type and author, files affected, migrations added, and any breaking API contract changes detected from `swagger-spec.json` diff. The comment is replaced (not appended) on each new push — one comment per PR, always current.
