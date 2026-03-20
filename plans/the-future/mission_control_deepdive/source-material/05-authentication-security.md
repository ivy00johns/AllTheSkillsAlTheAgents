# 05 — Authentication, Authorization & Security Architecture

This document dissects every security layer in Mission Control: authentication flows, session management, RBAC, proxy-level gates, rate limiting, security headers, audit logging, device identity, and workspace isolation. All file paths are relative to `~/AI/mission-control/`.

---

## 1. Authentication Methods

Mission Control supports three authentication principals, resolved in `src/lib/auth.ts` via `getUserFromRequest()`:

| Priority | Method | Header / Cookie | Principal Type | Effective Role |
|----------|--------|-----------------|----------------|----------------|
| 1 | Session cookie | `mc-session` cookie | `user` | From `users.role` column |
| 2 | Agent API key | `x-api-key` or `Authorization: Bearer mca_...` | `agent_api_key` | Derived from key scopes |
| 3 | System API key | `x-api-key` or `Authorization: Bearer ...` | `system_api_key` | Always `admin` |

### 1.1 Session Cookie Authentication

The primary browser auth flow. On login (`POST /api/auth/login`), the server:

1. Rate-limits via `loginLimiter` (5 req/min, critical — cannot be disabled)
2. Calls `authenticateUser(username, password)` which:
   - Looks up user by username
   - Rejects if provider is not `local`
   - Rejects if `is_approved !== 1`
   - Verifies password via scrypt (see Section 3)
3. Creates a session via `createSession()` (see Section 4)
4. Sets the `mc-session` cookie with options from `getMcSessionCookieOptions()`
5. Logs audit event `login` (or `login_failed` on failure)

Cookie attributes (`src/lib/session-cookie.ts`):

```typescript
{
  httpOnly: true,
  secure: secureEnv ?? isSecureRequest ?? (NODE_ENV === 'production'),
  sameSite: process.env.MC_COOKIE_SAMESITE || 'strict',  // strict/lax/none
  maxAge: expiresAt - now,
  path: '/',
}
```

Key design choice: `sameSite: 'strict'` by default. This is the strongest CSRF cookie protection available, and is safe because Mission Control's UI and API share the same origin.

### 1.2 System API Key Authentication

The `API_KEY` environment variable defines a global system key. When matched (via constant-time comparison), a synthetic user is returned:

```typescript
{
  id: 0,
  username: 'api',
  display_name: 'API Access',
  role: 'admin',           // Always admin
  principal_type: 'system_api_key',
  auth_scopes: ['admin'],
}
```

The key is extracted from either `x-api-key` header or `Authorization: Bearer|ApiKey|Token <key>` (`extractApiKeyFromHeaders()`).

### 1.3 Agent API Keys

Per-agent scoped keys stored in the `agent_api_keys` table. Validated in `validateAgentApiKey()`:

1. The raw key is SHA-256 hashed and looked up in `agent_api_keys`
2. Must not be revoked (`revoked_at IS NULL`)
3. Must not be expired (`expires_at IS NULL OR expires_at > now`)
4. Agent must exist in same workspace
5. Role is derived from scopes: `admin > operator > viewer`
6. `last_used_at` is updated on each use (best-effort, swallows lock errors)

```typescript
interface AgentApiKeyRow {
  id: number
  agent_id: number
  workspace_id: number
  name: string
  scopes: string          // JSON array: ["operator"], ["admin"], etc.
  expires_at: number | null
  revoked_at: number | null
  key_hash: string        // SHA-256 of raw key
  agent_name: string
}
```

Agent keys use the `mca_` prefix convention. The proxy (`src/proxy.ts`) allows `mca_`-prefixed keys to pass through to route handlers without validating against the system API key — actual DB validation happens in `auth.ts`.

### 1.4 Google OAuth with Admin Approval

Flow handled by `POST /api/auth/google` (`src/app/api/auth/google/route.ts`):

1. Client sends Google ID token (credential) from Google Sign-In
2. Server calls `verifyGoogleIdToken()` (`src/lib/google-auth.ts`):
   - Verifies token via `https://oauth2.googleapis.com/tokeninfo`
   - Validates audience matches `GOOGLE_CLIENT_ID` env var
   - Requires `email_verified === true`
3. Looks up user by `provider_user_id` (Google `sub`) or email
4. **If no user exists or user is not approved**: creates an `access_request` record (status: `pending`) and returns `403 PENDING_APPROVAL`
5. **If user exists and is approved**: creates session, sets cookie, returns user

Admin approval flow (`src/app/api/auth/access-requests/route.ts`):

- `GET /api/auth/access-requests` — List pending/all requests (admin only)
- `POST /api/auth/access-requests` — Approve or reject:
  - **Approve**: Creates user account (random 48-char hex password), sets `is_approved = 1`, assigns role
  - **Reject**: Marks request as rejected

This is a deliberate "admin gate" pattern — Google users cannot self-provision access.

---

## 2. Constant-Time Comparison

Two implementations of `safeCompare` exist (one in `src/lib/auth.ts`, one in `src/proxy.ts`), both using `crypto.timingSafeEqual`:

```typescript
// src/lib/auth.ts — handles length mismatch securely
export function safeCompare(a: string, b: string): boolean {
  if (typeof a !== 'string' || typeof b !== 'string') return false
  const bufA = Buffer.from(a)
  const bufB = Buffer.from(b)
  if (bufA.length !== bufB.length) {
    // Compare against dummy buffer to avoid timing leak on length mismatch
    const dummy = Buffer.alloc(bufA.length)
    timingSafeEqual(bufA, dummy)
    return false
  }
  return timingSafeEqual(bufA, bufB)
}
```

The `auth.ts` version is more paranoid: when lengths differ, it still performs a `timingSafeEqual` against a dummy buffer to avoid leaking timing information about whether the lengths matched. The `proxy.ts` version skips this (returns `false` immediately on length mismatch).

Used for: API key validation (system key), agent API key hash comparison, session token comparison.

---

## 3. Password Handling

Implemented in `src/lib/password.ts`. Uses Node.js built-in `scryptSync` — no external dependencies.

### Parameters

| Parameter | Value |
|-----------|-------|
| Algorithm | scrypt |
| Salt length | 16 bytes (random) |
| Key length | 32 bytes |
| Cost (N) | 16384 |
| Storage format | `{hex_salt}:{hex_hash}` |

### Implementation

```typescript
export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex')
  const hash = scryptSync(password, salt, 32, { N: 16384 }).toString('hex')
  return `${salt}:${hash}`
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':')
  if (!salt || !hash) return false
  const derived = scryptSync(password, salt, 32, { N: 16384 })
  const storedBuf = Buffer.from(hash, 'hex')
  if (derived.length !== storedBuf.length) return false
  return timingSafeEqual(derived, storedBuf)
}
```

### Password Policy

- Minimum 12 characters enforced at user creation (`src/lib/auth.ts`, `createUser()`)
- Minimum 12 characters enforced by Zod schema for the create-user API (`src/lib/validation.ts`, `createUserSchema`)
- Self-service password change via `PATCH /api/auth/me` uses a weaker 8-char minimum (inconsistency worth noting)
- No complexity requirements beyond length

### Insecure Default Detection

The admin seeding flow (from environment variables `AUTH_USER` / `AUTH_PASS`) could create users with the default password. The Settings panel and security audit surface this as a security posture finding.

---

## 4. Session Management

Implemented in `src/lib/auth.ts`. All sessions live in the `user_sessions` SQLite table.

### Session Lifecycle

| Operation | Function | Details |
|-----------|----------|---------|
| Create | `createSession()` | 32 random bytes → hex token, 7-day TTL |
| Validate | `validateSession()` | JOIN users + sessions, check expiry |
| Destroy | `destroySession()` | DELETE by token |
| Destroy all | `destroyAllUserSessions()` | DELETE by user_id |

### Token Generation

```typescript
const SESSION_DURATION = 7 * 24 * 60 * 60  // 7 days in seconds

export function createSession(userId, ipAddress?, userAgent?, workspaceId?) {
  const token = randomBytes(32).toString('hex')  // 64 hex chars
  const expiresAt = now + SESSION_DURATION
  // INSERT into user_sessions
  // UPDATE users SET last_login_at
  // DELETE expired sessions (cleanup)
  return { token, expiresAt }
}
```

### Session Table Schema

```sql
-- From migration 006_users
CREATE TABLE user_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  workspace_id INTEGER NOT NULL DEFAULT 1,
  expires_at INTEGER NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Validation Flow

`validateSession()` does a single JOIN query:

```sql
SELECT u.*, s.id as session_id
FROM user_sessions s
JOIN users u ON u.id = s.user_id
WHERE s.token = ? AND s.expires_at > ?
```

No token hashing — tokens are stored and compared as plaintext hex strings. The 256-bit entropy (32 random bytes) makes brute force infeasible, but a database leak would expose all active sessions.

---

## 5. Role-Based Access Control (RBAC)

### Role Hierarchy

```typescript
const ROLE_LEVELS: Record<string, number> = {
  viewer: 0,
  operator: 1,
  admin: 2,
}
```

### The `requireRole()` Pattern

The primary authorization primitive. Returns a discriminated union:

```typescript
export function requireRole(
  request: Request,
  minRole: User['role']
): { user: User } | { error: string; status: 401 | 403 } {
  const user = getUserFromRequest(request)
  if (!user) return { error: 'Authentication required', status: 401 }
  if (ROLE_LEVELS[user.role] < ROLE_LEVELS[minRole])
    return { error: `Requires ${minRole} role or higher`, status: 403 }
  return { user }
}
```

Usage in route handlers:

```typescript
// Admin-only endpoint
const auth = requireRole(request, 'admin')
if ('error' in auth) return NextResponse.json({ error: auth.error }, { status: auth.status })
const { user } = auth
```

### Role Capabilities

| Capability | Viewer | Operator | Admin |
|------------|--------|----------|-------|
| View dashboard, tasks, agents | Yes | Yes | Yes |
| View own profile (`GET /api/auth/me`) | Yes | Yes | Yes |
| Create/update tasks | No | Yes | Yes |
| Manage agents | No | Yes | Yes |
| Send chat messages | No | Yes | Yes |
| Manage users | No | No | Yes |
| View audit log | No | No | Yes |
| Approve Google access requests | No | No | Yes |
| Change user roles | No | No | Yes |
| Delete users | No | No | Yes |
| Manage settings | No | No | Yes |
| Manage webhooks | No | Yes | Yes |
| Super admin / tenant provisioning | No | No | Yes |

### Self-Protection Rules

- Admins cannot change their own role (`PUT /api/auth/users`)
- Admins cannot delete their own account (`DELETE /api/auth/users`)

---

## 6. Proxy Auth Gate

`src/proxy.ts` is a Next.js middleware that runs before every request. It enforces authentication at the network edge.

### Request Flow

```
Request → Host Allowlist → CSRF Check → Route Classification → Auth Check → Security Headers
```

### 6.1 Host Allowlist

```typescript
const allowAnyHost = envFlag('MC_ALLOW_ANY_HOST') || process.env.NODE_ENV !== 'production'
const allowedPatterns = process.env.MC_ALLOWED_HOSTS?.split(',')
```

- **Development**: All hosts allowed by default
- **Production**: Default-deny unless `MC_ALLOWED_HOSTS` is set
- Supports wildcard patterns: `*.example.com`, `100.*`
- Hostname extracted from `x-forwarded-host` or `host` header (first in chain)

### 6.2 CSRF Origin Validation

For mutating methods (`POST`, `PUT`, `DELETE`, `PATCH`):

```typescript
const origin = request.headers.get('origin')
if (origin) {
  const originHost = new URL(origin).host
  const requestHost = request.headers.get('host')
  if (originHost !== requestHost) {
    return NextResponse.json({ error: 'CSRF origin mismatch' }, { status: 403 })
  }
}
```

This is a simple origin-vs-host comparison. Combined with `sameSite: 'strict'` cookies, it provides double-layer CSRF protection. Note: if no `Origin` header is present (e.g., same-origin form submissions), the check is skipped.

### 6.3 Route Classification

| Route Pattern | Auth Required | Notes |
|---------------|---------------|-------|
| `/login` | No | Login page |
| `/api/auth/*` | No | Auth endpoints (login, Google OAuth) |
| `/api/docs`, `/docs` | No | API documentation |
| `/api/*` | Yes | Session cookie OR API key |
| `/*` (pages) | Yes | Session cookie only, redirects to `/login` |

### 6.4 Agent API Key Pass-Through

The proxy recognizes `mca_`-prefixed keys and lets them through without DB validation:

```typescript
const hasAgentApiKeyCandidate = apiKey.startsWith('mca_')
if (sessionToken || hasValidApiKey || hasAgentApiKeyCandidate) {
  return applySecurityHeaders(NextResponse.next())
}
```

This avoids coupling middleware to database access. Actual validation happens in route handlers via `validateAgentApiKey()`.

### 6.5 Security Headers Applied by Proxy

Every response passing through the proxy gets:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
```

---

## 7. Rate Limiting

Implemented in `src/lib/rate-limit.ts` using a factory pattern with in-memory `Map` stores.

### Factory Pattern

```typescript
export function createRateLimiter(options: {
  windowMs: number
  maxRequests: number
  message?: string
  critical?: boolean    // If true, MC_DISABLE_RATE_LIMIT won't bypass
}) → (request: Request) → NextResponse | null
```

### Four Pre-Configured Tiers

| Tier | Variable | Window | Max Requests | Critical | Used By |
|------|----------|--------|--------------|----------|---------|
| Login | `loginLimiter` | 60s | 5 | Yes | `POST /api/auth/login` |
| Mutation | `mutationLimiter` | 60s | 60 | No | User creation, access requests |
| Heavy | `heavyLimiter` | 60s | 10 | No | Resource-intensive endpoints |
| Read | `readLimiter` | 60s | 120 | No | Polling endpoints |

### IP Extraction

```typescript
export function extractClientIp(request: Request): string {
  const xff = request.headers.get('x-forwarded-for')
  if (xff && TRUSTED_PROXIES.size > 0) {
    // Walk right-to-left, skip trusted proxies, return first untrusted
    const ips = xff.split(',').map(s => s.trim())
    for (let i = ips.length - 1; i >= 0; i--) {
      if (!TRUSTED_PROXIES.has(ips[i])) return ips[i]
    }
  }
  return request.headers.get('x-real-ip')?.trim() || 'unknown'
}
```

`MC_TRUSTED_PROXIES` is a comma-separated list of proxy IPs. The right-to-left walk prevents client-spoofed IP injection — only the rightmost untrusted IP is used.

### Per-Agent Attribution

While rate limiting is IP-based, the `x-agent-name` header is captured in `getUserFromRequest()` for audit attribution. This allows tracking which agent made which request without affecting rate limit buckets.

### Disable for Testing

`MC_DISABLE_RATE_LIMIT=1` disables all non-critical limiters (useful for E2E tests). The `loginLimiter` is marked `critical: true` and cannot be disabled.

### Cleanup

Each limiter runs a 60-second cleanup interval (`setInterval` with `.unref()` to prevent blocking process exit) that purges expired entries from the in-memory store.

---

## 8. Security Headers

### Next.js Config Headers (`next.config.js`)

Applied to all routes via `async headers()`:

```javascript
const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'" + (googleEnabled ? ' https://accounts.google.com' : ''),
  "style-src 'self' 'unsafe-inline'",
  "connect-src 'self' ws: wss: http://127.0.0.1:* http://localhost:*",
  "img-src 'self' data: blob:" + (googleEnabled ? ' https://*.googleusercontent.com' : ''),
  "font-src 'self' data:",
  "frame-src 'self'" + (googleEnabled ? ' https://accounts.google.com' : ''),
].join('; ')
```

| Header | Value |
|--------|-------|
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Content-Security-Policy` | Dynamic (see above) |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |
| `Strict-Transport-Security` | Only if `MC_ENABLE_HSTS=1`: `max-age=63072000; includeSubDomains; preload` |

### CSP Notes

- `'unsafe-inline'` is used for both scripts and styles (common in Next.js apps with Tailwind)
- The original design mentions per-request nonces but the current implementation uses `'unsafe-inline'` instead — a pragmatic compromise for Next.js compatibility
- WebSocket connections are explicitly allowed via `connect-src 'self' ws: wss: http://127.0.0.1:* http://localhost:*`
- Google domains are conditionally added only when `NEXT_PUBLIC_GOOGLE_CLIENT_ID` or `GOOGLE_CLIENT_ID` is set

### HSTS

Opt-in via `MC_ENABLE_HSTS=1`. When enabled, sets a 2-year max-age with `includeSubDomains` and `preload`. Correctly defaults to off since many deployments are localhost/HTTP-only.

---

## 9. Ed25519 Device Identity

Implemented as a client-side module in `src/lib/device-identity.ts` (marked `'use client'`). Used for the OpenClaw gateway WebSocket handshake (protocol v3).

### Key Generation

```typescript
async function createNewIdentity(): Promise<DeviceIdentity> {
  const keyPair = await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify'])
  const pubRaw = await crypto.subtle.exportKey('raw', keyPair.publicKey)
  const privPkcs8 = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey)
  const deviceId = await sha256Hex(pubRaw)    // SHA-256 of raw public key
  // Store in localStorage
}
```

### Storage

| localStorage Key | Content |
|------------------|---------|
| `mc-device-id` | SHA-256 hex of raw public key |
| `mc-device-pubkey` | Base64url of raw public key |
| `mc-device-privkey` | Base64url of PKCS8 private key |
| `mc-device-token` | Cached token from gateway |

### Challenge-Response Flow

1. Client calls `getOrCreateDeviceIdentity()` — returns existing key or generates new one
2. During WebSocket connect, client signs a server nonce via `signPayload(privateKey, payload)`
3. Gateway verifies signature and returns a device token
4. Token is cached via `cacheDeviceToken()` for subsequent connections

### Fallback

If Ed25519 is unavailable (older browsers), the handshake proceeds in auth-token-only mode. The gateway accepts both authenticated modes.

### Usage in WebSocket

`src/lib/websocket.ts` imports the device identity module and uses it during the connect handshake:

```typescript
import { getOrCreateDeviceIdentity, signPayload, getCachedDeviceToken, cacheDeviceToken } from '@/lib/device-identity'
```

---

## 10. Audit Trail

### Database Schema

Created in migration `007_audit_log` (`src/lib/migrations.ts`):

```sql
CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action TEXT NOT NULL,
  actor TEXT NOT NULL,
  actor_id INTEGER,
  target_type TEXT,
  target_id INTEGER,
  detail TEXT,           -- JSON blob
  ip_address TEXT,
  user_agent TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_actor ON audit_log(actor);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
```

### `logAuditEvent()` Function

Located in `src/lib/db.ts`:

```typescript
export function logAuditEvent(event: {
  action: string
  actor: string
  actor_id?: number
  target_type?: string
  target_id?: number
  detail?: any
  ip_address?: string
  user_agent?: string
}) {
  db.prepare(`
    INSERT INTO audit_log (action, actor, actor_id, target_type, target_id, detail, ip_address, user_agent)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(...)

  // Broadcast security events via event bus
  const securityEvents = ['login_failed', 'user_created', 'user_deleted', 'password_change']
  if (securityEvents.includes(event.action)) {
    eventBus.broadcast('audit.security', { ... })
  }
}
```

### Logged Actions

| Action | When | Actor |
|--------|------|-------|
| `login` | Successful login | Username |
| `login_failed` | Failed login attempt | Attempted username |
| `login_google` | Successful Google login | Username |
| `google_login_pending_approval` | Google user without access | Email |
| `logout` | User logout | Username |
| `password_change` | Self-service password change | Username |
| `profile_update` | Display name change | Username |
| `user_create` | Admin creates user | Admin username |
| `user_update` | Admin updates user | Admin username |
| `user_delete` | Admin deletes user | Admin username |
| `access_request_approved` | Admin approves Google access | Admin username |
| `access_request_rejected` | Admin rejects Google access | Admin username |
| `tenant_bootstrap_requested` | Tenant provisioning request | Username |
| `tenant_bootstrap_completed` | Provisioning complete | Username |
| `tenant_bootstrap_failed` | Provisioning failed | Username |
| `tenant_decommission_requested` | Decommission request | Username |
| `provision_job_approved` | Job approval | Admin username |
| `provision_job_rejected` | Job rejection | Admin username |
| `provision_job_cancelled` | Job cancellation | Username |

### Audit API

`GET /api/audit` (`src/app/api/audit/route.ts`) — Admin only, with filtering:

```
GET /api/audit?action=login_failed&actor=admin&since=1709337600&until=1709424000&limit=100&offset=0
```

Returns paginated results with `total` count. Detail JSON is auto-parsed.

### Audit Trail Panel

The `AuditTrailPanel` (`src/components/panels/audit-trail-panel.tsx`) renders events with:
- Color-coded action labels (green for login, red for failures, amber for password changes)
- Icon indicators per action type
- IP address and user agent display
- Filterable by action type and actor

### Data Retention

The scheduler (`src/lib/scheduler.ts`) includes `audit_log` in data retention cleanup, configured via `retention.auditLog` setting (days).

---

## 11. Security Audit & Posture Scoring

The Dashboard (`src/components/dashboard/dashboard.tsx`) fetches aggregate audit stats:

```typescript
interface DbStats {
  audit: {
    day: number       // Events in last 24h
    week: number      // Events in last 7 days
    loginFailures: number  // Failed login count
  }
}
```

The system tracks:
- **Login failure count**: Surfaced on the dashboard as a security metric
- **Activity volume**: Day/week audit event counts for anomaly detection
- **Event bus broadcasting**: Security events (`login_failed`, `user_created`, `user_deleted`, `password_change`) are broadcast via `eventBus.broadcast('audit.security', ...)` for webhook delivery

---

## 12. Docker Security

### Dockerfile (`Dockerfile`)

Security-relevant practices:

1. **Non-root user**: Creates `nextjs` user (UID 1001) in `nodejs` group (GID 1001)
2. **Multi-stage build**: Only production artifacts in final image (no build tools, source code, or dev dependencies)
3. **Minimal base**: `node:20-slim` (not full)
4. **Data directory ownership**: `mkdir -p .data && chown nextjs:nodejs .data`
5. **Health check**: `curl -f http://localhost:${PORT}/login || exit 1`

### Docker Compose (`docker-compose.yml`)

Basic setup with:
- Named volume `mc-data` for SQLite persistence
- `restart: unless-stopped`
- Env file loading (optional)
- Port mapping via `MC_PORT` variable

The compose file does not currently include hardened-mode options like `read_only`, `cap_drop`, `security_opt: [no-new-privileges:true]`, or network isolation. These would be additions for a production deployment profile.

---

## 13. Workspace Isolation

Every major table has a `workspace_id` column (added via migrations `018_workspaces`, `019_workspaces_phase2`, `020_workspaces_phase3`):

### Tables with workspace_id

- `users`, `user_sessions`
- `tasks`, `agents`, `comments`, `activities`, `notifications`
- `quality_reviews`, `standup_reports`
- `messages`, `alert_rules`, `direct_connections`
- `github_syncs`, `workflow_pipelines`, `pipeline_runs`
- `workflow_templates`, `webhooks`, `webhook_deliveries`, `token_usage`

### Enforcement Pattern

All database queries filter on `workspace_id`:

```typescript
// src/lib/db.ts
db.prepare('SELECT ... FROM activities WHERE workspace_id = ? ...').all(workspaceId)
db.prepare('INSERT INTO activities (..., workspace_id) VALUES (..., ?)').run(workspaceId)
```

The workspace ID flows from authentication:

```
Request → getUserFromRequest() → user.workspace_id → passed to all DB functions
```

### Workspaces Table

```sql
CREATE TABLE workspaces (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  workspace_id INTEGER NOT NULL DEFAULT 1,
  -- ...
  UNIQUE(workspace_id, slug)
);
```

### Cross-Workspace Protection

- Users can only see data in their own workspace
- User management endpoints filter by `(existing.workspace_id ?? 1) !== workspaceId`
- The `getDefaultWorkspaceId()` function provides fallback to workspace ID 1

---

## 14. Two-Person Rule for Provisioning

The super-admin provisioning system (`src/lib/super-admin.ts`) enforces a two-person rule for live (non-dry-run) provisioning jobs:

```typescript
if (!dryRun) {
  if (approvedBy === requestedBy) {
    throw new Error('Two-person rule violation: live jobs require an approver different from the requester.')
  }
  if (approvedBy === actor) {
    throw new Error('Two-person rule violation: approver cannot be the execution runner for live jobs.')
  }
}
```

This requires three distinct actors for live provisioning: requester, approver, and executor.

---

## 15. Summary: Security Architecture for The Hive

### What to Replicate

1. **Session-based auth with scrypt hashing** — Battle-tested, no external auth service dependency
2. **Three-tier RBAC** — Simple but effective viewer/operator/admin hierarchy
3. **`requireRole()` pattern** — Clean discriminated union makes auth errors hard to miss
4. **Constant-time comparison** — Everywhere secrets are compared
5. **Rate limiting with critical tier** — Login limiter cannot be disabled even in test mode
6. **`sameSite: 'strict'` cookies + CSRF origin check** — Double-layer CSRF protection
7. **Comprehensive audit logging** — Every security-relevant action logged with IP, user agent
8. **Workspace isolation** — All queries scoped, prevents cross-tenant data leakage
9. **Ed25519 device identity** — Cryptographic device binding for WebSocket auth
10. **Agent API keys with scopes** — Per-agent auth with SHA-256 hashed storage

### What to Improve

1. **Hash session tokens** — Currently stored as plaintext; a DB leak exposes all sessions
2. **Per-request CSP nonces** — Replace `'unsafe-inline'` with nonce-based CSP
3. **Docker hardening** — Add `read_only`, `cap_drop: ALL`, `no-new-privileges`, network isolation to compose
4. **Consistent password policy** — Self-service change allows 8 chars, but creation requires 12
5. **Secret scanning** — Currently a dashboard metric but not an automated blocking gate
6. **Token rotation** — No session token rotation or sliding expiry (fixed 7-day TTL)
7. **Account lockout** — Rate limiting throttles but never locks accounts after repeated failures
