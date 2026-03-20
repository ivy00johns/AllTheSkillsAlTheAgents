# 11 — Testing Infrastructure

Mission Control has a mature, two-layer testing strategy: Vitest unit tests for isolated logic validation, and Playwright E2E tests for full API integration testing against a real server build. A GitHub Actions quality gate enforces that all layers pass before merge.

---

## Unit Testing: Vitest

### Framework Configuration

**File:** `vitest.config.ts`

```typescript
export default defineConfig(async () => {
  const { default: tsconfigPaths } = await import('vite-tsconfig-paths')
  return {
    plugins: [react(), tsconfigPaths()],
    test: {
      environment: 'jsdom',
      globals: true,
      setupFiles: ['src/test/setup.ts'],
      include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
      coverage: {
        provider: 'v8' as const,
        include: ['src/lib/**/*.ts'],
        exclude: ['src/lib/__tests__/**', 'src/**/*.test.ts'],
        thresholds: {
          lines: 60,
          functions: 60,
          branches: 60,
          statements: 60,
        },
      },
    },
  }
})
```

Key decisions:
- **Vitest v2.1.5** with jsdom environment for React component testing capability
- **v8 coverage provider** (fast native instrumentation, not Istanbul)
- **60% threshold** across all four metrics (lines, functions, branches, statements) -- a pragmatic floor, not aspirational
- **Coverage scope**: only `src/lib/**/*.ts` -- UI components are tested via E2E, not unit tests
- **Setup file**: `src/test/setup.ts` imports `@testing-library/jest-dom` for matcher extensions
- **Dynamic import** for `vite-tsconfig-paths` to avoid ESM/CJS bundler conflicts

### Test Scripts

From `package.json`:

| Script | Command | Purpose |
|--------|---------|---------|
| `test` | `vitest run` | Single run, CI-friendly |
| `test:watch` | `vitest` | Watch mode for development |
| `test:ui` | `vitest --ui` | Visual test runner UI |
| `test:all` | `pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e` | Full quality gate |
| `quality:gate` | `pnpm test:all` | Alias for CI |

### Unit Test Files: Complete Inventory

All 12 unit test files live in `src/lib/__tests__/`. Here is what each tests:

#### 1. `auth.test.ts` — Authentication & Authorization

Tests the two core auth primitives:

- **`safeCompare()`**: Timing-safe string comparison
  - Matching strings, mismatched strings, different lengths, empty strings, null/undefined inputs
  - Validates the constant-time comparison to prevent timing attacks

- **`requireRole()`**: Role-based access guard
  - 401 when no auth provided
  - 401 when API key is wrong
  - Returns user with admin role for valid API key
  - Role hierarchy: admin >= operator >= viewer
  - Bearer token format accepted
  - Rejects API key auth when `API_KEY` env not configured

Mocking pattern: Mocks `@/lib/db`, `@/lib/password`, and `@/lib/event-bus` to isolate auth logic from database and side effects.

#### 2. `cron-occurrences.test.ts` — Cron Schedule Expansion

Tests cron expression evaluation:
- `buildDayKey()`: Date formatting to `YYYY-MM-DD`
- `getCronOccurrences()`: Expands cron expressions over date ranges
  - Daily schedules, step values (`*/30`), OpenClaw timezone suffix handling
  - Returns empty array for invalid cron expressions

#### 3. `db-helpers.test.ts` — Database Helper Functions

Tests four core database operations with full mock isolation:

- **`parseMentions()`**: `@mention` extraction from text
  - Multiple mentions, single mention, no mentions, double-`@`, start/end positions
  - Hyphen/underscore/dot support in handles
  - Case-insensitive deduplication

- **`logActivity()`**: Activity audit trail insertion
  - Inserts into database AND broadcasts `activity.created` event
  - Stringifies data objects when provided

- **`createNotification()`**: Notification creation
  - Insert + `notification.created` broadcast
  - Optional source_type/source_id linking

- **`updateAgentStatus()`**: Agent status changes
  - Database update + `agent.status_changed` broadcast

Mocking pattern: Uses `vi.hoisted()` for mock variables shared between `vi.mock()` factories -- solves the hoisting limitation where mock variables must be declared before use.

#### 4. `db-seed-auth-pass.test.ts` — Password Seeding Logic

Tests `resolveSeedAuthPassword()`:
- Returns `AUTH_PASS` when `AUTH_PASS_B64` is not set
- Prefers `AUTH_PASS_B64` (base64-decoded) when present and valid
- Falls back to `AUTH_PASS` when `AUTH_PASS_B64` is invalid base64
- Returns null when no password env var is set

This handles the Docker deployment edge case where `AUTH_PASS` with special characters (e.g., `#`) can break shell sourcing.

#### 5. `gateway-url.test.ts` — WebSocket URL Construction

Tests `buildGatewayWebSocketUrl()`:
- Local dev: `ws://127.0.0.1:18789`
- Remote hosts on HTTPS: `wss://host` (port 18789 omitted)
- Explicit `https://` prefix normalized to `wss://`
- Preserves explicit URL ports
- Strips path/query/hash from pasted dashboard URLs

#### 6. `json-relaxed.test.ts` — Relaxed JSON Parser

Tests `parseJsonRelaxed()`:
- Strict JSON passthrough
- Line comments (`//`) and block comments (`/* */`) stripping
- Trailing comma tolerance
- URL fragments inside strings preserved (not treated as comments)
- Throws on genuinely invalid JSON

This parser handles `openclaw.json` files that users edit by hand with comments.

#### 7. `rate-limit.test.ts` — Factory Rate Limiter

Tests `createRateLimiter()`:
- First request within limit returns null (allowed)
- Allows requests up to max limit
- Returns 429 response when limit exceeded
- Custom error message support
- Window expiration resets the counter (uses `vi.useFakeTimers()`)
- Per-IP independent tracking

#### 8. `task-costs.test.ts` — Token Cost Analytics

Tests `calculateStats()` and `buildTaskCostReport()`:
- Correct token/cost/request aggregation
- Task-level, agent-level, project-level, and unattributed rollups
- Ticket reference formatting (e.g., `CORE-012`)
- Multi-agent/multi-task cost attribution

#### 9. `task-status.test.ts` — Status Normalization

Tests automatic status transitions:
- `normalizeTaskCreateStatus()`: Auto-assigns `assigned` status when assignee present
- `normalizeTaskUpdateStatus()`: Auto-promotes inbox->assigned when agent assigned, auto-demotes assigned->inbox when assignment removed
- Does not override explicit status changes

#### 10. `token-pricing.test.ts` — LLM Token Pricing

Tests `calculateTokenCost()` and `getModelPricing()`:
- Separate input/output rates for specific models (Claude Sonnet 4.5)
- Model alias matching by short name (e.g., `gateway::claude-opus-4-6`)
- Conservative fallback pricing for unknown models
- Zero cost for local models (Ollama)
- Zero cost for subscribed providers (flat-rate API access)
- Provider detection from model prefixes

#### 11. `validation.test.ts` — Zod Schema Validation

Comprehensive tests for all 10 API schemas:

| Schema | Tests |
|--------|-------|
| `createTaskSchema` | Title required, defaults (inbox/medium), all valid statuses, outcome/feedback fields, feedback_rating bounds |
| `createAgentSchema` | Name required |
| `createWebhookSchema` | Name + valid URL required, invalid URL rejected |
| `createAlertSchema` | All required fields, missing fields rejected |
| `spawnAgentSchema` | Task/model/label required, timeout range 10-3600s (default 300) |
| `createUserSchema` | Username + password required, default role operator |
| `qualityReviewSchema` | taskId + status (approved/rejected) + notes required |
| `createPipelineSchema` | Name + 2+ steps required |
| `createWorkflowSchema` | Name + task_prompt required, default model sonnet |
| `createMessageSchema` | to + message required |

#### 12. `webhooks.test.ts` — Webhook Security & Retry

Tests three areas:

- **`verifyWebhookSignature()`**: HMAC-SHA256 constant-time verification
  - Correct signature, wrong secret, tampered body, missing signature, empty secret

- **`nextRetryDelay()`**: Exponential backoff with jitter
  - Expected base delays: 30s, 300s, 1800s, 7200s, 28800s
  - +/-20% jitter range validation (run 20 times per attempt)
  - Clamps beyond array length, returns integer

- **Circuit breaker logic**: `consecutive_failures >= maxRetries` opens circuit

---

## E2E Testing: Playwright

### Framework Configuration

**File:** `playwright.config.ts`

```typescript
export default defineConfig({
  testDir: 'tests',
  testIgnore: /openclaw-harness\.spec\.ts/,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://127.0.0.1:3005',
    trace: 'retain-on-failure'
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } }
  ],
  webServer: {
    command: 'node .next/standalone/server.js',
    url: 'http://127.0.0.1:3005',
    reuseExistingServer: true,
    timeout: 120_000,
    env: { /* ... rate limiting disabled, test credentials */ }
  }
})
```

Critical design decisions:
- **Sequential execution**: `fullyParallel: false`, `workers: 1` -- tests share a SQLite database and must not race
- **Standalone build**: Tests run against `node .next/standalone/server.js` on port 3005, not a dev server
- **Rate limiting disabled**: `MC_DISABLE_RATE_LIMIT=1` for non-critical limiters
- **Workload thresholds elevated**: Queue depth and error rate thresholds set extremely high to prevent test interference
- **Trace on failure**: `retain-on-failure` captures Playwright trace files for debugging
- **Chromium only**: Single browser project, no Firefox/WebKit

### Playwright Config Variants

Three configurations serve different testing scenarios:

| Config | File | Included Tests | Use Case |
|--------|------|----------------|----------|
| Main | `playwright.config.ts` | All except `openclaw-harness` | Standard CI/CD |
| OpenClaw Local | `playwright.openclaw.local.config.ts` | Only `openclaw-harness` | Tests without gateway connection |
| OpenClaw Gateway | `playwright.openclaw.gateway.config.ts` | Only `openclaw-harness` | Tests with gateway connection |

The OpenClaw variants use custom server start scripts (`scripts/e2e-openclaw/start-e2e-server.mjs`) with `--mode=local` or `--mode=gateway`, and set `reuseExistingServer: false` (vs `true` for main config).

### Test Helpers

**File:** `tests/helpers.ts`

Shared test infrastructure providing:

```typescript
export const API_KEY_HEADER = { 'x-api-key': 'test-api-key-e2e-12345' }

// Entity lifecycle helpers:
createTestTask(request, overrides?) → { id, title, res, body }
deleteTestTask(request, id)
createTestAgent(request, overrides?) → { id, name, res, body }
deleteTestAgent(request, id)
createTestWorkflow(request, overrides?) → { id, name, res, body }
deleteTestWorkflow(request, id)
createTestWebhook(request, overrides?) → { id, name, res, body }
deleteTestWebhook(request, id)
createTestAlert(request, overrides?) → { id, name, res, body }
deleteTestAlert(request, id)
createTestUser(request, overrides?) → { id, username, res, body }
deleteTestUser(request, id)
```

Each helper uses a `uid()` function (`Date.now() + random chars`) for unique entity names, preventing test collisions.

### Test Cleanup Pattern

Every test file follows the same cleanup pattern:

```typescript
const cleanup: number[] = []

test.afterEach(async ({ request }) => {
  for (const id of cleanup) {
    await deleteTestEntity(request, id).catch(() => {})
  }
  cleanup.length = 0
})
```

Create-in-test -> push ID to cleanup array -> afterEach deletes all. The `.catch(() => {})` swallows errors for already-deleted entities.

### E2E Test Files: Complete Inventory

All 35+ test files in `tests/` with their coverage areas:

#### Authentication & Security (8 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `login-flow.spec.ts` | Login page load, redirect to login, session cookie, wrong password, session-based API access | Creates test user in `beforeAll`, validates `mc-session` cookie |
| `auth-guards.spec.ts` | 17 protected GET endpoints return 401 without auth | Loops through `/api/agents`, `/api/tasks`, `/api/activities`, `/api/notifications`, `/api/status`, `/api/logs`, `/api/chat/*`, `/api/standup`, `/api/spawn`, `/api/pipelines/*`, `/api/webhooks/*`, `/api/workflows`, `/api/settings`, `/api/tokens`, `/api/search`, `/api/audit` |
| `timing-safe-auth.spec.ts` | Valid API key works, wrong key rejected, empty key rejected, no header rejected | Validates `safeCompare` in production |
| `csrf-validation.spec.ts` | Mismatched Origin blocked with 403, matching Origin allowed, no Origin (CLI) allowed, GET exempt | CSRF protection for browser-based attacks |
| `legacy-cookie-removed.spec.ts` | Old `mission-control-auth` cookie no longer authenticates API or page requests | Security regression test |
| `rate-limiting.spec.ts` | 7 rapid failed logins -> at least one 429, fresh IP not rate-limited | Rate limiter integration test |
| `actor-identity-hardening.spec.ts` | Chat message ignores client `from` field, task broadcast ignores client `author` field | Anti-spoofing: server uses authenticated principal |
| `device-identity.spec.ts` | Ed25519 key pair generation, nonce signing, localStorage persistence across reload, key reimport round-trip, token cache, clearDeviceIdentity | Full browser crypto tests in Chromium |

#### CRUD Operations (7 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `agents-crud.spec.ts` | POST create, duplicate rejected, GET list with pagination/taskStats, GET by id/name, PUT by id/name, DELETE, full lifecycle | 14 tests covering the complete agent API |
| `tasks-crud.spec.ts` | POST minimal/full/actor-spoofing/empty-title/duplicate, GET list with filters (status/priority/limit), GET single/404/400, PUT update/404/empty-body, Aegis gate (403 for done without approval), DELETE, full lifecycle | 16 tests, most comprehensive CRUD suite |
| `alerts-crud.spec.ts` | POST create/validation, GET list, PUT update/404, DELETE, full lifecycle | Alert rule management |
| `webhooks-crud.spec.ts` | POST create/invalid-URL/missing-name, GET with masked secrets, PUT update/regenerate-secret/404, DELETE, full lifecycle | Secret masking verified in list response |
| `workflows-crud.spec.ts` | POST create/missing-name/missing-prompt, GET list, PUT update/404, DELETE, full lifecycle | Workflow template management |
| `user-management.spec.ts` | POST create/duplicate/missing-fields, GET list, PUT update/404, DELETE/404 | User lifecycle with role management |
| `task-comments.spec.ts` | POST add/empty-content/404/threaded-reply/author-spoofing, GET list/empty/404 | Comment threading and anti-spoofing |

#### Agent Features (5 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `agent-api-keys.spec.ts` | Scoped agent key creation (mca_ prefix), self-access allowed, cross-agent access denied (403), key listing, key revocation, expired key rejection | Complete per-agent API key lifecycle |
| `agent-attribution.spec.ts` | Self-scope via x-agent-name, cross-agent denied, privileged override for admin, section/hours parameter validation | Agent identity and access scope |
| `agent-diagnostics.spec.ts` | Self access, cross-agent denied, privileged override, invalid section/hours rejected | Agent-scoped diagnostic endpoints |
| `agent-costs.spec.ts` | Stats endpoint shape, per-agent cost breakdown, timeframe filtering, token recording, task-level cost attribution with unattributed rollup | Token cost analytics |
| `workload-signals.spec.ts` | Normal/throttle/shed/pause recommendations based on agent busy ratio, queue depth structure | Workload-based admission control |

#### Task Features (4 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `task-queue.spec.ts` | Priority-based task picking (critical first), continue_current for in-progress, max_capacity validation, x-agent-name header support | Smart task queue for agent work distribution |
| `task-outcomes.spec.ts` | Done status auto-populates completed_at, outcomes summary with by_agent/by_priority/common_errors | Task completion analytics |
| `task-regression.spec.ts` | Baseline vs post p95 latency comparison, intervention rate trend | A/B regression metrics |
| `quality-review.spec.ts` | POST review/404/validation, GET by taskId, batch lookup by taskIds | Aegis quality gate workflow |

#### Platform Features (8 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `notifications.spec.ts` | GET with recipient filter/unread_only, POST mark-delivered, PUT mark-read by IDs/mark-all-read | Notification lifecycle |
| `mentions.spec.ts` | Task description mentions notify user + agent, unknown mentions rejected in descriptions and comments | @mention resolution and validation |
| `search-and-export.spec.ts` | Search with results/short-query/empty-query, export as JSON, activities feed | Cross-entity search + data export |
| `direct-cli.spec.ts` | POST /api/connect (auto-creates agent), GET connections list, heartbeat with inline token_usage, DELETE disconnect (sets agent offline), auth required | CLI integration lifecycle |
| `gateway-connect.spec.ts` | Returns ws_url and token for selected gateway, 404 for unknown | Gateway WebSocket URL resolution |
| `github-sync.spec.ts` | Auth required, GITHUB_TOKEN error, invalid action, sync status history, repo format validation | GitHub issue sync |
| `docs-knowledge.spec.ts` | Create/tree/search/content/delete flows for markdown knowledge docs, auth required | Knowledge base CRUD |
| `openclaw-harness.spec.ts` | Capabilities, sessions API, cron API, gateway config API from fixtures | OpenClaw offline mode validation |

#### API Standards (3 files)

| File | Tests | Key Assertions |
|------|-------|----------------|
| `delete-body.spec.ts` | 7 DELETE endpoints require JSON body, old query param style rejected | Body-based DELETE standardization |
| `limit-caps.spec.ts` | 6 endpoints cap `limit` to 200 (activities to 500), search caps at 100 | Unbounded pagination prevention |
| `openapi.spec.ts` | Valid OpenAPI 3.1, key paths present, accessible without auth | API documentation correctness |

---

## CI Pipeline

### Quality Gate

**File:** `.github/workflows/quality-gate.yml`

```yaml
name: Quality Gate
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: quality-gate-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - Checkout
      - Setup pnpm (v10)
      - Setup Node (v20)
      - Install dependencies (pnpm install --frozen-lockfile)
      - Lint (pnpm lint)
      - Typecheck (pnpm typecheck)
      - Unit tests (pnpm test)
      - Prepare E2E environment (cp .env.test .env)
      - Build (pnpm build)
      - Install Playwright browsers
      - E2E tests (pnpm test:e2e)
```

Execution order: **lint -> typecheck -> test -> build -> test:e2e**

Key characteristics:
- **Sequential single job**: All steps in one job, not parallel, because E2E depends on the build artifact
- **Cancel-in-progress**: Concurrency group cancels stale runs on the same ref
- **Frozen lockfile**: Prevents accidental dependency changes in CI
- **E2E environment**: Copies `.env.test` to `.env` for deterministic config

### Docker Publish

**File:** `.github/workflows/docker-publish.yml`

Triggered by:
- Quality Gate workflow completion (on `main`)
- Version tags (`v*.*.*`)
- Manual dispatch

Publishes to GHCR with multi-platform support (amd64 + arm64), provenance, and SBOM. Uses GitHub Actions cache for Docker layer caching.

---

## Test Patterns

### Authentication in Tests

Two patterns coexist:

1. **API Key auth** (most tests): `headers: { 'x-api-key': 'test-api-key-e2e-12345' }`
2. **Session auth** (login-flow only): Creates user -> POST `/api/auth/login` -> extracts `mc-session` cookie -> passes as `cookie` header

The API key approach is dominant because it's stateless and simpler. Session auth is only tested explicitly in `login-flow.spec.ts`.

### Test Data Creation

All test data is created via API calls, not database seeding:
```typescript
const { id, name, res, body } = await createTestAgent(request, { role: 'builder' })
cleanup.push(id)
```

This validates the full creation path including validation, normalization, event emission, and notification triggers.

### Full Lifecycle Pattern

Most CRUD test files include a final "full lifecycle" test:
```typescript
test('full lifecycle: create -> read -> update -> delete -> confirm gone', async ({ request }) => {
  // Create
  const { id } = await createTestEntity(request)
  expect(createRes.status()).toBe(201)
  // Read -> Update -> Delete -> GET returns 404
})
```

This pattern catches integration issues that individual operation tests miss.

### Browser-Based Tests

Only two test files use Playwright's browser context (page fixture):
- `device-identity.spec.ts`: Ed25519 Web Crypto operations and localStorage
- `legacy-cookie-removed.spec.ts`: Cookie-based auth redirect behavior

All other tests use the `request` fixture for pure API testing -- no browser rendering needed.

---

## Coverage Analysis

### Well-Tested Areas

| Area | Unit Tests | E2E Tests | Assessment |
|------|-----------|-----------|------------|
| Authentication (auth, roles, API keys) | `auth.test.ts` | 8 E2E files | Excellent: timing-safe, CSRF, rate limiting, agent keys |
| Validation (Zod schemas) | `validation.test.ts` | All CRUD files | Excellent: 10 schemas, plus E2E validates end-to-end |
| Webhooks (HMAC, retry, circuit breaker) | `webhooks.test.ts` | `webhooks-crud.spec.ts` | Excellent: crypto + retry logic unit tested |
| Rate limiting | `rate-limit.test.ts` | `rate-limiting.spec.ts` | Excellent: factory + integration |
| Task management | `task-status.test.ts`, `task-costs.test.ts` | 4 task-related E2E files | Excellent |
| Agent management | `db-helpers.test.ts` | 5 agent-related E2E files | Excellent |
| Token pricing | `token-pricing.test.ts` | `agent-costs.spec.ts` | Good |
| Security hardening | - | `actor-identity-hardening.spec.ts`, `device-identity.spec.ts` | Good |

### Under-Tested Areas

| Area | Gap | Risk |
|------|-----|------|
| **UI components** | Zero React component unit tests | Medium: UI bugs caught only by manual testing |
| **WebSocket server** | No WS integration tests | High: gateway connection is a critical path |
| **SSE event streaming** | No tests for `/api/events` SSE endpoint | Medium: real-time updates untested |
| **Scheduler** | No tests for background job execution timing | Low: simple interval logic |
| **Agent sync** | No unit tests for `agent-sync.ts` | Medium: complex merge logic |
| **Claude session scanning** | No unit tests for JSONL parsing | Low: integration tested via OpenClaw harness |
| **Database migrations** | No migration tests | Low: SQLite migrations are idempotent |
| **Frontend stores (Zustand)** | No store tests | Medium: state management logic untested |
| **Error handling** | Minimal negative path coverage in unit tests | Low: E2E covers most 4xx/5xx responses |
| **Multi-workspace isolation** | Tests only use default workspace | Medium: workspace scoping could leak data |

### The Hive's Testing Strategy Should

1. **Adopt the two-layer approach** (unit + E2E) with the same Vitest/Playwright stack
2. **Add WebSocket integration tests** -- MC's biggest gap is no WS testing
3. **Add React component tests** with Testing Library -- MC skips these entirely
4. **Add Zustand store tests** -- business logic in stores should be unit tested
5. **Test multi-tenant workspace isolation** -- MC only tests default workspace
6. **Increase coverage threshold** to 70-80% as the codebase matures
7. **Add visual regression tests** with Playwright screenshots for dashboard panels
8. **Add contract tests** for the event bus -- verify event schemas between producer and consumer
