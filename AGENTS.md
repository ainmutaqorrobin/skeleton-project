# AGENTS.md

This file is generated from .ai/rules. Edit the source templates there, then run scripts/sync-agent-docs.ps1 or scripts/sync-agent-docs.sh.

## What This Repository Is

A **monorepo skeleton** for full-stack applications. It defines the architecture, tooling conventions, and coding standards for every app and package before any source code is written. Each subdirectory has its own `AGENTS.md` with rules specific to that layer.

---

## Monorepo Structure

```
apps/
  api/          <- NestJS backend (see apps/api/AGENTS.md)
  frontend/     <- React frontend - Next.js App Router or Expo Router (see apps/frontend/AGENTS.md)
  docker/       <- Docker Compose configs for all environments (see apps/docker/AGENTS.md)
  common/       <- Project-wide practices: TS, lint, git, CI/CD (see apps/common/AGENTS.md)
packages/
  swag/         <- Orval-generated TypeScript API client from swagger-spec.json
  schemas/      <- Shared Zod schemas + ErrorCode enum (used by both api and frontend)
  tsconfig/     <- Shared TypeScript base configs extended by all apps
```

Packages are built before apps. Dependency flow is strictly one-way: `apps/ -> packages/`. No package may import from `apps/`.

---

## Common Commands

```bash
# Development (run infrastructure in Docker, apps on host)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up db redis
pnpm dev                  # starts api and frontend on host

# Linting & Formatting (run from repo root - covers all apps and packages)
pnpm fmt                  # format all .ts/.tsx/.js/.jsx/.json files
pnpm lint                 # lint entire monorepo
pnpm lint:fix             # lint and auto-fix

# Type checking
pnpm tsc --noEmit         # type-check all workspaces

# Database
pnpm db:migrate           # run pending Kysely migrations
pnpm db:codegen           # regenerate db/types/ from live schema (requires DB running)
pnpm db:seed              # run idempotent seeders

# Code generation
pnpm codegen              # regenerate packages/swag/src/api.ts from swagger-spec.json

# Tests
pnpm test                 # run all unit/integration tests
pnpm test --filter=api    # run tests for a single workspace

# Docker (full stack per environment)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
docker compose -f docker-compose.yml -f docker-compose.test.yml up
docker compose -f docker-compose.yml -f docker-compose.staging.yml up
```

---

## Key Architectural Contracts

### API <-> Frontend contract via `packages/swag/`

1. Backend changes a controller or DTO -> `swagger-spec.json` is auto-written on app start.
2. Run `pnpm codegen` -> regenerates `packages/swag/src/api.ts`.
3. Commit `swagger-spec.json` and `packages/swag/src/api.ts` in the same PR as the backend change.
4. Frontend uses only the generated client - never hand-writes API types.

### Shared error contract via `packages/schemas/`

- `ErrorCode` enum lives in `packages/schemas/src/error-codes.ts`.
- Backend `GlobalExceptionFilter` maps all errors to this enum.
- Frontend switches on `errorCode`, never on `message`.
- Adding a new error code: update the enum first, then use it in both backend filter and frontend handler.

### TypeScript everywhere

- All apps extend `packages/tsconfig/base.json` which sets `strict: true`.
- No `any`, no `@ts-ignore` without explanation, explicit return types on public functions.

---

## Naming Conventions

- Application code and API payloads use `camelCase`.
- Database schema uses `snake_case`.
- Public HTTP route paths use lowercase `kebab-case`.
- See `apps/common/AGENTS.md` for the full naming matrix and boundary rules.

---

## Workflow Rules

- `main` is always deployable - PRs only, no direct pushes.
- Commit types: `feat`, `fix`, `chore`, `docs`, `infra`, `style`, `wip` (`wip` must never land on main).
- Pre-commit: Husky runs `pnpm fmt` + `pnpm lint` on staged files via lint-staged - never use `--no-verify` to bypass.
- PR merge to main -> automatic staging deploy. Tag release -> manual production deploy.

---

## Per-Layer Guidelines

Each layer has a dedicated `AGENTS.md` with detailed rules. Read the relevant file before touching that layer:

| Layer | File |
|---|---|
| NestJS API | `apps/api/AGENTS.md` |
| React Frontend (Next.js / Expo) | `apps/frontend/AGENTS.md` |
| Shared Packages | `apps/packages/AGENTS.md` |
| Docker / Compose | `apps/docker/AGENTS.md` |
| Cross-cutting practices | `apps/common/AGENTS.md` |
