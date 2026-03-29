> **Goal:** Keep the codebase consistent, easy to maintain, and safe against common runtime issues.

---

## Frontend

### 1) Folder Structure

```
components/
  ui/          ← pure presentational, no data fetching, fully reusable
  features/    ← domain-specific, may fetch data
services/      ← all API integration logic
hooks/         ← shared custom hooks
stores/        ← client state (Zustand)
lib/           ← utility functions, constants
```

- Keep components **small and readable**.
- Build **reusable components** unless a component is truly one-off.
- `ui/` components must not import from `features/` — dependency only flows downward.

### 2) State Management

Split state by concern — do not mix them:

| State type | Tool |
|---|---|
| Server state (fetch, cache, sync) | TanStack React Query |
| Global UI state (modals, sidebar, preferences) | Zustand |
| Local component state | `useState` / `useReducer` |

Avoid prop-drilling beyond 2 levels — lift to Zustand store instead.

### 3) API Integration

- Put all API integration logic under `services/`.
- Use **TanStack React Query** for fetching (queries) and mutating (mutations).
- Never call `fetch`/axios directly inside components.

**Codegen pipeline (backend → frontend types):**

```
NestJS Controller + DTOs
↓ (app bootstrap)
swagger-spec.json
↓ (orval codegen)
packages/swag/src/api.ts
↓
apps/mobile/services/*/service.ts
```

- Codegen must run after every backend contract change.
- Add codegen to `postinstall` or a watch script so it never falls behind.
- The generated client handles base URL and auth headers — configure these in the orval setup file, not in individual services.

### 4) Defensive Data Handling

Any component that fetches data must handle:

- Backend downtime
- `undefined` / empty responses
- Missing nested properties — `obj?.property?.nestedProperty` (optional chaining everywhere)
- Loading states — show skeleton screens or spinners while data is in-flight, never render nothing

**React Error Boundaries are required** at the route/page level. A single uncaught render error will crash the entire app without them. A `try/catch` in render is not a substitute.

```tsx
// Wrap each major screen/route
<ErrorBoundary fallback={<ErrorScreen />}>
  <FeatureScreen />
</ErrorBoundary>
```

### 5) Form Validation

- Validate **before** calling an API.
- Use **react-hook-form** + **Zod** via `@hookform/resolvers/zod`.
- Define the schema once with Zod — it serves as both the validation rule and the TypeScript type (`z.infer<typeof schema>`).
- Place shared schemas (used by both frontend and backend) in `packages/schemas/`.

```ts
// Single schema = validation + TypeScript type
const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
})
type LoginInput = z.infer<typeof loginSchema>
```

Use manual validation only if the form logic is genuinely too dynamic for a static schema.

---

## Backend

### 1) Development Setup

Run **only infrastructure** (DB, cache, queues) in Docker during development. Run the NestJS app directly for fast hot reload and easy debugging.

```
docker compose up db redis   ← infrastructure only
pnpm dev                     ← app runs on host
```

Never run the full stack in Docker locally during active development — the feedback loop is too slow.

### 2) Request Validation

Enable `ValidationPipe` globally on bootstrap. Without it, malformed requests reach your handlers unchecked.

```ts
app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }))
```

- Use `class-validator` + `class-transformer` on all DTOs.
- `whitelist: true` strips unknown properties automatically.
- `forbidNonWhitelisted: true` rejects requests with unexpected fields.

### 3) Standardized Error Responses

Every error from the API — regardless of source — must return the same shape. The frontend must never parse English strings to determine what went wrong.

**Error response contract:**

```json
{
  "statusCode": 400,
  "errorCode": "VALIDATION_ERROR",
  "message": "One or more fields are invalid.",
  "details": [
    { "field": "email", "message": "Invalid email format" },
    { "field": "password", "message": "Must be at least 8 characters" }
  ],
  "timestamp": "2024-01-01T00:00:00.000Z",
  "path": "/api/users",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

- `errorCode` — machine-readable string the frontend switches on. Never parse `message` in frontend logic.
- `details` — optional array, only present for validation errors or multi-field issues.
- `requestId` — attach via middleware on every request (e.g. `uuid`). Makes tracing a specific error in logs trivial.
- `message` — human-readable summary safe to show in UI. Never leak internal details (SQL errors, file paths, stack traces).

**Define a standard error code enum** shared between frontend and backend via `packages/`:

```ts
export enum ErrorCode {
  VALIDATION_ERROR     = 'VALIDATION_ERROR',
  NOT_FOUND            = 'NOT_FOUND',
  UNAUTHORIZED         = 'UNAUTHORIZED',
  FORBIDDEN            = 'FORBIDDEN',
  CONFLICT             = 'CONFLICT',       // e.g. duplicate email
  RATE_LIMITED         = 'RATE_LIMITED',
  INTERNAL_ERROR       = 'INTERNAL_ERROR',
  // add domain-specific codes as needed
}
```

**`GlobalExceptionFilter` must handle every error source uniformly:**

| Error source | How it arrives | Map to |
|---|---|---|
| `HttpException` (NestJS built-in) | thrown manually in code | use its `statusCode` + map to `ErrorCode` |
| `ValidationPipe` errors | `BadRequestException` with structured `message` array | `VALIDATION_ERROR` + populate `details` |
| DB unique constraint violation (Postgres `23505`) | raw DB error | `409 CONFLICT` |
| DB foreign key violation (Postgres `23503`) | raw DB error | `400 BAD_REQUEST` |
| `better-auth` auth errors | library-specific error shape | `401 UNAUTHORIZED` or `403 FORBIDDEN` |
| Any unrecognized / unhandled error | anything else | always `500 INTERNAL_ERROR`, log full stack, return no internals |

**Rules:**
- Log every error with: `requestId`, `userId` (if authenticated), `method`, `path`, `errorCode`, `statusCode`, and full stack trace (server-side only).
- Never log sensitive fields (passwords, tokens) — redact them.
- Never expose stack traces, SQL queries, or internal file paths to the client.
- In production, even the `message` for `INTERNAL_ERROR` should be generic: `"An unexpected error occurred."` — the real detail is in the server log.

### 4) Environment Variable Validation

Validate all env vars at startup using `@nestjs/config` + Joi or Zod. **Fail fast** — a missing `DATABASE_URL` should crash at boot, not at the first DB query.

```ts
ConfigModule.forRoot({
  validationSchema: Joi.object({
    DATABASE_URL: Joi.string().required(),
    PORT: Joi.number().default(3000),
    // ...
  }),
})
```

### 5) Database

Use **Kysely** for type-safe query building. Use **Kysely codegen** to generate TypeScript types from the live DB schema — the DB is the source of truth, not manually written types. Codegen requires a live DB connection; account for this in CI setup.

**Choosing a database — tradeoffs:**

| Database | Best for | Pros | Cons |
|---|---|---|---|
| **PostgreSQL** | Default choice for almost everything | Rich feature set (JSONB, arrays, full-text search), excellent Kysely support, best community | Slightly heavier than MySQL for simple workloads |
| **MySQL / MariaDB** | Budget shared hosting, existing MySQL infra | Widely supported by cheap hosting providers, familiar to many devs | Fewer advanced features than Postgres, subtle type differences |
| **SQLite** | Small single-user apps, local-first tools | Zero server setup, single file, great for prototypes | Not suitable for multi-user concurrent writes, no network access |
| **MongoDB** | Truly document-oriented data (irregular schema) | Flexible schema, easy horizontal scale | Loses relational guarantees, no joins, easy to create inconsistent data if not careful |

**Recommendation:** default to PostgreSQL. Only deviate when there's a concrete reason (client's existing infra, hosting constraint, truly document-oriented data).

### 6) Migrations

- Use Kysely's built-in migration runner.
- Name migration files: `YYYYMMDDHHMMSS_short_description.ts` — timestamp prefix ensures correct execution order and avoids filename collisions across branches.
- Every migration must have both `up` and `down` functions.
- **Never drop a column in the same deployment that removes it from code.** Deploy the code change first (column becomes unused), then drop the column in a follow-up migration. This keeps zero-downtime deployments safe.
- Migrations run automatically on app startup in staging/prod, or via explicit script — choose one and document it.

#### Migration Conflict Problem (Multi-developer)

**The problem:** Developer A and Developer B both create migration files on separate branches. When both branches are merged, there are two new migration files. Depending on their timestamps and what each migration does, running them in the wrong order can corrupt data or fail entirely.

**Scenario that breaks things:**
```
main:      ...20240101_add_users
branch-A:  ...20240102_add_user_roles     ← depends on users table
branch-B:  ...20240101_add_products       ← earlier timestamp, merged after branch-A
```
If `branch-B` is merged after `branch-A`, and staging already ran `20240102_add_user_roles`, Kysely will now see `20240101_add_products` as a new unrun migration with an *earlier* timestamp than one already executed. Kysely only runs migrations it hasn't seen before — it does not re-order already-run ones. This is safe **only if** the two migrations are independent. If they touch related tables, data integrity is at risk.

**How to prevent this:**

1. **Always rebase from `main` before writing a migration.** This is the most important rule. See what migrations already exist, then create yours *after* them.

2. **One migration per PR rule.** If two PRs both add migrations, merge them sequentially — never let two migration-bearing PRs sit open simultaneously targeting the same base.

3. **Communicate in standups.** "I'm adding a migration today" should be said out loud. Treat it like a shared resource lock.

4. **Never modify an already-merged migration file.** Once a migration has run on any environment (even dev on another machine), it is immutable. Create a new migration to fix mistakes.

5. **Squash migrations on long-running branches.** If a feature branch has 3 migration files accumulated over 2 weeks, squash them into one before merging — reduces the conflict surface area.

**Conflict resolution when it already happened:**

If two migrations land out of intended order and a bad state is reached:
1. Write a new corrective migration — never edit existing ones.
2. The `down` function exists for this: roll back to a known good state on the affected environment, fix the order issue (rename the file timestamp if not yet run anywhere), then re-run.
3. If already run on production: a corrective `up` migration is the only safe path — no rollback on prod without extreme caution.

**Alternative approach — Atlas (schema-as-code):**

If migration conflicts become a recurring pain, consider replacing file-based migrations with **Atlas**. Atlas takes a declarative schema definition and computes the diff between current DB state and desired state, generating the migration automatically. Two devs editing the schema file is a standard code conflict (resolved in the file, not by reordering migration files). Tradeoff: steeper learning curve, different mental model.

### 7) API Documentation

Use **`@nestjs/swagger`** + **Scalar** for documentation. Bootstrap wires everything together in one place:

```ts
// main.ts
const document = SwaggerModule.createDocument(app, config);

// 1. Write spec to disk — keeps swagger-spec.json in sync on every app start
writeFileSync("./swagger-spec.json", JSON.stringify(document));

// 2. Swagger UI (machine-readable, used by Orval codegen)
SwaggerModule.setup("api", app, document);

// 3. Scalar UI (human-readable, for devs and clients)
app.use("/swag", apiReference({
  metaData: { title: "Your App | API Documentation" },
  spec: { content: document },
}));
```

**Why `writeFileSync` and not a separate script:**
- The document is built from live decorators — running the app *is* the codegen step.
- `writeFileSync` runs once synchronously at boot, before the server accepts requests. It is not a request handler and does not block traffic.
- This means `swagger-spec.json` is always current as long as the app has been started at least once after a backend change.

**Keeping the pipeline in sync — rules:**

1. **Commit `swagger-spec.json` to the repo.** This lets frontend devs run Orval codegen without needing the backend running locally. Without it, the frontend has no spec to generate from.

2. **`swagger-spec.json` must be regenerated and committed before merging to `main`.** A stale spec = stale frontend types = type errors or silent runtime mismatches. Make this a PR checklist item.

3. **In CI:** boot the backend briefly as part of the build step to regenerate the spec, then run Orval. Alternatively, assert in CI that the committed `swagger-spec.json` matches what the app would generate (diff check).

4. **Decorate all DTOs and controller responses.** Any field without `@ApiProperty()` is invisible to Orval — it will not appear in the generated types.

**Two UIs, two audiences:**

| Endpoint | Tool | Audience |
|---|---|---|
| `/api` | Swagger UI | Orval codegen, automated tooling |
| `/swag` | Scalar | Developers, QA, clients reviewing the API |

Scalar renders a significantly more readable UI than Swagger UI — use `/swag` as the link you share with others.

### 8) Authentication

- Use **`better-auth`** for authentication.
- Tradeoff: newer library (2024), smaller community than Passport.js. Fewer Stack Overflow answers, higher chance of breaking changes. Acceptable for a skeleton — just pin the version.

### 9) Logging

Use structured logging (JSON output) via **Pino** or **Winston**. Plain `console.log` is not searchable in production log systems.

Every log entry should include: `timestamp`, `level`, `requestId`, `userId` (if authenticated), `message`.

### 10) Rate Limiting

Add **`@nestjs/throttler`** globally. Public-facing freelance apps will be scraped and brute-forced. Configure stricter limits on auth endpoints.

### 11) Seeder

- Maintain a seeder to generate sample data for testing and debugging.
- Seeders must be **idempotent** — safe to run twice without duplicating data (use upsert, not insert).
- Seeder should cover realistic edge cases, not just happy-path data.

---

## Packages

- `packages/swag/` — generated TypeScript types from Swagger, consumed by the frontend via Orval.
- `packages/schemas/` — shared Zod schemas used by both frontend and backend.
- Packages export types and schemas only — **never business logic**.
- Codegen is triggered by script, not manually. Add it to the monorepo task pipeline.

---

## Monorepo

Use **Turborepo** for build/task orchestration.

- Define task dependencies in `turbo.json` so builds run in correct order (packages before apps).
- Enable Turborepo's remote cache for CI speed — avoids rebuilding unchanged packages.
- Each app/package has its own `tsconfig.json` extending a shared base config in `packages/tsconfig/`.

---

## Docker

### Service Split

| Service | Container |
|---|---|
| Backend (NestJS) | `api` |
| Frontend | `web` / `mobile` build |
| Database (Postgres) | `db` |
| Cache (Redis, if used) | `redis` |

### Compose Files

Use **Docker Compose merge files** — never put env-specific logic in the base file:

```
docker-compose.yml          ← base (shared structure only)
docker-compose.dev.yml      ← dev overrides (bind mounts, debug ports)
docker-compose.test.yml     ← test overrides (isolated DB, no persistent volume)
docker-compose.staging.yml  ← staging overrides
docker-compose.prod.yml     ← prod overrides (restart policies, resource limits)
```

### Health Checks

Define health checks on every service. Without them, Docker reports `running` before the app is ready, causing flaky startup ordering.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 10s
  timeout: 5s
  retries: 5
```

### Volumes

- **Bind mounts** for source code in dev (live reload).
- **Named volumes** for database data in all envs — never use bind mounts for DB data, and never use anonymous volumes (lost on `docker compose down`).

```yaml
volumes:
  db_data:    ← named, persists across restarts
```

---

## Environment Files

- Commit **`.env.example`** to the repo — documents every required key with placeholder values.
- Never commit `.env` or any file containing real secrets. Add to `.gitignore` immediately.
- Write a script (`scripts/gen-env.sh`) that copies `.env.example` → `.env` and prompts for missing required values.
- Keep separate env files per environment: `.env.development`, `.env.test`, `.env.staging`, `.env.production`.

> If a secret ever gets committed accidentally, treat the key as compromised and rotate it — git history cannot be trusted even after a revert.

---

## Testing

### Unit / Integration Tests

- Use **Vitest** (frontend) or **Jest** (backend / NestJS).
- Test business logic and service layer — not implementation details.
- For backend: integration tests should hit a real test database, not mocks. Mocked DB tests have caused prod migrations to fail while tests passed.
- Seeders and test fixtures must use the same migration runner as production.

### End-to-End Tests

- Use **Playwright** (web) or **Detox** (React Native / Expo).
- Cover critical user flows only: auth, core feature, payment (if applicable).
- E2E tests run in CI against a staging-like environment, not dev.

---

## CI/CD

Every pull request must pass before merge:

1. Type-check (`tsc --noEmit`)
2. Lint (`oxlint`)
3. Format check
4. Unit/integration tests
5. Build

Deployment pipeline per environment:

```
PR merge to main → staging deploy (automatic)
Tag release      → production deploy (manual approval)
```

### PR Changelog (AI-generated)

On every pull request, a CI job runs an AI-generated changelog comment summarising what changed and who committed it.

**What the changelog must include:**
- Summary of changes per commit author (who did what)
- Grouped by commit type (`feat`, `fix`, `infra`, etc.)
- Files or areas of the codebase affected
- Any migrations added
- Any breaking changes detected (API contract diff against `swagger-spec.json`)

**Implementation approach (GitHub Actions):**

```yaml
# .github/workflows/pr-changelog.yml
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Collect git log with authors since branch diverged from main
          git log origin/main..HEAD --pretty=format:"%h %an <%ae> %s" > commits.txt
          git diff origin/main..HEAD --stat >> commits.txt
          # Pass to Claude API and post result as PR comment

      - name: Post comment
        uses: actions/github-script@v7
        # post the generated changelog as a PR comment
```

**Rules:**
- The changelog comment is **replaced** (not appended) on each new push to the PR — one comment per PR, always up to date.
- The AI summary is informational only — it does not block the PR from merging.
- Commit authors' names and emails come from git log — no manual tagging needed.
- Keep the prompt instructed to be concise: bullet points, no filler prose.

---

## TypeScript

- Enable **`"strict": true`** in all `tsconfig.json` files — non-negotiable. Catches null/undefined bugs, implicit any, and unsafe type assertions at compile time.
- No `@ts-ignore` without a comment explaining why.
- No `any` without justification — use `unknown` and narrow the type explicitly.

---

## Code Quality

- **Husky** — runs formatter + lint check as pre-commit hook. Blocks commits that don't pass.
- **Oxc** (`oxlint` + `oxc_formatter`) for formatting and linting — Rust-based, fast.
  - Tradeoff: not at full ESLint plugin parity yet (some import-order and a11y rules unavailable). Acceptable for most freelance projects.
- Keep generated code **readable** — avoid overly clever logic, deep nesting, and nested spread operators.

---

## Error Monitoring

Integrate **Sentry** (or equivalent) in staging and production.

- Frontend: catches uncaught JS errors and unhandled promise rejections.
- Backend: catches unhandled exceptions (hook into the GlobalExceptionFilter).
- Set up **source maps** upload in the build pipeline so stack traces point to real source lines, not minified output.

Without this, you will not know when your deployed app crashes.

---

## Git

### Branching Strategy

```
main          ← always deployable, protected
feature/*     ← new features, branched from main
fix/*         ← bug fixes
chore/*       ← non-functional changes (deps, config)
```

- No direct pushes to `main` — PRs only.
- Branch names must be descriptive: `feature/user-auth`, not `feature/stuff`.
- Delete branches after merge.

### Commit Style

Use [Conventional Commits](https://www.conventionalcommits.org/):

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
wip: user notifications (incomplete)
```

- `wip` commits should never land on `main` — squash or reword before merging.
- Keep the subject line under 72 characters.
- Use the body for *why*, not *what* — the diff shows what changed.
