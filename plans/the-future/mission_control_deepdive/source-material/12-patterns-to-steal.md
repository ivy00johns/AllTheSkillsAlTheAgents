# 12 — Patterns to Steal

Mission Control contains several code patterns that are battle-tested, well-structured, and directly applicable to The Hive. This document catalogs the best patterns, shows their implementation, explains why they work, and notes how The Hive should adapt each one.

---

## Pattern 1: The `requireRole()` Guard

**File:** `src/lib/auth.ts`

### The Pattern

```typescript
export function requireRole(
  request: Request,
  minRole: User['role']
): { user: User; error?: never; status?: never } | { user?: never; error: string; status: 401 | 403 } {
  const user = getUserFromRequest(request)
  if (!user) {
    return { error: 'Authentication required', status: 401 }
  }
  if ((ROLE_LEVELS[user.role] ?? -1) < ROLE_LEVELS[minRole]) {
    return { error: `Requires ${minRole} role or higher`, status: 403 }
  }
  return { user }
}
```

Usage in every API route:
```typescript
export async function GET(request: Request) {
  const auth = requireRole(request, 'viewer')
  if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status })
  const user = auth.user
  // ... route logic
}
```

### Why It's Good

- **Discriminated union return type**: TypeScript narrows `auth.user` to `User` (not `undefined`) after the error check, with zero type assertions
- **Role hierarchy is numeric**: `{ viewer: 0, operator: 1, admin: 2 }` -- simple integer comparison, not string matching
- **Separates 401 from 403**: Authentication failure (no identity) vs authorization failure (insufficient role) -- correct HTTP semantics
- **Multi-principal support**: `getUserFromRequest()` checks session cookie, then agent API key, then system API key -- transparent to the caller
- **Agent identity attribution**: `x-agent-name` header is parsed and attached to the user object for audit trails without requiring separate middleware

### How The Hive Should Adapt

- **Keep the discriminated union pattern** -- it eliminates entire classes of auth bugs
- **Extend the role hierarchy** to include fleet-level roles: `agent < operator < admin < fleet_admin`
- **Add scope-based permissions** alongside roles for fine-grained API access (MC already starts this with `auth_scopes`)
- **Consider middleware-based enforcement** instead of per-route guard calls, while keeping the guard available for routes that need custom logic

---

## Pattern 2: The `validateBody()` + Zod Pattern

**File:** `src/lib/validation.ts`

### The Pattern

```typescript
export async function validateBody<T>(
  request: Request,
  schema: ZodSchema<T>
): Promise<{ data: T } | { error: NextResponse }> {
  try {
    const body = await request.json()
    const data = schema.parse(body)
    return { data }
  } catch (err) {
    if (err instanceof ZodError) {
      const messages = err.issues.map((e) => `${e.path.join('.')}: ${e.message}`)
      return {
        error: NextResponse.json(
          { error: 'Validation failed', details: messages },
          { status: 400 }
        ),
      }
    }
    return {
      error: NextResponse.json({ error: 'Invalid request body' }, { status: 400 }),
    }
  }
}
```

Schemas are co-located in the same file:
```typescript
export const createTaskSchema = z.object({
  title: z.string().min(1, 'Title is required').max(500),
  status: z.enum(['inbox', 'assigned', 'in_progress', 'review', 'quality_review', 'done']).default('inbox'),
  priority: z.enum(['critical', 'high', 'medium', 'low']).default('medium'),
  tags: z.array(z.string()).default([]),
  metadata: z.record(z.string(), z.unknown()).default({}),
  // ... 15+ fields with defaults and constraints
})
```

### Why It's Good

- **Same discriminated union pattern** as `requireRole()` -- consistency reduces cognitive load
- **Zod schemas are self-documenting**: Defaults, enums, min/max constraints, and custom messages live in one place
- **Error messages are structured**: `details: ["status: Invalid enum value"]` with path information, not just "bad request"
- **JSON parse errors handled gracefully**: Non-JSON bodies get a clean error, not a stack trace
- **Schema reuse**: `updateTaskSchema = createTaskSchema.partial()` derives update schema from create schema

### How The Hive Should Adapt

- **Adopt Zod v4** (MC already uses `^4.3.6`) for its improved performance and tree-shaking
- **Co-locate schemas with routes** instead of a single `validation.ts` -- as the API grows, one file becomes unwieldy
- **Generate OpenAPI from Zod schemas** automatically (MC generates OpenAPI separately)
- **Add `validateQuery()` companion** for GET request query parameters -- MC validates query params ad-hoc in each route
- **Consider schema versioning** for API evolution -- MC doesn't version its schemas yet

---

## Pattern 3: Webhook Retry with Exponential Backoff + Circuit Breaker

**File:** `src/lib/webhooks.ts`

### The Pattern

```typescript
// Backoff schedule in seconds: 30s, 5m, 30m, 2h, 8h
const BACKOFF_SECONDS = [30, 300, 1800, 7200, 28800]
const MAX_RETRIES = parseInt(process.env.MC_WEBHOOK_MAX_RETRIES || '5', 10) || 5

export function nextRetryDelay(attempt: number): number {
  const base = BACKOFF_SECONDS[Math.min(attempt, BACKOFF_SECONDS.length - 1)]
  const jitter = base * 0.2 * (2 * Math.random() - 1) // +/-20%
  return Math.round(base + jitter)
}
```

The delivery function handles three outcomes:

```typescript
if (success) {
  // Reset consecutive failures on success
  db.prepare(`UPDATE webhooks SET consecutive_failures = 0 WHERE id = ?`).run(webhook.id)
} else {
  // Increment consecutive failures
  db.prepare(`UPDATE webhooks SET consecutive_failures = consecutive_failures + 1 WHERE id = ?`).run(webhook.id)

  if (attempt < MAX_RETRIES - 1) {
    // Schedule retry with next_retry_at timestamp
    const delaySec = nextRetryDelay(attempt)
    db.prepare(`UPDATE webhook_deliveries SET next_retry_at = ?`).run(nextRetryAt, deliveryId)
  } else {
    // Exhausted retries -- trip circuit breaker (disable webhook)
    if (wh.consecutive_failures >= MAX_RETRIES) {
      db.prepare(`UPDATE webhooks SET enabled = 0 WHERE id = ?`).run(webhook.id)
    }
  }
}
```

Retry processing is a separate scheduled task:
```typescript
export async function processWebhookRetries(): Promise<{ ok: boolean; message: string }> {
  // Find deliveries where next_retry_at <= now (limit 50)
  // Clear next_retry_at immediately (prevent double-processing)
  // Re-deliver each, incrementing attempt counter
}
```

### Why It's Good

- **Explicit backoff schedule** instead of formula: `[30, 300, 1800, 7200, 28800]` is readable and intentional
- **Jitter prevents thundering herd**: +/-20% randomization
- **Database-backed retry queue**: Survives server restarts (unlike in-memory timers)
- **Circuit breaker is simple**: `consecutive_failures >= MAX_RETRIES` disables the webhook
- **Double-processing prevention**: Clears `next_retry_at` before re-delivering
- **Delivery pruning**: Keeps last 200 deliveries per webhook, preventing table bloat
- **10-second timeout**: `AbortController` with timeout prevents slow endpoints from blocking the retry queue
- **HMAC-SHA256 signatures**: Every delivery is signed with the webhook's secret

### How The Hive Should Adapt

- **Generalize beyond webhooks**: The Hive needs circuit breakers for all external integrations (LLM providers, tool calls, remote agents), not just webhooks
- **Add circuit breaker states**: MC only has open/closed -- add half-open with probe requests
- **Use a proper job queue** (BullMQ or similar) instead of polling a database table every 60 seconds
- **Make backoff configurable per webhook** -- different services have different tolerance
- **Add dead letter handling** -- MC disables the webhook but doesn't alert the user or provide recovery UI

---

## Pattern 4: Factory Rate Limiter

**File:** `src/lib/rate-limit.ts`

### The Pattern

```typescript
export function createRateLimiter(options: RateLimiterOptions) {
  const store = new Map<string, RateLimitEntry>()

  // Periodic cleanup every 60s (timer doesn't prevent process exit)
  const cleanupInterval = setInterval(() => {
    const now = Date.now()
    for (const [key, entry] of store) {
      if (now > entry.resetAt) store.delete(key)
    }
  }, 60_000)
  if (cleanupInterval.unref) cleanupInterval.unref()

  return function checkRateLimit(request: Request): NextResponse | null {
    if (process.env.MC_DISABLE_RATE_LIMIT === '1' && !options.critical) return null
    const ip = extractClientIp(request)
    // ... sliding window check
  }
}

// Pre-configured instances
export const loginLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 5, critical: true })
export const mutationLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 60 })
export const readLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 120 })
export const heavyLimiter = createRateLimiter({ windowMs: 60_000, maxRequests: 10 })
```

### Why It's Good

- **Factory pattern**: Each limiter has its own Map store, window size, and limit -- no global state
- **`critical` flag**: Login limiter can't be disabled even in test mode -- security-critical rate limits stay on
- **`unref()` on timer**: Cleanup timer doesn't prevent Node.js process exit
- **Return type is `NextResponse | null`**: Null means allowed, non-null is the 429 response -- callers just check `if (result) return result`
- **Trusted proxy IP extraction**: Handles `x-forwarded-for` chain walking and `x-real-ip` fallback
- **Per-IP tracking**: Each IP gets independent counters

### How The Hive Should Adapt

- **Adopt the factory pattern** -- it's the right abstraction level
- **Add Redis-backed storage** for multi-instance deployments (MC's in-memory Map only works for single-process)
- **Add sliding window algorithm** instead of fixed window -- MC resets the entire window at expiry, allowing burst-at-boundary attacks
- **Add rate limit headers** (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) -- MC doesn't inform clients of their remaining quota
- **Add per-agent rate limits** in addition to per-IP -- agents should have separate quotas from human users

---

## Pattern 5: Singleton EventEmitter Surviving HMR

**File:** `src/lib/event-bus.ts`

### The Pattern

```typescript
class ServerEventBus extends EventEmitter {
  private static instance: ServerEventBus | null = null

  private constructor() {
    super()
    this.setMaxListeners(50)
  }

  static getInstance(): ServerEventBus {
    if (!ServerEventBus.instance) {
      ServerEventBus.instance = new ServerEventBus()
    }
    return ServerEventBus.instance
  }

  broadcast(type: EventType, data: any): ServerEvent {
    const event: ServerEvent = { type, data, timestamp: Date.now() }
    this.emit('server-event', event)
    return event
  }
}

// Use globalThis to survive HMR in development
const globalBus = globalThis as typeof globalThis & { __eventBus?: ServerEventBus }
export const eventBus = globalBus.__eventBus ?? ServerEventBus.getInstance()
globalBus.__eventBus = eventBus as ServerEventBus
```

### Why It's Good

- **HMR survival via `globalThis`**: In Next.js dev mode, module re-evaluation would create a new EventEmitter, orphaning all SSE listeners. Storing on `globalThis` prevents this.
- **Single emission channel**: All events go through `emit('server-event', event)` -- one listener on the bus gets everything, simplifying SSE forwarding
- **Typed event catalog**: `EventType` union lists all 16 event types -- TypeScript catches typos in event names
- **`setMaxListeners(50)`**: Prevents Node.js warnings when many SSE clients are connected simultaneously
- **Broadcast returns the event**: Callers can use the constructed event object for logging or chaining

### How The Hive Should Adapt

- **Keep the globalThis pattern** for HMR survival -- this is a non-obvious requirement that breaks real-time features during development
- **Replace EventEmitter with a proper pub/sub** for multi-process deployments (Redis pub/sub, or NATS)
- **Add event schemas** with Zod validation -- MC trusts that event payloads match their expected shapes
- **Add wildcard subscriptions**: MC's webhook system already does event pattern matching (`activity.*`), but the bus itself only supports exact matches
- **Add backpressure handling**: If SSE consumers are slow, events queue up in memory indefinitely

---

## Pattern 6: Bidirectional Agent Config Sync with SHA-256

**File:** `src/lib/agent-sync.ts`

### The Pattern

MC reads agents from `openclaw.json` and upserts them into SQLite, preserving workspace file enrichment:

```typescript
export async function syncAgentsFromConfig(actor: string = 'system'): Promise<SyncResult> {
  const agents = await readOpenClawAgents()       // Parse openclaw.json
  for (const agent of agents) {
    const mapped = mapAgentToMC(agent)             // Extract MC fields
    const configJson = JSON.stringify(mapped.config)
    const existing = findByName.get(mapped.name)

    if (existing) {
      const configChanged = existingConfig !== configJson || existing.role !== mapped.role
      const soulChanged = mapped.soul_content !== null && mapped.soul_content !== existingSoul
      if (configChanged || soulChanged) {
        updateAgent.run(mapped.role, configJson, soulToWrite, now, mapped.name)
      }
    } else {
      insertAgent.run(mapped.name, mapped.role, mapped.soul_content, now, now, configJson)
    }
  }
}
```

Workspace enrichment reads `identity.md` and `TOOLS.md` from agent directories:
```typescript
export function enrichAgentConfigFromWorkspace(configData: any): any {
  const identityFile = readWorkspaceFile(workspace, 'identity.md')
  const toolsFile = readWorkspaceFile(workspace, 'TOOLS.md')
  // Merge file-based identity/tools with config-based, config wins
}
```

Bidirectional write-back:
```typescript
export async function writeAgentToConfig(agentConfig: any): Promise<void> {
  const parsed = parseJsonRelaxed<any>(raw)
  const idx = parsed.agents.list.findIndex((a) => a.id === agentConfig.id)
  if (idx >= 0) {
    parsed.agents.list[idx] = deepMerge(parsed.agents.list[idx], agentConfig)
  } else {
    parsed.agents.list.push(agentConfig)
  }
  await writeFile(configPath, JSON.stringify(parsed, null, 2) + '\n')
}
```

### Why It's Good

- **Config as source of truth with DB as cache**: File changes propagate to DB on sync, not the other way around (for reads)
- **Deep merge preserves unmanaged fields**: `deepMerge()` only overwrites fields present in the update, keeping user customizations
- **Change detection before write**: Only updates DB rows when config or soul_content actually changed -- prevents unnecessary events
- **Workspace file enrichment**: Agent identity and tools are enriched from the filesystem, not just from JSON config
- **Transactional batch sync**: All agent upserts happen in a single `db.transaction()` -- atomic all-or-nothing
- **Path traversal protection**: `resolveWithin()` prevents agents from reading files outside their workspace

### How The Hive Should Adapt

- **Adopt the enrichment pattern** -- agents that read their own workspace files for identity/tools is powerful
- **Add SHA-256 content hashing** for change detection instead of JSON string comparison (MC compares stringified JSON, which is order-dependent)
- **Use file watchers** (`chokidar` or `fs.watch`) for real-time sync instead of polling on a scheduler interval
- **Add conflict resolution UI** -- when both MC and config file change, MC silently overwrites the DB; The Hive should detect and present conflicts
- **Support multiple config sources** (not just one `openclaw.json`) -- The Hive's skill registry should handle distributed config

---

## Pattern 7: Natural Language Schedule Parsing

**File:** `src/lib/schedule-parser.ts` was not found, but the cron occurrence engine exists.

**File:** `src/lib/cron-occurrences.ts` (tested in `cron-occurrences.test.ts`)

### The Pattern

```typescript
export function getCronOccurrences(cron: string, start: number, end: number): CronOccurrence[] {
  // Strips OpenClaw timezone suffix: "0 6 * * * (UTC)" -> "0 6 * * *"
  // Expands cron expression into individual occurrences within [start, end] range
  // Returns array of { dayKey: 'YYYY-MM-DD', timestamp: number }
}
```

### Why It's Good

- **Tolerance of vendor-specific syntax**: Strips `(UTC)` suffix that OpenClaw adds
- **Range-based expansion**: Useful for calendar views and schedule previews
- **Graceful failure**: Returns empty array for invalid cron, doesn't throw

### How The Hive Should Adapt

- **Build a full natural language parser**: "every weekday at 9am" -> cron expression
- **Add schedule preview API**: Show next N occurrences before saving
- **Support interval-based schedules** alongside cron (e.g., "every 30 minutes") for simpler use cases

---

## Pattern 8: Ed25519 Device Identity

**File:** `src/lib/device-identity.ts`

### The Pattern

```typescript
export async function getOrCreateDeviceIdentity(): Promise<DeviceIdentity> {
  // Check localStorage for existing identity
  const storedId = localStorage.getItem('mc-device-id')
  const storedPub = localStorage.getItem('mc-device-pubkey')
  const storedPriv = localStorage.getItem('mc-device-privkey')

  if (storedId && storedPub && storedPriv) {
    try {
      const privateKey = await importPrivateKey(fromBase64Url(storedPriv))
      return { deviceId: storedId, publicKeyBase64: storedPub, privateKey }
    } catch {
      // Corrupted keys -- regenerate
    }
  }
  return createNewIdentity()
}

async function createNewIdentity(): Promise<DeviceIdentity> {
  const keyPair = await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify'])
  // deviceId = sha256(rawPublicKey) in hex
  const deviceId = await sha256Hex(pubRaw)
  // Store in localStorage as base64url
  localStorage.setItem(STORAGE_DEVICE_ID, deviceId)
  localStorage.setItem(STORAGE_PUBKEY, toBase64Url(pubRaw))
  localStorage.setItem(STORAGE_PRIVKEY, toBase64Url(privPkcs8))
  return { deviceId, publicKeyBase64, privateKey: keyPair.privateKey }
}

export async function signPayload(
  privateKey: CryptoKey,
  payload: string,
  signedAt = Date.now()
): Promise<{ signature: string; signedAt: number }> {
  const payloadBytes = encoder.encode(payload)
  const signatureBuffer = await crypto.subtle.sign('Ed25519', privateKey, payloadBytes)
  return { signature: toBase64Url(signatureBuffer), signedAt }
}
```

### Why It's Good

- **Zero-dependency cryptography**: Uses Web Crypto API (available in all modern browsers), no npm packages
- **Persistent identity**: Survives page reloads via localStorage
- **Self-healing**: Corrupted keys trigger automatic regeneration
- **Challenge-response ready**: `signPayload()` signs nonces for WebSocket handshake authentication
- **Device ID derived from public key**: `sha256(publicKey)` makes the ID deterministic and verifiable
- **Base64url encoding**: URL-safe encoding for use in headers and query parameters
- **Graceful degradation**: When Ed25519 isn't supported, falls back to token-only auth

### How The Hive Should Adapt

- **Adopt the full pattern** -- device identity is essential for browser-to-agent trust
- **Extend to agent identity**: CLI agents should also generate Ed25519 key pairs for mutual authentication
- **Add key rotation**: MC never rotates keys; The Hive should support periodic rotation with overlap period
- **Add server-side key verification**: MC generates keys but the gateway validates them -- The Hive should verify signatures in its own backend
- **Consider IndexedDB** instead of localStorage for key storage -- localStorage is synchronous and has 5MB limits

---

## Pattern 9: Smart Polling with Page Visibility API

**File:** `src/lib/use-smart-poll.ts`

### The Pattern

```typescript
export function useSmartPoll(
  callback: () => void | Promise<void>,
  intervalMs: number,
  options: SmartPollOptions = {}
) {
  // Options: pauseWhenConnected, pauseWhenDisconnected, pauseWhenSseConnected, backoff, enabled

  // Always fire initial fetch on mount (bootstrap data)
  if (!initialFiredRef.current && enabled) {
    initialFiredRef.current = true
    callbackRef.current()
  }

  // Visibility change handler
  const handleVisibilityChange = () => {
    isVisibleRef.current = document.visibilityState === 'visible'
    if (isVisibleRef.current) {
      backoffMultiplierRef.current = 1  // Reset backoff
      fire()                             // Immediate fetch
      startInterval()                    // Restart polling
    } else {
      clearInterval(intervalRef.current) // Stop polling when hidden
    }
  }
  document.addEventListener('visibilitychange', handleVisibilityChange)

  // Returns manual trigger function
  return fire
}
```

### Why It's Good

- **Battery/bandwidth conservation**: Stops polling when tab is hidden
- **Instant recovery**: Fires immediately when tab becomes visible, then restarts interval
- **SSE/WS coordination**: Can pause polling when real-time connection is active (no redundant fetches)
- **Backoff on errors**: Failed fetches increase interval by 0.5x up to `maxBackoffMultiplier` (default 3x)
- **Bootstrap guarantee**: Always fires initial fetch regardless of WS/SSE state -- SSE delivers events but not initial state
- **Manual trigger**: Returns a `fire()` function for imperative refresh (e.g., after user action)
- **Used extensively**: 14+ components use this hook -- it's the standard polling mechanism

### How The Hive Should Adapt

- **Adopt the hook directly** -- it's the right abstraction for dashboard panels
- **Add exponential backoff** instead of linear (+0.5x per failure)
- **Add stale data detection**: If poll returns identical data N times, increase interval
- **Integrate with The Trail**: Log poll intervals and skip reasons for observability
- **Add request deduplication**: If a manual trigger fires while a poll is in-flight, don't send a second request

---

## Pattern 10: JSONL Session Transcript Scanning

**File:** `src/lib/claude-sessions.ts`

### The Pattern

```typescript
function parseSessionFile(filePath: string, projectSlug: string): SessionStats | null {
  const content = readFileSync(filePath, 'utf-8')
  const lines = content.split('\n').filter(Boolean)

  for (const line of lines) {
    let entry: JSONLEntry
    try { entry = JSON.parse(line) } catch { continue }

    // Extract session ID, git branch, project path from first occurrence
    // Count user messages, assistant messages, tool uses
    // Accumulate token usage (input, output, cache read, cache creation)
    // Track first/last message timestamps
    // Skip sidechain (subagent) messages for counts
  }

  // Estimate cost with model-specific pricing
  const pricing = MODEL_PRICING[model] || DEFAULT_PRICING
  const estimatedCost =
    inputTokens * pricing.input +
    cacheReadTokens * pricing.input * 0.1 +       // Cache reads = 10% of input cost
    cacheCreationTokens * pricing.input * 1.25 +   // Cache creation = 125% of input cost
    outputTokens * pricing.output

  // Active if last message < 5 minutes ago
  const isActive = (Date.now() - new Date(lastMessageAt).getTime()) < 5 * 60 * 1000

  return { sessionId, model, inputTokens, outputTokens, estimatedCost, isActive, ... }
}
```

Sync function runs every 60 seconds via the scheduler:
```typescript
export async function syncClaudeSessions(): Promise<{ ok: boolean; message: string }> {
  const sessions = scanClaudeSessions()
  db.transaction(() => {
    db.prepare('UPDATE claude_sessions SET is_active = 0').run()  // Mark all inactive
    for (const s of sessions) { upsert.run(...) }                 // Upsert each session
  })()
}
```

### Why It's Good

- **Non-intrusive discovery**: Reads Claude Code's own JSONL files, no agent instrumentation needed
- **Resilient parsing**: Invalid JSON lines are skipped, not fatal
- **Sidechain awareness**: Skips subagent messages to avoid double-counting
- **Cache-aware cost estimation**: Differentiates cache read (10% cost), cache creation (125% cost), and fresh tokens
- **Active detection**: Simple timestamp-based heuristic (< 5 minutes)
- **Transactional sync**: Marks all sessions inactive, then re-activates discovered ones -- handles session termination
- **Lightweight**: File stat checks + line-by-line parsing, runs every 60s without meaningful overhead

### How The Hive Should Adapt

- **Extend to multiple agent runtimes**: Not just Claude Code -- parse Codex CLI, Aider, Continue, and custom agent logs
- **Add file watcher** instead of 60-second polling for faster detection
- **Stream large files**: MC reads entire JSONL files into memory; for long sessions, use streaming line reader
- **Add session fingerprinting**: Hash session content for change detection instead of re-parsing unchanged files
- **Feed into The Trail**: Session transcripts should flow into the unified trace view

---

## Pattern 11: Structured Logging with Pino

**File:** `src/lib/logger.ts`

### The Pattern

```typescript
import pino from 'pino'

function hasPinoPretty(): boolean {
  try {
    require.resolve('pino-pretty')
    return true
  } catch {
    return false
  }
}

const usePretty = process.env.NODE_ENV !== 'production' && hasPinoPretty()

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  ...(usePretty && {
    transport: { target: 'pino-pretty', options: { colorize: true } },
  }),
})
```

Usage throughout the codebase:
```typescript
logger.info({ synced, created, updated }, 'Agent sync complete')
logger.warn({ webhookId: webhook.id, name: webhook.name }, 'Webhook circuit breaker tripped')
logger.error({ err, webhookId: webhook.id }, 'Webhook delivery logging/pruning failed')
```

### Why It's Good

- **Structured by default**: Every log entry is JSON in production, structured data as first argument
- **Graceful pretty-print**: Detects `pino-pretty` availability at runtime, falls back to JSON if not installed
- **Environment-aware**: Pretty in dev, JSON in production, configurable via `LOG_LEVEL`
- **No dependency on pretty-print**: `pino-pretty` is a devDependency, not bundled in production
- **Context objects**: `{ err, webhookId }` attaches structured context without string interpolation

### How The Hive Should Adapt

- **Adopt Pino directly** -- it's the fastest Node.js logger and the structured output is essential for The Trail
- **Add request correlation IDs**: Every log entry should include a request/trace ID for correlation
- **Add agent context**: Every log entry from an agent operation should include `agentId`, `agentName`
- **Pipe to The Trail**: JSON logs should flow directly into the unified observability system
- **Add log levels per module**: Different subsystems (auth, scheduler, sync) should have independent log levels

---

## Pattern 12: The API Route Template

Every API route in MC follows the same structure. Here's the implicit template:

### The Pattern

```typescript
import { NextResponse } from 'next/server'
import { requireRole } from '@/lib/auth'
import { validateBody } from '@/lib/validation'
import { someLimiter } from '@/lib/rate-limit'
import { getDatabase, logAuditEvent } from '@/lib/db'
import { eventBus } from '@/lib/event-bus'
import { logger } from '@/lib/logger'

export async function POST(request: Request) {
  // 1. Rate limiting
  const limited = someLimiter(request)
  if (limited) return limited

  // 2. Authentication + authorization
  const auth = requireRole(request, 'operator')
  if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status })

  // 3. Body validation
  const parsed = await validateBody(request, someSchema)
  if ('error' in parsed) return parsed.error

  // 4. Business logic
  try {
    const db = getDatabase()
    const result = db.prepare('INSERT INTO ...').run(...)

    // 5. Side effects: events, audit, notifications
    eventBus.broadcast('entity.created', { ... })
    logAuditEvent({ action: 'entity_create', actor: auth.user.username, detail: { ... } })

    // 6. Response
    return NextResponse.json({ entity: result }, { status: 201 })
  } catch (err: any) {
    if (err.message?.includes('UNIQUE constraint')) {
      return NextResponse.json({ error: 'Already exists' }, { status: 409 })
    }
    logger.error({ err }, 'Failed to create entity')
    return NextResponse.json({ error: 'Internal error' }, { status: 500 })
  }
}
```

### Why It's Good

- **Consistent ordering**: Rate limit -> Auth -> Validate -> Logic -> Events -> Response
- **Early returns at each gate**: No deeply nested conditionals
- **SQLite error handling**: UNIQUE constraint violations caught and mapped to 409
- **Audit trail for all mutations**: `logAuditEvent()` called after successful writes
- **Event-driven side effects**: Webhook dispatch, SSE notifications, and activity logging happen via the event bus

### How The Hive Should Adapt

- **Codify as middleware chain** instead of repeated boilerplate -- The Hive should compose rate-limit, auth, validation, and audit as middleware
- **Add request tracing**: Wrap each route in a trace span for The Trail
- **Add response envelope standardization**: MC's responses vary (`{ task }`, `{ agent }`, `{ success: true }`) -- standardize to `{ data, meta, errors }`
- **Add workspace scoping middleware**: MC handles workspace_id ad-hoc in each route; The Hive should scope queries automatically

---

## Summary: The 12 Patterns Ranked by Adoption Priority

| Priority | Pattern | Verdict |
|----------|---------|---------|
| 1 | `requireRole()` discriminated union | **Copy exactly**, extend role hierarchy |
| 2 | `validateBody()` + Zod schemas | **Copy exactly**, add query validation |
| 3 | API route template (rate-limit -> auth -> validate -> logic -> events) | **Codify as middleware** |
| 4 | Singleton EventEmitter with globalThis HMR survival | **Copy for dev**, replace with pub/sub for prod |
| 5 | Smart polling with Page Visibility API | **Copy the hook**, add exponential backoff |
| 6 | Factory rate limiter | **Copy pattern**, add Redis backing |
| 7 | Webhook retry with exponential backoff + circuit breaker | **Generalize** to all integrations |
| 8 | JSONL session scanning | **Extend** to multi-runtime agent discovery |
| 9 | Ed25519 device identity | **Copy for browser**, extend to CLI agents |
| 10 | Structured logging with Pino | **Copy exactly**, add correlation IDs |
| 11 | Bidirectional agent config sync | **Adopt enrichment pattern**, add file watchers |
| 12 | Cron occurrence expansion | **Build richer** natural language scheduler |
