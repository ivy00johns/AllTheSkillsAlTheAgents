# 20 — Security Hardening

**Document type:** Security specification
**Status:** DRAFT
**Date:** 2026-03-20
**Scope:** Authentication, authorization, agent identity, skill security, infrastructure hardening
**Prerequisite reading:** `04-role-taxonomy.md` (agent castes, lifecycle), `08-skill-system.md` (skill model, Waggle), `18-api-layer.md` (auth model, RBAC, rate limiting)
**Source material:** Mission Control v1.3.0 (auth patterns, `requireRole()`, scrypt), Agent Identity research (EdDSA JWT, capability taxonomy, prompt injection defenses), SKILL.md Ecosystem Audit (ClawHavoc, Sigstore, Lethal Trifecta)

---

## 1. Security Model Overview

### Defense in Depth

The Hive secures four layers, each independent so that a breach at one layer does not cascade.

| Layer | Mechanism | What It Stops |
|-------|-----------|---------------|
| **Network** | Docker network isolation (5 networks, no Worker touches the data network) | Lateral movement between services |
| **Transport** | TLS termination at Fastify; internal traffic over isolated Docker networks | Eavesdropping, credential sniffing |
| **Application** | EdDSA JWT + RBAC + capability-scoped tokens + `requireRole()` guards | Unauthorized access, privilege escalation, confused deputy |
| **Data** | Encryption at rest (PostgreSQL `pgcrypto`, Valkey persistence encryption), scrypt for passwords, SHA-256 for stored keys | Credential theft from disk, database compromise |

### Threat Model

Three primary threats drive every design decision in this document:

**1. Runaway Agents.** A Worker whose LLM reasoning goes off track — spawning unauthorized work, exhausting budgets, or writing to files outside its Cell. Defense: capability-scoped JWTs, per-Worker Valkey ACLs, budget ceiling in JWT claims, circuit breaker (The Guard).

**2. Skill Supply Chain Attacks.** Malicious SKILL.md files entering The Waggle registry — demonstrated at scale by ClawHavoc (1,184 malicious packages, Feb 2026) and corroborated by Snyk's finding that 36% of public skills have security flaws. Defense: three-layer import pipeline (hash, scan, review gate), Sigstore provenance, static analysis for shell commands and prompt injection.

**3. Confused Deputy Attacks.** A Worker with legitimate credentials tricked via prompt injection into misusing those credentials — reading another Cell's data, exfiltrating secrets, or impersonating The Queen. Defense: capability-based access control (JWT carries only the permissions needed for the current Cell), structured data/instruction separation in prompts, HMAC-signed results, The Lethal Trifecta decomposition.

### Trust Boundaries

Six boundaries exist in The Hive. Every boundary requires authentication and authorization:

```
The Glass (browser) ──HTTPS──→ Hivemind API (Fastify)
The Queen ──JWT──→ Workers
Workers ──JWT──→ LiteLLM (LLM proxy)
Workers ──JWT──→ MCP Gateway ──OAuth──→ MCP Servers
The Queen ──JWT──→ The Keeper (approval system)
The Trail (audit) ──scram-sha-256──→ ClickHouse
```

No Worker ever crosses the data boundary directly. Workers interact with PostgreSQL and ClickHouse only through service APIs.

---

## 2. Agent Credential Lifecycle

### The Queen as Sole Certificate Authority

The Queen is the only entity that issues agent credentials. No Worker can create, extend, or modify its own identity token. This single-issuer model eliminates ambient authority — the root cause of the confused deputy problem.

### Signing Algorithm: EdDSA / Ed25519

| Property | Ed25519 | RSA-2048 (RS256) | Why Ed25519 Wins |
|----------|---------|-------------------|------------------|
| Signature size | 64 bytes | 256 bytes | 4x smaller JWTs |
| Signing speed | ~62x faster | Baseline | Workers spawn fast |
| Key size | 32 bytes | 256 bytes | Smaller secrets in memory |
| Deterministic | Yes | No (nonce-dependent) | Eliminates nonce-reuse vulnerabilities |
| Library | `jose` (zero-dependency ESM) | `jsonwebtoken` | `jose` supports EdDSA natively |

The Queen generates an Ed25519 keypair at startup using `jose.generateKeyPair('EdDSA')`. The private key is stored as a file-based secret (see Section 7). The public key is distributed to all services that verify Worker JWTs.

### JWT Claim Structure

Every Worker JWT contains these claims:

```json
{
  "alg": "EdDSA",
  "kid": "queen-primary-2026-03"
}
{
  "iss": "urn:hive:queen",
  "sub": "worker:coder-a7f3b2",
  "aud": "urn:hive:services",
  "exp": 1711000900,
  "iat": 1711000000,
  "nbf": 1711000000,
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "cell_id": "cell-proj-landing-page-42",
  "caste": "coder",
  "capabilities": [
    "read:cells:cell-proj-landing-page-42",
    "write:cells:cell-proj-landing-page-42",
    "call:litellm",
    "execute:code",
    "read:honey"
  ],
  "max_budget_cents": 500
}
```

| Claim | Type | Purpose |
|-------|------|---------|
| `iss` | string | Always `urn:hive:queen` — only the Queen issues tokens |
| `sub` | string | `worker:{workerId}` — unique per Worker instance |
| `aud` | string | `urn:hive:services` — all Hive services accept this audience |
| `exp` | number | Unix timestamp, 15 minutes from issuance (default TTL) |
| `iat` | number | Issuance time |
| `jti` | string | UUIDv4 — unique token ID for revocation tracking |
| `cell_id` | string | The Cell this Worker is assigned to — scopes all access |
| `caste` | string | Worker caste (coder, researcher, reviewer, planner) |
| `capabilities` | string[] | Explicit list of permitted operations |
| `max_budget_cents` | number | Maximum LLM spend for this Worker's lifetime |

### Seven-Step Spawn Sequence

When The Queen spawns a Worker:

1. **Create Cell record** — Insert into PostgreSQL `cells` table with `cell_id`, objective, assigned caste, capability budget.

2. **Generate JWT** — Sign an Ed25519 JWT with capabilities scoped to that Cell and caste. TTL: 15 minutes (refreshable).

3. **Create Valkey ACL user** — Per-Worker ACL restricted to the Worker's key prefix namespace:
   ```
   ACL SETUSER {workerId} on >{randomPassword}
     resetkeys ~cell:{cellId}:{workerId}:* ~cell:{cellId}:shared:*
     resetchannels &cell:{cellId}:*
     -@all +xadd +xread +xreadgroup +xack +xrange +xlen
     +get +set +setex +del +exists +expire +ping +auth
   ```

4. **Inject credentials** — Worker subprocess receives: `HIVE_WORKER_TOKEN` (JWT), `HIVE_WORKER_ID`, `HIVE_REDIS_USER`, `HIVE_REDIS_PASS`, `HIVE_CELL_ID`.

5. **Validate on startup** — Worker verifies JWT signature, expiry, issuer, audience, and required claims before processing any tasks. If validation fails, the Worker exits immediately.

6. **Use for all service calls** — Every HTTP request includes `Authorization: Bearer <token>`. Every Valkey operation uses the per-Worker ACL user.

7. **Revoke on completion** — The Queen adds the token's `jti` to the revocation blocklist in PostgreSQL, deletes the Valkey ACL user, and marks the Worker record as terminated.

### Per-Worker Valkey ACL Isolation

Each Worker's Valkey user can only access keys matching its own prefix:

```
cell:{cellId}:{workerId}:input      — Worker's task input stream
cell:{cellId}:{workerId}:output     — Worker's result output stream
cell:{cellId}:shared:broadcast      — Cell-wide broadcast (read access)
cell:{cellId}:shared:honey          — Shared knowledge store (read access)
```

A compromised Coder Worker in Cell-42 cannot read the Researcher Worker's output stream in the same Cell, and absolutely cannot access any data from Cell-43. The Queen's Valkey user has broader access across all Cells.

### Revocation

The revocation blocklist is a PostgreSQL table checked on every auth middleware call:

```sql
CREATE TABLE revoked_tokens (
  jti         UUID PRIMARY KEY,
  worker_id   TEXT NOT NULL,
  revoked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason      TEXT NOT NULL,
  revoked_by  TEXT NOT NULL
);

CREATE INDEX idx_revoked_tokens_jti ON revoked_tokens (jti);
```

Auth middleware checks revocation after JWT signature verification but before capability checks. The check uses a Valkey cache (`revoked:{jti}` keys with TTL matching token expiry) to avoid hitting PostgreSQL on every request. PostgreSQL is the source of truth; Valkey is the fast path.

### Key Rotation

The Queen rotates signing keys every 24 hours:

1. Generate new Ed25519 keypair with a new `kid` (e.g., `queen-primary-2026-03-21`).
2. Begin signing new tokens with the new key.
3. Old key remains valid for verification for 1 hour (overlap window).
4. After overlap, old public key is removed from service verification configs.
5. Workers spawned with old-key tokens that are still alive receive a refreshed token signed with the new key during their next token refresh cycle.

Services verify JWTs by looking up the `kid` header against a set of known public keys (current + previous during overlap).

### A2A Protocol: Explicitly Deferred

The Agent2Agent Protocol (Google, v1.0, 2026) solves cross-organization agent federation — agents from different vendors discovering and authenticating across trust boundaries. The Hive operates entirely within a single organization's Docker infrastructure. A2A adds HTTP discovery overhead, requires every Worker to expose an endpoint, and solves a trust problem that does not exist when all agents are spawned by the same Queen on the same network.

**Deferral trigger:** A2A implementation begins when The Hive needs to accept tasks from external agent fleets or delegate to third-party agents. Until then, JWT-based identity with capability scopes is sufficient.

---

## 3. Human Authentication

### Password Hashing: scrypt

All human passwords are hashed with scrypt before storage. Not bcrypt, not argon2 — scrypt was chosen for its memory-hardness (resistant to GPU/ASIC attacks) and its availability in Node.js `crypto` without native addon dependencies.

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| N (cost) | 16384 | ~100ms on modern hardware, GPU-resistant |
| r (block size) | 8 | Standard memory-hardness factor |
| p (parallelism) | 1 | Single-threaded — prevents timing side channels |
| Salt | 16 random bytes | Per-password, cryptographically random |
| Key length | 64 bytes | Stored as `{base64url(salt)}:{base64url(hash)}` |

Implementation: `crypto.scrypt()` with the parameters above, storing `{base64url(salt)}:{base64url(hash)}`. Verification uses `crypto.timingSafeEqual()` to prevent timing attacks.

### Session Tokens

Browser sessions for The Glass use HTTP-only cookies:

| Property | Value |
|----------|-------|
| Token | 32 cryptographically random bytes |
| Storage | SHA-256 hash in PostgreSQL `sessions` table |
| TTL | 7 days |
| Cookie name | `hive_session` |
| `httpOnly` | `true` |
| `secure` | `true` (production), `false` (dev) |
| `sameSite` | `strict` |
| `path` | `/` |

The raw token is sent to the browser once (in the `Set-Cookie` header on login). The server stores only the SHA-256 hash. On each request, the server hashes the cookie value and looks it up in the sessions table. This means a database leak does not expose usable session tokens.

```sql
CREATE TABLE sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  token_hash    BYTEA NOT NULL UNIQUE,
  role          TEXT NOT NULL CHECK (role IN ('viewer', 'operator', 'admin', 'fleet_admin')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at    TIMESTAMPTZ NOT NULL,
  last_used_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address    INET,
  user_agent    TEXT
);

CREATE INDEX idx_sessions_token_hash ON sessions (token_hash);
CREATE INDEX idx_sessions_expires ON sessions (expires_at);
```

### CSRF Protection

Two-layer CSRF defense:

1. **`sameSite: 'strict'`** — The browser never sends the session cookie on cross-origin requests. This alone blocks most CSRF attacks.

2. **Origin-vs-Host validation** — On every state-changing request (POST, PUT, PATCH, DELETE), the middleware compares the `Origin` header against the `Host` header. If they differ and the origin is not in the configured allowlist, the request is rejected with 403. Missing `Origin` on mutation requests is also rejected.

### Constant-Time Comparison

Every code path that compares secrets uses `crypto.timingSafeEqual()`:

- Password verification (scrypt output comparison)
- Session token lookup (hash comparison)
- API key validation (SHA-256 hash comparison)
- HMAC result verification (Worker output signatures)
- Webhook signature verification

Timing attacks are subtle and difficult to detect. Using constant-time comparison everywhere secrets are compared eliminates the entire attack class.

---

## 4. RBAC Enforcement

### Four-Tier Role Hierarchy

Roles are integer-backed, enabling `>=` comparison. Each role inherits all permissions of lower roles.

| Role | Level | Permissions |
|------|-------|-------------|
| `viewer` | 0 | Read all state in The Glass. View The Yard View, The Trail, The Yield. No mutations. |
| `operator` | 1 | Start/pause/resume/cancel builds. Approve/reject Inspections (The Keeper). Dispatch Workers. Create Cells. |
| `admin` | 2 | Manage API keys. Configure The Waggle. Kill Workers. Manage workspace settings. |
| `fleet_admin` | 3 | Manage users and roles. Rotate signing keys. Access full audit log. Federation configuration. Emergency operations. |

### The `requireRole()` Guard

Proven at production scale by Mission Control (83 routes, zero auth bypass bugs). The discriminated union pattern means TypeScript narrows the type after the guard — `auth.role` is guaranteed valid, eliminating `undefined` access. Returns `{ ok: true; auth: AuthContext }` on success, `{ ok: false; error: string; status: 401 | 403 }` on failure. Extracts auth from cookie, agent key header, or system key header, then checks `ROLE_LEVELS[auth.role] >= ROLE_LEVELS[minimumRole]`.

### Principal-Specific Role Storage

| Principal | Where Role Lives | Why |
|-----------|-----------------|-----|
| Browser user | PostgreSQL `sessions` table (copied from `users.role` at login) | Session is the auth context for The Glass |
| Agent (Worker) | JWT `caste` claim, mapped to `operator` | Workers perform mutations within their Cell scope |
| System API key | PostgreSQL `system_keys` table | CI/CD keys have a fixed role (typically `admin`) |

Workers do not participate in the RBAC hierarchy for human-facing operations. A Worker JWT with `caste: "coder"` grants `operator`-level access to Cell-scoped endpoints only. Workers cannot access user management, key rotation, or audit log endpoints regardless of their caste.

### Capability vs. Role: When Each Applies

- **Role** guards human-facing endpoints (The Glass, The Smoker CLI, API keys). Checked via `requireRole()`.
- **Capabilities** guard Worker-to-service operations (Cell reads/writes, LLM calls, code execution). Checked via `requireCapability()` against the JWT `capabilities[]` array.

Both are checked on every request. A Worker must pass JWT signature verification, revocation check, role check, and capability check before any handler executes.

---

## 5. SKILL.md Supply Chain Security

### The Threat

ClawHavoc (February 2026): 7 attacker accounts uploaded 386 malicious SKILL.md files to ClawHub. Follow-up analysis found 1,184 malicious skills total — one in five packages. The payload was Atomic macOS Stealer (AMOS), distributed through "Prerequisites" sections that directed agents to execute base64-encoded scripts. No parser vulnerability was exploited — the attack was pure social engineering embedded in documentation.

Snyk's ToxicSkills study: 36% of public skills have security flaws. 26.1% contain at least one vulnerability across 14 patterns. 91% of confirmed malicious skills combine prompt injection with malicious code patterns. Skills bundling executable scripts are 2.12x more likely to contain vulnerabilities.

CVE-2025-6514 (CVSS 9.6): `mcp-remote` versions 0.0.5 through 0.1.15 enable OS command injection when connecting to untrusted MCP servers. 558,000+ downloads at disclosure. **Pin `mcp-remote` >= 0.1.16.**

### Three-Layer Import Pipeline

Every skill entering The Waggle passes through three layers. The default posture is **deny**.

**Layer 1 — Source Verification**

External skills require Sigstore cryptographic provenance:
- **Cosign** signs the skill content hash
- **Fulcio** issues short-lived certificates via OIDC (linking to the publisher's identity)
- **Rekor** records the signing event in an immutable transparency log

First-party skills (from The Hive's own repository) bypass Sigstore but still pass through Layers 2 and 3.

**Layer 2 — Static Analysis**

A multi-phase scanner inspects every skill before admission:

| Pattern | Detection Method | Severity |
|---------|-----------------|----------|
| Shell commands in body | Regex: `` `[^`]*\b(curl\|wget\|bash\|sh\|exec\|eval)\b `` | CRITICAL |
| External URL fetches | Regex: `https?://` not in allowlist | HIGH |
| Base64-encoded payloads | Regex: `[A-Za-z0-9+/]{40,}={0,2}` | CRITICAL |
| Prompt injection patterns | "Ignore previous instructions", "You are now", "IMPORTANT:" overrides | HIGH |
| Unicode Tag codepoints | U+E0000–U+E007F (invisible to humans, interpreted by models) | CRITICAL |
| Password-protected archives | `.zip`, `.rar`, `.7z` references with password instructions | CRITICAL |
| Environment variable access | `process.env`, `$ENV`, `os.environ` | HIGH |
| Excessive tool requests | `allowed-tools` list > 10 tools | MEDIUM |

Skills flagged at CRITICAL are rejected outright. Skills flagged at HIGH require mandatory human review.

**Layer 3 — Review Gate**

- Skills passing automated scans with no flags: enter a human reviewer queue. One approval required.
- Skills flagged by any scanner: mandatory human approval. Two approvals required.
- First-party skills passing automated scans: auto-approved (but scan results logged for audit).

### The Lethal Trifecta Defense

No single Worker simultaneously holds all three of:

1. **Access to sensitive data** (credentials, API keys, user data)
2. **Exposure to untrusted skill content** (imported skills, external tool responses)
3. **Unrestricted external communication** (network egress, MCP calls to external services)

Task decomposition enforces this structurally. A Worker processing an imported skill for review has no network egress. A Worker with access to production credentials does not process untrusted content. This is a security control, not just an orchestration pattern.

### Session-Boundary Migration

Running Workers keep their current skill version until Cell completion. When The Waggle receives an updated skill version:

1. New version is scanned and approved through the pipeline.
2. New version is marked as `active` in the `skill_versions` table.
3. Already-running Workers continue using their pinned version (recorded at spawn time).
4. New Workers spawned after activation receive the new version.
5. **Exception:** Critical security patches trigger immediate Worker recycling — The Queen terminates affected Workers and respawns them with the patched skill version.

### Waggle Persistence Schema

```sql
CREATE TABLE waggle_skills (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL UNIQUE,
  description     TEXT NOT NULL,
  source          TEXT NOT NULL CHECK (source IN ('first_party', 'external')),
  publisher       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE skill_versions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id        UUID NOT NULL REFERENCES waggle_skills(id),
  version         TEXT NOT NULL,
  content_hash    TEXT NOT NULL,
  signature       TEXT,
  sigstore_bundle JSONB,
  scan_status     TEXT NOT NULL CHECK (scan_status IN ('pending', 'passed', 'flagged', 'rejected')),
  reviewed_by     UUID REFERENCES users(id),
  review_note     TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activated_at    TIMESTAMPTZ,
  UNIQUE (skill_id, version)
);

CREATE TABLE security_scans (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_version_id  UUID NOT NULL REFERENCES skill_versions(id),
  scanner           TEXT NOT NULL,
  findings          JSONB NOT NULL DEFAULT '[]',
  max_severity      TEXT CHECK (max_severity IN ('NONE', 'MEDIUM', 'HIGH', 'CRITICAL')),
  passed            BOOLEAN NOT NULL,
  scanned_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 6. API Security

### Rate Limiting

Four-tier rate limiting enforced per principal via Valkey sliding window counters (from doc 18):

| Tier | Budget | Window | Applies To | Always On |
|------|--------|--------|-----------|-----------|
| `login` | 5 req | 1 min | `POST /api/auth/login` | Yes |
| `mutation` | 60 req | 1 min | POST/PUT/PATCH/DELETE | No (dev bypass) |
| `heavy` | 10 req | 1 min | Full state queries, metrics aggregation | No (dev bypass) |
| `read` | 120 req | 1 min | GET endpoints | No (dev bypass) |

Workers during active builds are exempt from the `read` tier (they query state frequently during coordination). System API keys can be granted elevated limits.

Every response includes: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`. Exceeded budgets return HTTP 429 with `Retry-After`.

### API Key Security

Agent and system API keys:

- **Generation:** 32 cryptographically random bytes, displayed once at creation, never recoverable.
- **Storage:** SHA-256 hash in PostgreSQL. The raw key is never stored.
- **Lookup:** On each request, hash the presented key and match against stored hashes.
- **Logging:** API keys are never logged, never included in error responses, never returned by any endpoint. Log the key's `id` and `label` instead.
- **Scoping:** Each key record tracks `workspace_id`, `role`, `label`, `created_by`, `last_used_at`, `expires_at`.

```sql
CREATE TABLE api_keys (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_hash      BYTEA NOT NULL UNIQUE,
  key_prefix    TEXT NOT NULL,
  principal     TEXT NOT NULL CHECK (principal IN ('agent', 'system')),
  workspace_id  UUID NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('viewer', 'operator', 'admin', 'fleet_admin')),
  label         TEXT NOT NULL,
  agent_id      TEXT,
  scopes        TEXT[],
  created_by    UUID NOT NULL REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at  TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,
  revoked_at    TIMESTAMPTZ
);
```

The `key_prefix` stores the first 8 characters of the key for identification in logs and UI (e.g., `hive_ak_a3f8...`).

### Request Validation

All request bodies are validated against TypeBox schemas before reaching handlers. Invalid payloads return 400 with a structured error envelope — never a stack trace or internal state.

TypeBox schemas enforce type, format, length, and pattern constraints. See doc 18, Section 4 for endpoint-specific schemas.

### Security Headers

Every response from the Fastify server includes:

```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'
Strict-Transport-Security: max-age=63072000; includeSubDomains
X-DNS-Prefetch-Control: off
X-Permitted-Cross-Domain-Policies: none
```

CSP is tightened for The Glass dashboard. API-only responses (`/api/*`) omit the `style-src` and `img-src` directives.

### Host Allowlist

In production, the Fastify server validates the `Host` header against a configured allowlist (`HIVE_ALLOWED_HOSTS` env var, comma-separated). Requests with unknown `Host` values are rejected with 421 Misdirected Request. This prevents DNS rebinding attacks and host header injection.

---

## 7. Infrastructure Security

### Docker Network Isolation

Five isolated Docker networks map to the five architecture layers. No container sits on all networks.

```yaml
networks:
  frontend:        # The Glass UI <-> Hivemind API only
  orchestration:   # The Queen <-> Workers <-> Hivemind
  data:            # The Queen <-> PostgreSQL, The Trail <-> ClickHouse
  llm:             # Workers <-> LiteLLM
  eventbus:        # The Queen <-> Valkey <-> Workers
```

| Service | Networks | Rationale |
|---------|----------|-----------|
| The Glass (Nginx/static) | `frontend` | Browser-facing only |
| Hivemind (Fastify API) | `frontend`, `orchestration`, `data`, `eventbus` | Central hub |
| The Queen | `orchestration`, `data`, `eventbus` | Spawns Workers, writes to The Comb |
| Workers | `orchestration`, `llm`, `eventbus` | No data network access, no frontend access |
| LiteLLM | `llm` | Workers only |
| PostgreSQL | `data` | Queen and Hivemind only |
| Valkey | `eventbus` | Queen and Workers |
| ClickHouse | `data` | The Trail and Hivemind only |
| MCP Gateway | `orchestration`, `llm` | Mediates Worker-to-MCP traffic |

Workers cannot reach PostgreSQL or ClickHouse directly. If a Worker is compromised via prompt injection, the network topology prevents it from querying or modifying persistent data stores.

### File-Based Secrets

Production deployments use file-based secrets via the `_FILE` convention. Environment variables never contain secrets in production.

```yaml
# docker-compose.prod.yml
services:
  hivemind:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/pg_password
      QUEEN_SIGNING_KEY_FILE: /run/secrets/queen_ed25519_private
      VALKEY_PASSWORD_FILE: /run/secrets/valkey_password
    secrets:
      - pg_password
      - queen_ed25519_private
      - valkey_password

secrets:
  pg_password:
    file: ./secrets/pg_password.txt
  queen_ed25519_private:
    file: ./secrets/queen_ed25519_private.pem
  valkey_password:
    file: ./secrets/valkey_password.txt
```

At startup, a `loadSecret(envKey)` function checks for `{envKey}_FILE` first, reads the file, and falls back to the direct env var only in development. In production, direct env var usage logs a warning. Missing secrets throw immediately — fail fast, not fail silent.

### PostgreSQL Hardening

| Setting | Value | Why |
|---------|-------|-----|
| Authentication | `scram-sha-256` | Never `trust`, not even in development |
| `pg_hba.conf` | `host all all 0.0.0.0/0 scram-sha-256` | No password-less connections |
| Connection encryption | `ssl = on` in production | Encrypts data in transit within Docker networks |
| Application users | Separate users per service (hivemind, queen, trail) | Principle of least privilege |
| Default user | Disabled (`REVOKE ALL ON SCHEMA public FROM PUBLIC`) | No ambient access |

### Valkey Hardening

| Setting | Value | Why |
|---------|-------|-----|
| Authentication | ACL-based (per-Worker users) | No default user in production |
| Default user | `ACL SETUSER default off` | Disable the unauthenticated default user |
| `protected-mode` | `yes` | Reject connections from non-localhost without auth |
| `maxmemory-policy` | `noeviction` | Prevent silent data loss under memory pressure |
| TLS | Optional (within Docker network, cleartext acceptable) | Network isolation provides equivalent boundary |
| Persistence encryption | `aof-use-rdb-preamble yes` with encrypted volume | Protects data at rest |

Per-Worker Valkey ACLs are created at spawn time and deleted at Cell completion (Step 3 and Step 7 of the spawn sequence).

### ClickHouse Hardening

| Setting | Value | Why |
|---------|-------|-----|
| Write user | `trail_writer` — INSERT only on event tables | The Trail is the only write path |
| Read user | `glass_reader` — SELECT only on materialized views | The Glass dashboard queries aggregated data |
| No Worker access | Workers are not on the `data` network | Architectural enforcement, not just config |
| `readonly = 1` | Set on `glass_reader` profile | Defense in depth for read-only access |

---

## 8. Audit Trail

### What Gets Logged

Every security-relevant event is written to an append-only PostgreSQL table. ClickHouse receives a copy for analytics and long-term querying.

#### Authentication Events

| Event | Fields |
|-------|--------|
| `auth.login` | user_id, ip, user_agent, success (boolean), failure_reason |
| `auth.logout` | user_id, session_id |
| `auth.key_created` | key_id, principal, role, created_by |
| `auth.key_revoked` | key_id, revoked_by, reason |
| `auth.role_changed` | user_id, old_role, new_role, changed_by |
| `auth.failed_attempt` | principal_type, identifier, ip, reason |

#### Worker Lifecycle Events

| Event | Fields |
|-------|--------|
| `worker.spawned` | worker_id, cell_id, caste, jti, capabilities |
| `worker.terminated` | worker_id, cell_id, reason, duration_ms, tokens_used |
| `worker.budget_exceeded` | worker_id, cell_id, max_budget_cents, actual_spend_cents |
| `worker.token_refreshed` | worker_id, old_jti, new_jti |
| `worker.token_revoked` | worker_id, jti, revoked_by, reason |
| `worker.circuit_breaker` | worker_id, cell_id, trigger_reason, action_taken |

#### Approval Events (The Keeper)

| Event | Fields |
|-------|--------|
| `keeper.approval_requested` | approval_id, build_id, agent_id, gate_name, cell_id |
| `keeper.decision` | approval_id, decision (approved/rejected), user_id, ip, user_agent, comment |

#### Skill Events (The Waggle)

| Event | Fields |
|-------|--------|
| `waggle.skill_imported` | skill_id, name, source, content_hash |
| `waggle.scan_completed` | skill_version_id, scanner, passed, max_severity, findings_count |
| `waggle.skill_approved` | skill_version_id, reviewed_by, review_note |
| `waggle.skill_rejected` | skill_version_id, reviewed_by, reason |
| `waggle.skill_disabled` | skill_id, disabled_by, reason |

### Audit Table Schema

```sql
CREATE TABLE audit_log (
  id          BIGSERIAL PRIMARY KEY,
  event_type  TEXT NOT NULL,
  actor_type  TEXT NOT NULL CHECK (actor_type IN ('user', 'worker', 'system', 'queen')),
  actor_id    TEXT NOT NULL,
  target_type TEXT,
  target_id   TEXT,
  metadata    JSONB NOT NULL DEFAULT '{}',
  ip_address  INET,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutability: no UPDATE or DELETE
REVOKE UPDATE, DELETE ON audit_log FROM hivemind_user;
REVOKE UPDATE, DELETE ON audit_log FROM queen_user;

-- Append-only enforced at the database level
CREATE RULE no_update_audit AS ON UPDATE TO audit_log DO INSTEAD NOTHING;
CREATE RULE no_delete_audit AS ON DELETE TO audit_log DO INSTEAD NOTHING;

-- Query indexes
CREATE INDEX idx_audit_event_type ON audit_log (event_type);
CREATE INDEX idx_audit_actor ON audit_log (actor_type, actor_id);
CREATE INDEX idx_audit_target ON audit_log (target_type, target_id);
CREATE INDEX idx_audit_created ON audit_log (created_at);
```

### Retention

| Data Category | Retention | Rationale |
|---------------|-----------|-----------|
| Security events (auth, role changes, key operations) | 365 days | Compliance, incident investigation |
| Worker lifecycle events | 90 days | Operational debugging |
| Approval decisions | 365 days | Accountability |
| Skill scan results | 365 days | Supply chain audit |
| General operational events | 30 days (configurable) | Cost control |

ClickHouse tables use TTL-based automatic expiration (`TTL created_at + INTERVAL {days} DAY`), partitioned by `toYYYYMM(created_at)`, ordered by `(event_type, created_at)`. Uses `LowCardinality(String)` for event_type and actor_type columns for compression.

---

## 9. Incident Response

### Runaway Worker

**Trigger:** Circuit breaker (The Guard) detects: budget exceeded, repeated errors, or anomalous behavior (writing to unexpected streams, making requests outside capability scope).

**Response sequence:**

1. The Guard fires `worker.circuit_breaker` event to The Airway.
2. The Queen sends SIGTERM to the Worker process (10-second grace period).
3. If the Worker does not exit, SIGKILL.
4. The Queen adds the Worker's `jti` to the revocation blocklist.
5. The Queen deletes the Worker's Valkey ACL user.
6. The Cell is marked `abandoned` in PostgreSQL.
7. The audit log records the full sequence with trigger reason.
8. If `reassignCell: true`, The Queen spawns a replacement Worker for the Cell.

**Blast radius containment:** Because the Worker's JWT was scoped to a single Cell and its Valkey ACL restricted to its own key prefixes, the damage is confined to that Cell's data. Other Cells and Workers are unaffected.

### Compromised Skill

**Trigger:** Security scan flag on an already-active skill, external CVE report, or behavioral anomaly detected during Worker execution.

**Response sequence:**

1. Mark the skill as `disabled` in The Waggle (`waggle.skill_disabled` event).
2. Query all running Workers that were spawned with the compromised skill version.
3. For each affected Worker:
   a. Send a termination signal (SIGTERM).
   b. Revoke the Worker's JWT.
   c. Delete the Worker's Valkey ACL user.
   d. Mark the Worker's Cell as `needs_review`.
4. Run the static analysis scanner against all outputs produced by affected Workers (check for exfiltrated data, injected code, unauthorized file modifications).
5. If indicators of compromise (IOCs) are found, escalate: notify `fleet_admin` via The Glass alert (A Sting), log detailed findings.
6. Respawn affected Cells with clean Workers using a different skill version (or no skill if no safe version exists).

### Key Compromise

**Trigger:** Suspected or confirmed exposure of The Queen's Ed25519 signing key.

**Response sequence (emergency rotation):**

1. Generate a new Ed25519 keypair immediately.
2. Update the signing key in The Queen's secret store.
3. Add ALL active JTIs to the revocation blocklist (mass revocation).
4. Delete ALL Worker Valkey ACL users.
5. Re-spawn healthy Workers with new JWTs signed by the new key.
6. The old public key is removed from all service verification configs (no overlap window during emergency).
7. Audit: log the compromised key's `kid`, the number of revoked tokens, and the re-spawn results.

**Recovery time target:** All Workers re-credentialed within 60 seconds of key compromise detection.

### Two-Person Rule

Destructive infrastructure operations require two `fleet_admin` principals to authorize:

| Operation | Required Approvals |
|-----------|-------------------|
| Emergency key rotation | 2 fleet_admin |
| Mass Worker termination (>10 Workers) | 2 fleet_admin |
| Audit log export or archival | 2 fleet_admin |
| Federation configuration changes | 2 fleet_admin |
| Production database access (direct SQL) | 2 fleet_admin |
| User role escalation to fleet_admin | 2 fleet_admin (existing) |

Implementation: the first `fleet_admin` initiates the operation, creating a pending approval record. The second `fleet_admin` confirms via a separate authenticated session. Both actors, their IPs, timestamps, and the operation details are recorded in the audit log.

### Admin Seeding

On first deployment, The Hive creates a default `fleet_admin` account:

```typescript
const DEFAULT_ADMIN = {
  email: 'admin@thehive.local',
  password: crypto.randomBytes(24).toString('base64url'),  // random, printed to stdout once
  role: 'fleet_admin',
};
```

The default password is printed to the console during first boot and never stored. The admin is required to change it on first login. If the default password has not been changed after 24 hours, the system logs a `security.insecure_default` warning every hour until it is changed.

---

## 10. Security Implementation Checklist

### Phase 0 (Foundation) — Week 1-2

- [ ] Ed25519 keypair generation and storage
- [ ] JWT issuance in Worker spawn sequence
- [ ] JWT verification middleware on all Fastify routes
- [ ] `requireRole()` discriminated union guard
- [ ] `requireCapability()` middleware for Worker routes
- [ ] scrypt password hashing for human accounts
- [ ] Session token creation and validation
- [ ] CSRF protection (sameSite + origin check)
- [ ] Security headers on all responses
- [ ] Audit log table with immutability constraints
- [ ] Admin seeding with insecure-default detection

### Phase 1 (Hardening) — Week 3-4

- [ ] Per-Worker Valkey ACL creation/deletion in spawn sequence
- [ ] Revocation blocklist (PostgreSQL + Valkey cache)
- [ ] 24-hour key rotation with 1-hour overlap
- [ ] Token refresh for long-running Workers
- [ ] Rate limiting (4-tier, Valkey-backed)
- [ ] API key management (SHA-256 hashed storage)
- [ ] Host allowlist enforcement
- [ ] Docker network isolation (5 networks)
- [ ] File-based secrets (`_FILE` convention)

### Phase 2 (Supply Chain) — Week 5-6

- [ ] Waggle static analysis scanner (8 pattern categories)
- [ ] Sigstore integration (Cosign, Fulcio, Rekor)
- [ ] Skill review gate workflow
- [ ] Session-boundary migration for skill updates
- [ ] MCP credential isolation proxy
- [ ] Lethal Trifecta enforcement in task decomposition
- [ ] HMAC result signing for Worker outputs

### Phase 3 (Operations) — Week 7-8

- [ ] Incident response runbooks (runaway, compromise, key rotation)
- [ ] Two-person rule for destructive operations
- [ ] ClickHouse audit replication
- [ ] Retention policy automation (TTL enforcement)
- [ ] Security event alerting (Stings for failed auth spikes, budget overruns)
- [ ] Emergency key rotation tested end-to-end
- [ ] `mcp-remote` version pinning verification (>= 0.1.16)

---

*This document consolidates security specifications previously scattered across docs 03, 04, 05, 08, 09, and 13. It is the authoritative source for all security decisions in The Hive.*
