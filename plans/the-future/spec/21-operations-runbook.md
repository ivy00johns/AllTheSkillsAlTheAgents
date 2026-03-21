# 21 — Operations Runbook

**Document type:** Operational procedures
**Status:** DRAFT
**Date:** 2026-03-20
**Scope:** Day-to-day operations, maintenance, troubleshooting, and incident response
**Prerequisite reading:** 03-system-architecture, 13-observability, 16-build-program

---

## 1. First Startup Sequence

Bringing The Hive up for the first time. Every step must succeed before proceeding.

### 1.1 Prerequisites

| Requirement | Minimum Version | Check Command |
|-------------|----------------|---------------|
| Docker + Docker Compose | 24.0+ / 2.20+ | `docker --version && docker compose version` |
| Node.js | 22.0+ | `node --version` |
| pnpm | 9.0+ | `pnpm --version` |
| git | 2.40+ | `git --version` |

### 1.2 Start Infrastructure

```bash
git clone https://github.com/your-org/the-hive.git ~/AI/The-Hive
cd ~/AI/The-Hive
cp .env.example .env
docker compose -f infra/compose.local.yml up -d
```

Expected containers: `hive-postgres` (:5432), `hive-valkey` (:6379), `hive-dolt` (:3306), `hive-clickhouse` (:8123/:9000). Wait for all to report healthy via `docker compose -f infra/compose.local.yml ps`.

### 1.3 Build and Verify

```bash
pnpm install && pnpm build
platform doctor            # verify all backing services
platform db migrate        # apply schema migrations (idempotent)
platform serve             # start The Glass + API (default port 3000)
platform config show       # verify configuration
```

Expected `platform doctor` output on fresh install:

```
[PASS] postgres    — connection OK, schema v0 (migrations pending)
[PASS] valkey      — connection OK, ACL configured
[PASS] dolt        — server running, 0 databases
[PASS] clickhouse  — connection OK, schema v0 (migrations pending)
[WARN] workers     — no active sessions (expected on first start)
```

### 1.4 Health Check Endpoints

| Endpoint | Response | Meaning |
|----------|---------|---------|
| `GET /health` | `200 { "status": "ok" }` | API server running |
| `GET /health/deep` | `200 { "postgres": "ok", ... }` | All backing services reachable |

---

## 2. Daily Operations

### 2.1 Fleet Health

```bash
platform fleet status
```

Or use The Yard View in The Glass for visual monitoring.

| Metric | Healthy | Investigate |
|--------|---------|-------------|
| Active Workers | Matches workload | Stuck at 0 with pending Cells — check The Queen |
| Capped Workers (idle) | < 50% of fleet | > 50% idle — reduce fleet or check dispatch |
| Worker uptime | < 4 hours | Long sessions have stale context |
| Heartbeat age | < 2 minutes | Stale heartbeat — Worker may be stuck or dead |

### 2.2 Cost Monitoring

```bash
platform cost summary                 # current period
platform cost breakdown --by worker   # per-Worker
platform cost breakdown --by model    # per-model
```

Or use The Yield view in The Glass. Red flags: single Worker > $5/hour (retry loop?), Opus usage > 20% of calls (routing broken?), daily spend > 2x the 7-day average.

### 2.3 Patrol Agent Backoff

Patrol agents use exponential backoff when idle: **30s** (active) → **60s** (1 idle cycle) → **2m** (2+ idle cycles). Resets to 30s when work is found. If patrols miss work, verify they are active (`platform fleet status`), work exists (`platform work ready`), and Caste requirements match.

### 2.4 Merge Queue

```bash
platform merge status
```

| Metric | Healthy | Warning |
|--------|---------|---------|
| Queue depth | < 20 | > 30 — Workers outpacing merge |
| Oldest item | < 30 min | > 1 hour — likely stuck |
| Tier 4 (AI reimagine) rate | < 5% | > 10% — contracts too loose |

### 2.5 The Airway (Valkey Streams)

```bash
valkey-cli XLEN hive:events
valkey-cli XINFO GROUPS hive:events
```

Stream length < 50K is healthy. Consumer lag > 10,000 entries means a consumer is falling behind — check for crashed consumers, slow downstream writes, or event volume spikes.

### 2.6 PostgreSQL and Dolt

```bash
platform doctor --category postgres --verbose
platform doctor --category dolt --verbose
```

**PostgreSQL:** Active connections < 80% of pool, query p95 < 100ms, dead tuples < 10%.
**Dolt:** Commit frequency 1-10/min during active builds, branch count < 50, connections < max_connections (100+).

---

## 3. Known Dolt Limitations and Workarounds

Production-discovered issues from the Beads platform. Documented to prevent reintroduction.

### 3.1 mergeJoinIter Panic

Dolt server panics on certain complex JOIN queries. **Workaround:** use `LEFT JOIN` instead of `JOIN` in queries with compound keys across multiple tables. The LEFT JOIN code path avoids the panic. Open Dolt issue — monitor for upstream fix.

### 3.2 GH#2455 — DOLT_COMMIT Staging Sweep Bug

The `-Am` flag in `DOLT_COMMIT` has a staging sweep bug that silently loses data. **Rule:** NEVER use `DOLT_COMMIT('-Am', ...)`. Always stage explicitly:

```sql
CALL DOLT_ADD('work_items');
CALL DOLT_ADD('dependencies');
CALL DOLT_COMMIT('-m', 'Update work items and dependencies');
```

Enforce with a lint rule that flags any `DOLT_COMMIT` call containing `-A`.

### 3.3 Wisp Data Loss — Transaction Ordering

Calling `DOLT_COMMIT()` before the SQL transaction's `COMMIT` can lose data. The Dolt version-control commit races with the uncommitted SQL transaction. **Rule:** always `COMMIT` the SQL transaction BEFORE calling `DOLT_COMMIT()`:

```sql
BEGIN;
INSERT INTO work_items (...) VALUES (...);
COMMIT;                                          -- SQL first
CALL DOLT_ADD('work_items');
CALL DOLT_COMMIT('-m', 'Create wisps');          -- Dolt second
```

### 3.4 Production Sizing

| Parameter | Minimum | Recommended |
|-----------|---------|-------------|
| `max_connections` | 100 | 150 |
| Databases per server | 5 max | 3 or fewer |
| Memory | 2 GB | 4 GB |

More than 5 databases on a single Dolt server causes noticeable latency degradation.

### 3.5 Shadow Database Prevention

Dolt can auto-start a server on client connect, creating "shadow databases" that consume ports and memory. Three safeguards: auto-start disabled in test mode (`NODE_ENV=test`), disabled when an explicit port is configured, and disabled when another server is detected on the target port. If unexpected Dolt processes appear (`ps aux | grep dolt`), kill them and set an explicit port in `config.yaml`.

---

## 4. Data Retention and Compaction

### 4.1 Default Retention

| Data Category | Default | Config Key |
|---------------|---------|------------|
| Activities | 90 days | `retention.activities_days` |
| Audit log | 365 days | `retention.audit_days` |
| Operational logs | 30 days | `retention.logs_days` |
| Notifications (Signals) | 60 days | `retention.notifications_days` |
| Token usage | 90 days | `retention.token_usage_days` |

Setting any value to `0` disables cleanup (keep forever) for compliance scenarios.

### 4.2 Running Cleanup

```bash
platform cleanup --dry-run    # preview (row counts + estimated disk reclamation)
platform cleanup              # execute
```

Always `--dry-run` first, especially after changing retention settings.

### 4.3 Dolt Compaction

| Tier | Trigger | Action |
|------|---------|--------|
| 0 | Continuous | Normal — every Cell change is a Dolt commit |
| 1 | Items > 30 days old | Archived — metadata retained, history squashed |
| 2 | Items > 90 days old | Flattened — single snapshot, intermediates removed |

```bash
platform compact --dry-run && platform compact
```

Only completed Cells are compacted. In-progress work is never touched.

### 4.4 ClickHouse Retention

TTL-based retention configured per table in `config.yaml` under `clickhouse.ttl`. Default: 90 days for traces, 365 days for aggregated metrics.

### 4.5 Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Data cleanup | Weekly | `platform cleanup` |
| Dolt compaction | Weekly | `platform compact` |
| Worktree cleanup | Daily | `platform worktree clean` |
| Backup verification | Monthly | `platform backup verify` |

PostgreSQL VACUUM runs automatically. Valkey stream trimming is configured via `config.yaml` MAXLEN.

---

## 5. Cost Management

### 5.1 LiteLLM Proxy as Mandatory Gateway

All LLM calls route through LiteLLM. No Worker communicates directly with a provider. This enables budget enforcement, model routing, caching, and spend attribution.

### 5.2 Budget Hierarchy

Five levels, each enforced independently:

| Level | Scope | Enforcement |
|-------|-------|------------|
| Organization | Total monthly spend | Hard cap — all Workers stop |
| Team | Per-team allocation | Soft then hard cap |
| API Key | Per-key limit | Hard cap via LiteLLM `max_budget` |
| User | Per-operator limit | Soft cap with Signals |
| End User | Per-end-user limit | Configurable |

### 5.3 Pre-Dispatch Estimation

Before spawning a Worker, The Queen: (1) looks up the Cell's complexity, (2) maps to historical token usage for that Caste, (3) checks remaining budget at all five levels. If projected cost exceeds any hard cap, the Cell is deferred with `budget_exhausted`.

### 5.4 Per-Worker Virtual API Keys

Each Worker gets a virtual API key with a hard `max_budget`. When exceeded, LiteLLM returns HTTP 400 and the Worker terminates gracefully. View keys: `platform cost keys --active`. Revoke: `platform cost key revoke <key-id>`.

### 5.5 Model Routing

| Task Type | Target Tier | Examples |
|-----------|------------|---------|
| Documentation, tests, boilerplate | Haiku-class | JSDoc, unit tests, READMEs |
| Standard implementation | Sonnet-class | Feature code, bug fixes |
| Complex architecture | Opus-class | Cross-module redesigns |

Configured in `config.yaml` under `litellm.routing`. The Queen includes a `task_tier` header on dispatch.

### 5.6 Prompt Caching

At scale, 90%+ of agentic tokens are cache reads at 10% of input price. Cache creation costs 125% but amortizes when Workers share Caste contexts. Maximize by: placing skill preambles first in context (identical across same-Caste Workers), keeping system prompts stable, loading large references once per Caste.

### 5.7 Alerting Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| `RunawayWorkerSpend` | Worker > $5/hr for 15 min | Warning |
| `RunawayWorkerSpend` | Worker > $10/hr for 10 min | Critical |
| `TeamBudgetCritical` | Team > 90% of monthly budget | Warning |
| `WorkerRequestSpike` | Worker > 60 LLM requests/min | Warning |
| `OrgBudgetWarning` | Organization > 80% of monthly budget | Warning |

### 5.8 Cost Reference

Monthly at 25 optimized agents: **$2,200 - $4,400** (LLM $1,800-3,600 + infrastructure $400-800). Without optimization: $13,750 - $27,500. Optimization is not optional.

---

## 6. Database Scaling Inflection Points

### 6.1 Scaling Decision Matrix

| Agent Count | PostgreSQL | Valkey | Dolt | ClickHouse |
|-------------|-----------|--------|------|------------|
| 1-5 (dev) | Single instance | Single instance | Single instance | Not needed |
| 5-20 (early prod) | Connection pooling | Single instance | Single instance | Optional |
| 20-30 (production) | Consider read replica | Monitor streams | max_connections=150 | Recommended |
| 30+ (scale) | Read replicas, partitioning | Cluster mode | Multiple instances (< 5 DBs each) | Required |

### 6.2 When to Add ClickHouse

Add when: event volume > 10K/day, dashboard queries > 5 seconds, time-series aggregations span 30+ days, or token reports take > 10 seconds. **Migration path:** ETL from PostgreSQL events table to ClickHouse — not a schema rewrite. PostgreSQL stays as write target. The Glass reads ClickHouse when available, falls back to PostgreSQL.

### 6.3 Valkey Streams Backpressure

Monitor with `XLEN`. Stream length < 10K is healthy, 10-50K is elevated (check slow consumers), > 50K is critical (trim if necessary). Consumer lag > 10,000 events means the consumer is falling behind — common causes: crashed process, slow downstream write, or volume spike.

### 6.4 Dolt Ready Queue Performance

The ready queue CTE is the most sensitive Dolt query. If it exceeds 500ms with 10K+ items, add a materialized view fallback refreshed on Dolt commit hooks. Check with `platform work ready --timing`.

---

## 7. Troubleshooting Common Issues

### 7.1 Worker Stuck (>10 min no progress)

The 3-tier watchdog catches this: Tier 0 detects heartbeat timeout (2 min), Tier 1 runs AI triage on The Trail (5 min), Tier 2 sends a monitor agent (10 min). Manual: `platform fleet inspect <id>` to check last tool call, `platform agent kill <id>` to terminate. Common causes: pending Keeper approval, tool retry loop, hanging LLM request, worktree lock contention.

### 7.2 Merge Queue Jammed

`platform merge status --verbose` to identify the stuck item. Common fixes:

| Cause | Fix |
|-------|-----|
| Tier 4 failure | `platform merge skip <item-id>` |
| Hanging test suite | Kill test runner, investigate |
| Contract violation | Fix violations, resubmit |
| Dependency cycle | Resolve order manually |

Force-merge (requires Keeper): `platform merge force <item-id> --reason "..."`.

### 7.3 SSE Connections Dropping

Check Nginx config: `proxy_buffering off`, `proxy_cache off`, `proxy_http_version 1.1`. Verify 30-second heartbeat is flowing. The Glass auto-reconnects via `Last-Event-ID`. For HTTP/1.1 connection limits (6 per origin), switch to HTTP/2.

### 7.4 Dolt Server Crash Recovery

Restart container: `docker compose -f infra/compose.local.yml restart hive-dolt`. Dolt uses WAL — restart should recover automatically. If corruption persists, restore from last good commit:

```sql
SELECT * FROM work_items AS OF 'abc123def';       -- query historical state
CALL DOLT_RESET('--hard', 'abc123def');            -- reset to known-good
SELECT * FROM DOLT_DIFF('HEAD~1', 'HEAD', 'work_items');  -- check for loss
```

### 7.5 Orphaned Worktrees

```bash
platform worktree list        # show all worktrees + session status
platform worktree clean       # remove worktrees with terminated sessions
```

The Tier 0 watchdog auto-detects these. Manual cleanup if watchdog is lagging.

### 7.6 Valkey OOM

Check memory: `valkey-cli INFO memory`. Check stream sizes: `valkey-cli XLEN hive:events`. Trim: `valkey-cli XTRIM hive:events MAXLEN ~ 10000`. Prevention: configure MAXLEN in `config.yaml` under `valkey.streams`. Streams are ephemeral — trimming loses events but The Glass reconnects with a full state snapshot. Durable data lives in PostgreSQL/ClickHouse.

### 7.7 ClickHouse Query Timeout

Check running queries: `SELECT query, elapsed FROM system.processes ORDER BY elapsed DESC`. Refresh stale materialized views: `SYSTEM REFRESH VIEW <name>`. For dashboard queries, always include time range filters — unbounded queries on large tables will timeout.

---

## 8. Backup and Recovery

### 8.1 PostgreSQL

pg_dump daily (retain 7 daily + 4 weekly), WAL archiving for point-in-time recovery (7-day window).

```bash
platform backup postgres
platform restore postgres --file backup.dump
platform restore postgres --target-time "2026-03-20 14:30:00"
```

### 8.2 Dolt

Dolt IS its own version control — every commit is recoverable by hash. Push daily to DoltHub, S3, or filesystem remote. Query any historical state with `AS OF` without restoring.

```bash
platform backup dolt
platform restore dolt --remote origin
```

### 8.3 Valkey

RDB snapshots (every 5 min) + AOF. Streams are ephemeral by design. If data is lost: Workers reconnect, The Glass gets a full state snapshot, no durable data is lost. Recovery: restart Valkey (AOF replays automatically). If AOF corrupted, start fresh.

### 8.4 ClickHouse

Daily incremental backup via `clickhouse-backup`. Analytics data is derived — can be fully rebuilt from PostgreSQL: `platform rebuild clickhouse --from-postgres` (slow but complete).

### 8.5 The Glass UI Database

SQLite file copy weekly. Non-critical — preferences/layouts only. If lost, The Glass reinitializes with defaults.

### 8.6 Backup Verification

```bash
platform backup verify    # run monthly — checks all targets are accessible and recent
```

---

## 9. Health Check Reference

### 9.1 platform doctor

```bash
platform doctor                         # all checks
platform doctor --category <name>       # specific category
platform doctor --verbose               # connection details + timing
platform doctor --fix                   # auto-repair known issues
platform doctor --format json           # machine-readable output
platform doctor --format prometheus     # Prometheus gauge metrics
```

### 9.2 Categories

| Category | Checks |
|----------|--------|
| `postgres` | Connection, auth, schema version, pool utilization, replication lag |
| `valkey` | Connection, ACL config, stream health, memory usage |
| `dolt` | Server running, commit pattern (no `-Am`), branch count, disk usage, shadow DB detection |
| `clickhouse` | Connection, schema version, materialized view freshness, disk usage |
| `workers` | Active sessions, orphaned worktrees, stale agents, session duration |
| `mail` | Queue depth, delivery latency, dead letters |
| `cost` | Spend rate, budget utilization, anomaly detection, LiteLLM proxy reachability |

### 9.3 Auto-Repair (--fix)

Repairs: orphaned worktrees, stale sessions (releases claimed Cells), overgrown streams (trims to MAXLEN), dead letter messages, stale materialized views. Never touches: database schema, configuration, backup data, or active Worker sessions.

### 9.4 Recommended Schedule

| Check | Frequency | Method |
|-------|-----------|--------|
| Full doctor | Every 5 min | Cron or K8s liveness probe |
| Cost checks | Every 15 min | Prometheus scrape |
| `/health/deep` | Every 30 sec | Load balancer health check |
| `doctor --fix` | Daily | Cron (safe to run frequently) |

---

## Appendix: Quick Reference

### Commands

| Task | Command |
|------|---------|
| Start infrastructure | `docker compose -f infra/compose.local.yml up -d` |
| Start The Hive | `platform serve` |
| Health check | `platform doctor` |
| Fleet status | `platform fleet status` |
| Cost summary | `platform cost summary` |
| Merge queue | `platform merge status` |
| Ready work | `platform work ready` |
| Kill Worker | `platform agent kill <id>` |
| Clean worktrees | `platform worktree clean` |
| Cleanup | `platform cleanup` |
| Compact | `platform compact` |
| Backup all | `platform backup all` |
| Auto-repair | `platform doctor --fix` |

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `HIVE_POSTGRES_URL` | `postgres://hive:hive@localhost:5432/hive` | PostgreSQL |
| `HIVE_VALKEY_URL` | `redis://localhost:6379` | Valkey |
| `HIVE_DOLT_HOST` / `_PORT` | `localhost` / `3306` | Dolt |
| `HIVE_CLICKHOUSE_URL` | `http://localhost:8123` | ClickHouse |
| `HIVE_LITELLM_URL` | `http://localhost:4000` | LiteLLM proxy |
| `HIVE_PORT` | `3000` | API + The Glass |
| `HIVE_LOG_LEVEL` | `info` | Logging (debug/info/warn/error) |

### Port Map

| Port | Service |
|------|---------|
| 3000 | The Hive API + The Glass |
| 3306 | Dolt (MySQL protocol) |
| 4000 | LiteLLM Proxy |
| 5432 | PostgreSQL |
| 6379 | Valkey (Redis protocol) |
| 8123 / 9000 | ClickHouse (HTTP / native) |

---

*Operational procedures for The Hive platform. Generated 2026-03-20.*
