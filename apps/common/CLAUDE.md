# Common Practices — Claude Guidelines

> Project-wide rules that apply across every app and package in this monorepo.
> When in doubt about a practice not covered in an app-specific CLAUDE.md, this file is the source of truth.

---

## TypeScript

- `strict: true` is enabled everywhere via `packages/tsconfig/base.json` — never disable it.
- No `@ts-ignore` without a comment explaining why it is necessary.
- No `any` — use `unknown` and narrow explicitly.
- Explicit return types on all public functions and service methods — do not rely on inference for shared API surfaces.

---

## Code Quality

### Formatting and Linting

- Use **Oxc** (`oxlint` + `oxc_formatter`) for all formatting and linting.
- Run via `pnpm lint` and `pnpm format`.
- Tradeoff: Oxc is not at full ESLint plugin parity. Some import-order and accessibility rules are unavailable. Acceptable — do not swap to ESLint to recover a missing rule without team discussion.

### Pre-commit Hooks (Husky)

- Husky runs formatter + lint check before every commit.
- A commit that fails lint or formatting is blocked — fix the issue, do not use `--no-verify` to bypass.
- If a hook is consistently failing on generated code, fix the generator config or add the path to the lint ignore list — do not disable the hook.

---

## Git

### Branching Strategy

```
main          ← always deployable, protected — no direct pushes
feature/*     ← new features
fix/*         ← bug fixes
chore/*       ← maintenance (deps, config, tooling)
infra/*       ← infrastructure and deployment changes
docs/*        ← documentation only
```

- PRs only — no direct pushes to `main` under any circumstance.
- Branch names must be descriptive: `feature/user-auth` not `feature/stuff`.
- Delete the branch after it is merged.

### Commit Style

| Type | When to use |
|---|---|
| `feat` | New feature or user-facing functionality |
| `fix` | Bug fix |
| `chore` | Maintenance — dependency updates, config, tooling |
| `docs` | Documentation only changes |
| `infra` | Infrastructure — Docker, CI/CD, deployment config |
| `style` | Formatting, whitespace — no logic change |
| `wip` | Work in progress — incomplete, not ready for review |

```
feat: add user profile screen
fix: correct null check on address field
chore: update orval to 7.x
docs: document migration conflict resolution
infra: add health check to docker-compose
style: reformat auth service
wip: notifications screen (incomplete)
```

**Rules:**
- `wip` commits must never land on `main` — squash or reword before merging.
- Subject line under 72 characters.
- Use the commit body for *why*, not *what* — the diff shows what changed.

---

## CI/CD

### PR Checks (must all pass before merge)

1. Type-check (`tsc --noEmit`)
2. Lint (`oxlint`)
3. Format check
4. Unit / integration tests
5. Build

### PR Changelog (AI-generated)

Every PR gets an AI-generated comment summarising what changed and who committed it. The comment is **replaced** (not appended) on each new push — one comment per PR, always current.

The changelog includes:
- Changes grouped by commit type and author
- Files / areas of the codebase affected
- Any migrations added
- Any breaking changes detected via `swagger-spec.json` diff

### Deployment Pipeline

```
PR merge to main → staging deploy (automatic)
Tag release      → production deploy (manual approval)
```

Never deploy directly to production from a feature branch.

---

## Environment Files

- Commit **`.env.example`** — one per app, documents every required key with placeholder values.
- Never commit `.env` or any file with real secrets.
- Use `scripts/gen-env.sh` to copy `.env.example` → `.env` for local setup.
- Separate env files per stage: `.env.development`, `.env.test`, `.env.staging`, `.env.production`.

> If a secret is accidentally committed, treat it as compromised and rotate it immediately — a revert does not remove it from git history.

---

## Monorepo (Turborepo)

- All tasks (build, lint, test, codegen) are defined in `turbo.json`.
- Task dependencies must be explicit — `packages/` build before `apps/`.
- Use Turborepo remote cache in CI to skip rebuilding unchanged packages.
- Run all tasks from the repo root via `pnpm` workspace scripts — do not `cd` into individual apps to run tasks in CI.

---

## Error Monitoring

- **Sentry** (or equivalent) is integrated in staging and production for both frontend and backend.
- Source maps are uploaded in the build pipeline — stack traces must point to real source lines, not minified output.
- The `GlobalExceptionFilter` in the API hooks into Sentry for backend error capture.
- The frontend Error Boundary hooks into Sentry for uncaught render errors.
- Never disable Sentry in staging — it is the primary signal for catching issues before they reach production.

---

## Security Baseline

- Never log passwords, tokens, or card numbers — redact before logging.
- Never expose stack traces, SQL queries, or internal file paths in API responses.
- All user input is validated server-side regardless of client-side validation.
- Rate limiting is enabled on all public endpoints — stricter on auth routes.
- HTTPS only in staging and production — no HTTP fallback.
- `CORS` is configured explicitly — do not use wildcard `*` in staging or production.
