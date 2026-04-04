# Developer Guideline

> Last updated: 05 April 2026, 01:31 AM MYT

## Purpose

This file is for human contributors. It collects the developer-facing rules for working in this monorepo skeleton without mixing them with the Claude/Codex instruction setup.

## What To Edit

Edit implementation here:

- `apps/`
- `packages/`

Edit developer documentation here when project process changes:

- `README.md`
- `GUIDELINE.md`
- `TEMPLATE.md`

Edit AI instruction rules only when agent guidance changes:

- `.ai/rules/`

Do not hand-edit generated AI files:

- `AGENTS.md`
- `CLAUDE.md`
- `apps/*/AGENTS.md`
- `apps/*/CLAUDE.md`

## Core Monorepo Rules

- Dependency flow is one-way: `apps/ -> packages/`
- Packages build before apps
- `main` must stay deployable
- PRs only, no direct pushes to `main`
- Use conventional commit types: `feat`, `fix`, `chore`, `docs`, `infra`, `style`
- `wip` commits must not land on `main`

## Common Commands

```bash
pnpm dev
pnpm fmt
pnpm lint
pnpm lint:fix
pnpm tsc --noEmit
pnpm test
pnpm db:migrate
pnpm db:codegen
pnpm db:seed
pnpm codegen
```

## Architecture Contracts

### API and frontend contract

- Backend DTO/controller changes must update `swagger-spec.json`
- After contract changes, run `pnpm codegen`
- Commit `swagger-spec.json` and `packages/swag/src/api.ts` in the same PR
- Frontend should use the generated client, not handwritten API types

### Shared error contract

- Use `ErrorCode` from `packages/schemas/src/error-codes.ts`
- Frontend logic must switch on `errorCode`, not message text
- Add new error codes in the shared package first

### TypeScript

- Keep `strict: true`
- No `any` unless there is a strong reason and explicit narrowing plan
- No `@ts-ignore` without explanation

## Developer Workflow

If you change implementation only:

- Update app or package code
- Run the relevant checks
- Do not touch `.ai/rules/` unless the actual project guidance changed

If you change project conventions or architectural guidance:

- Update `GUIDELINE.md`, `README.md`, or `TEMPLATE.md` as needed
- If the AI assistants should follow that new guidance too, also update the matching `.ai/rules/*.md` file
- Re-run `scripts/sync-agent-docs.ps1` or `scripts/sync-agent-docs.sh` after changing `.ai/rules/`

## AI Docs Relationship

- `.ai/rules/` is the source of truth for AI-specific working instructions
- `AGENTS.md` and `CLAUDE.md` are generated from `.ai/rules/`
- Human review freshness for the AI rules is tracked in `.ai/RULES_STATUS.md`
