# 12 -- Build Plan for Gas Town Integration

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## Overview

This document is the build plan for integrating Beads into Gas Town and
constructing the missing coordination layers on top of it. The plan is phased
from "use what works today" through "build the cleaner version" to "production
hardening."

The key insight: Beads is an excellent data plane. Its storage engine, dependency
graph, and Dolt-based version control are solid. What is missing is the control
plane -- the orchestration, monitoring, and policy enforcement layers that Gas
Town needs. We build those on top, not by forking.

---

## Phase 0: Integrate As-Is (Week 1-2)

### Goal

Get every Gas Town rig using Beads for task tracking immediately, using only
features that are stable today. No custom code, no modifications.

### Step 0.1: Install the bd CLI

Choose one installation method per platform:

```bash
# macOS (Homebrew)
brew install beads

# Any platform (npm)
npm install -g @beads/bd

# From source (requires Go 1.22+)
git clone https://github.com/steveyegge/beads
cd beads && make install
```

Verify installation:

```bash
bd version
# Expected: bd version 0.61.0 (or later)
```

### Step 0.2: Initialize in Each Project

For each Gas Town rig/project:

```bash
cd /path/to/rig-project
bd init --prefix gt
```

This creates `.beads/` with:
- `metadata.json` -- database name, prefix, Dolt mode
- `dolt/` -- Dolt database directory (auto-created)
- `config.yaml` -- user preferences

For shared Dolt server mode (Gas Town's standard):

```bash
bd init --prefix gt \
  --server-host 127.0.0.1 \
  --server-port 3307 \
  --database beads_gt
```

### Step 0.3: Core Agent Workflow

Every agent (Polecat) follows this loop:

```bash
# 1. Find ready work
bd ready --json

# 2. Claim a task atomically
bd update <issue-id> --claim

# 3. Do the work (agent-specific)

# 4. Close the task
bd close <issue-id> --reason "completed: <summary>"

# 5. Check for more ready work
bd ready --json
```

For creating new work discovered during execution:

```bash
bd create "Discovered: <title>" \
  --type task \
  --priority 2 \
  --label discovered \
  --parent <parent-id>
```

### Step 0.4: Set Up OpenTelemetry

Enable observability from day one:

```bash
export BD_OTEL_METRICS_URL=http://localhost:4317  # Your OTLP endpoint
export BD_OTEL_TRACES_URL=http://localhost:4317
```

Key metrics to dashboard:
- `bd.db.retry_count` -- transient errors (should be near zero)
- `bd.db.lock_wait_ms` -- lock contention (P99 should be < 100ms)
- `bd.db.circuit_trips` -- server health (should be zero in steady state)
- `bd.db.circuit_rejected` -- cascading failure indicator

### Step 0.5: Install Claude Code Plugin

```bash
cd /path/to/rig-project
bd setup claude-code
```

This installs slash commands (`/bd-create`, `/bd-ready`, `/bd-close`, etc.)
into the Claude Code environment. Agents can use natural language or slash
commands to interact with Beads.

### Step 0.6: Set Up Recipes for Other Tools

```bash
bd setup cursor      # Cursor IDE integration
bd setup windsurf    # Windsurf integration
bd setup junie       # JetBrains Junie integration
```

Each recipe generates tool-specific configuration files that teach the AI tool
how to invoke `bd` commands.

### Phase 0 Deliverables

- [ ] bd CLI installed on all development machines
- [ ] Each rig project initialized with `bd init`
- [ ] Shared Dolt server configured and running
- [ ] Agent workflow (ready -> claim -> work -> close) documented and tested
- [ ] OTel dashboard showing storage metrics
- [ ] Claude Code plugin installed on all rig projects

---

## Phase 1: Harden the Foundation (Week 3-4)

### Goal

Fix the critical gaps identified in [11-production-gaps.md](11-production-gaps.md)
that block reliable operation at 20+ concurrent agents.

### Step 1.1: Dolt Server Tuning

**Load test first, then tune.**

1. Write a load test that simulates production conditions:
   - 20+ concurrent goroutines (simulating agents)
   - 10+ databases on one server (simulating Gas Town rigs)
   - Mixed read/write workload (70% reads, 30% writes)
   - Sustained for 30+ minutes

2. Run the load test against a vanilla `dolt sql-server` and record:
   - Connection establishment latency (P50, P95, P99)
   - Transaction commit latency (P50, P95, P99)
   - Error rate by category (timeout, lock, connection)
   - Server memory and CPU usage

3. Apply tuning parameters and re-test:

```sql
-- On the Dolt SQL server:
SET GLOBAL max_connections = 300;
SET GLOBAL interactive_timeout = 300;
SET GLOBAL wait_timeout = 300;
```

4. Implement a connection pool wrapper:

```go
// In the Gas Town orchestration layer (not in beads itself):
type PooledDoltAccess struct {
    pool    *semaphore.Weighted  // Limit concurrent connections
    maxConn int64
}

func (p *PooledDoltAccess) Acquire(ctx context.Context) error {
    return p.pool.Acquire(ctx, 1)
}
```

5. Add a circuit breaker with configurable thresholds:
   - Trip after 5 consecutive failures within 30 seconds
   - Half-open after 10 seconds (allow 1 probe request)
   - Reset after 3 consecutive successes

6. Document the tuning parameters in a runbook:
   - `max_connections`: recommended value per database count
   - `back_log`: queue depth for connection backlog
   - Connection pool size per DoltStore instance
   - Circuit breaker thresholds

### Step 1.2: MCP Server Fix

**Recommended approach: one MCP server per project.**

Running a single MCP server for multiple projects is the root cause of the
multi-repo routing bug. The cleanest fix is architectural:

```
Rig A project/
    .beads/
    MCP server (port 5100) --> bd (BEADS_WORKING_DIR=/path/to/rig-a)

Rig B project/
    .beads/
    MCP server (port 5101) --> bd (BEADS_WORKING_DIR=/path/to/rig-b)
```

Each MCP server process has a single, fixed workspace. No routing ambiguity.

If a shared MCP server is required (for resource efficiency), apply these
mitigations in order:

1. Set `BEADS_REQUIRE_CONTEXT=1` in the MCP server environment.
2. Require every tool call to include `workspace_root` as a parameter.
3. Validate that the resolved workspace matches the expected project before
   executing any write operation.

### Step 1.3: Disable Dolt Telemetry

On every machine running a Dolt server:

```bash
dolt config --global --add metrics.disabled true
export DOLT_DISABLE_EVENT_FLUSH=1
```

Add to the Dolt server startup script:

```bash
DOLT_DISABLE_EVENT_FLUSH=1 dolt sql-server \
  --host 127.0.0.1 \
  --port 3307 \
  --data-dir /path/to/dolt-data
```

### Step 1.4: Monitoring Dashboard

Build an OTel dashboard with these panels:

| Panel | Metric | Alert Threshold |
|-------|--------|-----------------|
| Connection Health | `bd.db.circuit_trips` | > 0 in 5 min window |
| Retry Storm | `bd.db.retry_count` rate | > 10/min |
| Lock Contention | `bd.db.lock_wait_ms` P99 | > 500ms |
| Circuit Rejection | `bd.db.circuit_rejected` | > 0 |
| Claim Conflicts | `bd.claim.conflict_count` (custom) | > 5/min |

### Phase 1 Deliverables

- [ ] Load test passing at 20+ concurrent agents, 10+ databases
- [ ] Dolt server tuning runbook written and applied
- [ ] Connection pool limits implemented
- [ ] MCP server running one-per-project (or BEADS_REQUIRE_CONTEXT=1 enabled)
- [ ] Dolt telemetry disabled on all machines
- [ ] OTel dashboard deployed with alerts

---

## Phase 2: Build the Missing Pieces (Week 5-8)

### Goal

Build the four coordination components that Beads lacks: Witness, Federation
CLI, Gate Evaluator, and Swarm Dispatcher.

### 2a. Built-in Witness Agent

The Witness monitors agent health and takes recovery actions.

**Architecture:**

```
Witness Daemon (Go)
    |
    +-- Heartbeat Monitor
    |   - Query: bd stale --json --threshold 90s
    |   - Interval: configurable (default 30s)
    |   - Dead threshold: 3 missed heartbeats (default 90s)
    |
    +-- Recovery Engine
    |   - Level 1: Warn (log + metric)
    |   - Level 2: Restart (kill agent session, re-queue work)
    |   - Level 3: Reassign (unclaim issue, return to ready pool)
    |   - Level 4: Alert human (webhook / email / Slack)
    |
    +-- State Tracker
        - Records recovery actions as events on the agent bead
        - Tracks recovery success/failure for adaptive thresholds
```

**Configuration (witness.config.yaml):**

```yaml
witness:
  heartbeat_interval: 30s
  dead_threshold: 90s          # 3 missed heartbeats
  recovery:
    level_1_action: warn       # Just log
    level_1_after: 90s         # After 1 missed threshold
    level_2_action: restart    # Kill and restart
    level_2_after: 180s        # After 2 missed thresholds
    level_3_action: reassign   # Return work to pool
    level_3_after: 300s        # After 5 minutes total
    level_4_action: alert      # Human notification
    level_4_after: 600s        # After 10 minutes total
  alert:
    webhook_url: ""            # Slack/Discord webhook
    email: ""                  # Email address
```

**Formula packaging:**

```toml
# mol-witness-patrol.formula.toml
[formula]
name = "witness-patrol"
description = "Built-in health monitoring for agent beads"
type = "molecule"

[steps.patrol]
action = "witness.patrol"
interval = "30s"
config = "witness.config.yaml"
```

**Implementation approach:**
- Use `beads.Storage` Go interface directly (not bd CLI subprocess).
- Query agent beads via `GetReadyWork` with agent-type filter.
- Compare `last_activity` timestamps against `dead_threshold`.
- Execute recovery actions via `UpdateIssue` (unclaim) and external commands
  (restart).

### 2b. Federation CLI and Daemon

Beads already has federation commands (`bd federation sync`, `status`,
`add-peer`, `remove-peer`, `list-peers`). The gap is testing, automation, and
backup.

**Step 2b.1: Test cross-town sync**

Write an integration test that:
1. Creates two Dolt databases with `bd init` (different prefixes).
2. Adds each as a federation peer of the other.
3. Creates issues in database A.
4. Runs `bd federation sync` from database B.
5. Verifies issues appear in database B.
6. Creates a conflicting update in both, syncs, and verifies the conflict
   resolution strategy (`ours` or `theirs`) is applied correctly.

**Step 2b.2: Automated sync daemon**

```go
// federation_daemon.go
type FederationDaemon struct {
    store    storage.DoltStorage
    peers    []string
    interval time.Duration
    strategy string  // "ours" | "theirs"
}

func (d *FederationDaemon) Run(ctx context.Context) error {
    ticker := time.NewTicker(d.interval)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            for _, peer := range d.peers {
                result, err := d.store.Sync(ctx, peer, d.strategy)
                if err != nil {
                    log.Error("federation sync failed",
                        "peer", peer, "error", err)
                    // Metric: bd.federation.sync_failures
                    continue
                }
                // Metric: bd.federation.sync_success
                // Metric: bd.federation.pulled_commits = result.PulledCommits
            }
        }
    }
}
```

**Step 2b.3: Backup strategy**

Add scheduled federation push to a backup remote:

```bash
# Add backup remote
bd federation add-peer backup s3://gastown-backup/beads

# Cron: push to backup every hour
0 * * * * cd /path/to/project && bd federation sync --peer backup
```

### 2c. Gate Evaluator Daemon

The Gate Evaluator polls open gates and closes them when their conditions are
satisfied.

**Architecture:**

```
Gate Evaluator (Go)
    |
    +-- Timer Gates
    |   - Check: created_at + timeout < now?
    |   - Action: bd close <gate-id> --reason "timeout expired"
    |
    +-- GitHub Run Gates (gh:run)
    |   - Check: gh api repos/{owner}/{repo}/actions/runs/{run_id} -> status
    |   - Action: bd close <gate-id> --reason "run completed: success"
    |   - Rate limit: max 1 API call per gate per 60s
    |
    +-- GitHub PR Gates (gh:pr)
    |   - Check: gh api repos/{owner}/{repo}/pulls/{pr_number} -> merged
    |   - Action: bd close <gate-id> --reason "PR merged"
    |   - Rate limit: max 1 API call per gate per 60s
    |
    +-- Bead Gates (bead)
    |   - Check: bd show <rig>:<bead-id> --json -> status == "closed"
    |   - Requires: federation peer access to target rig
    |   - Action: bd close <gate-id> --reason "bead closed"
    |
    +-- Timeout Enforcer
        - Check: all open gates where created_at + timeout < now
        - Action: escalate (warn, then force-close, then alert)
```

**Configuration (gate-evaluator.config.yaml):**

```yaml
gate_evaluator:
  poll_interval: 60s
  github:
    rate_limit_per_gate: 60s    # Min interval between API calls per gate
    token_env: GITHUB_TOKEN     # Environment variable for GitHub token
  timeout:
    warn_at: 0.8                # Warn at 80% of timeout
    force_close_at: 1.0         # Force close at 100% of timeout
    escalate_at: 1.5            # Alert human at 150% of timeout
```

**Implementation notes:**
- Query open gates: `store.SearchIssues(ctx, "", types.IssueFilter{IssueType: "gate", ExcludeStatus: ["closed"]})`
- Parse `await_type` to determine evaluation method.
- Use `await_id` as the lookup key for the external system.
- Close satisfied gates with `store.CloseIssue(ctx, id, reason, "gate-evaluator", "")`.
- Track gate evaluation latency: `bd.gate.eval_latency_ms`.

**Formula packaging:**

```toml
# mol-gate-patrol.formula.toml
[formula]
name = "gate-patrol"
description = "Automatic gate evaluation and timeout enforcement"
type = "molecule"

[steps.evaluate]
action = "gate.evaluate"
interval = "60s"
config = "gate-evaluator.config.yaml"
```

### 2d. Swarm Dispatcher

The Swarm Dispatcher automates wave-based work dispatching from Beads'
topological sort.

**Architecture:**

```
Swarm Dispatcher (Go)
    |
    +-- Wave Calculator (already exists in bd swarm)
    |   - Input: epic ID
    |   - Output: ReadyFront[] (wave number -> issue IDs)
    |   - Uses Kahn's topological sort on dependency graph
    |
    +-- Capacity Manager
    |   - Query: how many agents are available?
    |   - Source: agent beads with state = "idle"
    |   - Policy: don't dispatch more issues than idle agents
    |
    +-- Wave Dispatcher
    |   - For each wave (in order):
    |     1. Wait for previous wave to complete (all closed)
    |     2. Dispatch ready issues up to capacity
    |     3. Track in-progress count
    |   - Support partial waves (dispatch what fits)
    |
    +-- Progress Tracker
        - % complete: closed / total
        - ETA: (remaining / throughput) where throughput = closed / elapsed
        - Throughput: issues/hour, moving average
```

**Key design decisions:**

1. **Capacity-aware dispatching:** The existing `bd swarm analyze` computes all
   waves upfront. The dispatcher adds a runtime capacity check: if wave 3 has
   15 issues but only 8 agents are idle, dispatch 8 and queue the remaining 7.

2. **Progress tracking as OTel metrics:**
   - `bd.swarm.wave_current` -- current wave number
   - `bd.swarm.issues_total` -- total issues in swarm
   - `bd.swarm.issues_closed` -- closed issues
   - `bd.swarm.issues_in_progress` -- claimed/active issues
   - `bd.swarm.throughput_per_hour` -- rolling throughput

3. **Wave completion detection:** Poll `bd ready --json` filtered to the
   epic's children. When the ready set changes (new issues become unblocked),
   a new wave has started.

**Formula packaging:**

```toml
# mol-swarm-dispatch.formula.toml
[formula]
name = "swarm-dispatch"
description = "Capacity-aware wave dispatching for epics"
type = "molecule"

[params]
epic_id = { type = "string", required = true }
max_parallel = { type = "int", default = 10 }

[steps.analyze]
action = "swarm.analyze"
epic = "{{params.epic_id}}"

[steps.dispatch]
action = "swarm.dispatch"
epic = "{{params.epic_id}}"
max_parallel = "{{params.max_parallel}}"
depends_on = ["analyze"]
```

### Phase 2 Deliverables

- [ ] Witness daemon: detects dead agents within 90s, recovers within 2 min
- [ ] Federation sync tested between 2 towns with conflict resolution
- [ ] Automated federation sync daemon running on configurable interval
- [ ] Gate evaluator: closes satisfied gates within 60s
- [ ] Gate timeout enforcement with escalation chain
- [ ] Swarm dispatcher: capacity-aware wave dispatching
- [ ] All four components packaged as formulas
- [ ] OTel metrics for all four components

---

## Phase 3: Build the Cleaner Version (Week 9-16)

### Goal

The "cleaner version" is NOT a fork of Beads. It is an orchestration layer
built on top of Beads that:

1. Uses Beads as the data plane (via the Go library API, not CLI subprocess)
2. Adds the coordination components from Phase 2
3. Provides clean APIs for Gas Town integration
4. Handles the rough edges (federation, multi-repo, security)

### Architecture

```
Gas Town Orchestration Layer (Go binary)
    |
    +-- Witness Service
    |   Built-in health monitoring (Phase 2a)
    |   Uses: storage.AdvancedQueryStore (stale detection)
    |         storage.Storage (UpdateIssue for unclaim)
    |
    +-- Gate Evaluator
    |   Polling daemon for gate conditions (Phase 2c)
    |   Uses: storage.Storage (SearchIssues, CloseIssue)
    |         external APIs (GitHub, cross-rig federation)
    |
    +-- Swarm Dispatcher
    |   Capacity-aware wave dispatching (Phase 2d)
    |   Uses: storage.DependencyQueryStore (graph queries)
    |         storage.Storage (GetReadyWork, UpdateIssue)
    |
    +-- Federation Manager
    |   Clean sync + conflict resolution (Phase 2b)
    |   Uses: storage.FederationStore (peer management)
    |         storage.SyncStore (sync operations)
    |         storage.RemoteStore (push/pull)
    |
    +-- Security Layer
    |   Encryption, RBAC, audit (Phase 4)
    |   Wraps: storage.Storage (authorization checks)
    |
    +-- API Server
        Clean HTTP/gRPC API for Gas Town components
        Wraps all of the above into a unified service
    |
    v
beads.Storage interface (Go library, in-process)
    |
    v
Dolt SQL Server (tuned, monitored, one per town)
    |
    v
.beads/dolt/ (on-disk, encrypted at rest)
```

### Key Design Principle: Go Library, Not CLI Subprocess

The integration layer (MCP, Claude Code plugin) invokes `bd` as a subprocess
because it is written in Python/TypeScript. The orchestration layer is written
in Go and should use the `beads.Storage` interface directly.

Why this matters:

| Aspect | CLI subprocess | Go library |
|--------|---------------|------------|
| Latency per operation | ~50-100ms (process spawn) | ~1-5ms (function call) |
| Type safety | JSON parsing, string matching | Compile-time type checking |
| Error handling | Exit code + stderr parsing | Go error interface |
| Transaction support | None (each bd call is independent) | `RunInTransaction` for atomics |
| Connection pooling | New connection per invocation | Shared pool across all calls |
| Memory | New process per call | Shared address space |

To use the Go library:

```go
import (
    "github.com/steveyegge/beads/internal/storage/dolt"
    "github.com/steveyegge/beads/internal/storage"
)

cfg := dolt.Config{
    Path:       "/path/to/.beads/dolt",
    BeadsDir:   "/path/to/.beads",
    Database:   "beads_gt",
    ServerHost: "127.0.0.1",
    ServerPort: 3307,
}

store, err := dolt.New(ctx, cfg)
if err != nil {
    log.Fatal(err)
}
defer store.Close()

// Use the full DoltStorage interface
var ds storage.DoltStorage = store

// Atomic multi-operation transaction
err = ds.RunInTransaction(ctx, "create epic with children", func(tx storage.Transaction) error {
    if err := tx.CreateIssue(ctx, epic, "mayor"); err != nil {
        return err
    }
    for _, child := range children {
        if err := tx.CreateIssue(ctx, child, "mayor"); err != nil {
            return err
        }
        if err := tx.AddDependency(ctx, dep, "mayor"); err != nil {
            return err
        }
    }
    return nil
})
```

### Key Design Principle: Formula-Driven Workflows

Every coordination component is a formula. This means:

1. **Discoverable:** `bd formula list` shows all available coordination formulas.
2. **Configurable:** Parameters are in TOML, not hard-coded.
3. **Composable:** Formulas can depend on each other.
4. **Auditable:** Every formula execution creates events in the Dolt history.
5. **Replaceable:** A Gas Town can swap one formula implementation for another.

### Key Design Principle: Configuration Over Code

All tunables live in YAML configuration files, not Go constants:

```yaml
# gastown.config.yaml
orchestration:
  witness:
    enabled: true
    heartbeat_interval: 30s
    dead_threshold: 90s
    recovery_levels: [warn, restart, reassign, alert]
  gates:
    enabled: true
    poll_interval: 60s
    timeout_enforcement: true
  swarm:
    enabled: true
    max_parallel: 20
    wave_completion_poll: 10s
  federation:
    enabled: true
    sync_interval: 5m
    strategy: ours
    backup_remote: s3://gastown-backup/beads
    backup_interval: 1h
  security:
    encryption_at_rest: false    # Phase 4
    rbac_enabled: false          # Phase 4
    audit_logging: true
  dolt:
    server_host: 127.0.0.1
    server_port: 3307
    max_connections_per_db: 15
    circuit_breaker_threshold: 5
    circuit_breaker_reset: 10s
```

### Key Design Principle: Graceful Degradation

The system must work with 1 agent or 30. Each component degrades gracefully:

| Component | 1 Agent | 5 Agents | 30 Agents |
|-----------|---------|----------|-----------|
| Witness | Monitors the one agent | Monitors all 5 | Monitors all 30, sharded |
| Gate Evaluator | Polls gates every 60s | Same | Same (gates are few) |
| Swarm | Sequential wave dispatch | Parallel within waves | Full parallelism |
| Federation | Manual sync | Periodic sync | Continuous sync |
| Connection Pool | 1 connection | 5 connections | Pooled, backpressure |

### Orchestration Layer API

The orchestration layer exposes a clean API for Gas Town components:

```go
// gastown/orchestration/api.go

type Orchestrator interface {
    // Work management
    DispatchWork(ctx context.Context, epicID string, maxParallel int) error
    GetReadyWork(ctx context.Context, agentID string) ([]*types.Issue, error)
    ClaimWork(ctx context.Context, issueID string, agentID string) error
    CompleteWork(ctx context.Context, issueID string, agentID string, result string) error

    // Health monitoring
    RegisterAgent(ctx context.Context, agentID string, role string) error
    Heartbeat(ctx context.Context, agentID string) error
    GetAgentHealth(ctx context.Context) ([]*AgentHealth, error)

    // Gate management
    CreateGate(ctx context.Context, gateType string, awaitID string, timeout time.Duration) (string, error)
    CheckGates(ctx context.Context) ([]*GateStatus, error)

    // Federation
    SyncWithPeer(ctx context.Context, peerName string) (*SyncResult, error)
    GetFederationStatus(ctx context.Context) ([]*PeerStatus, error)

    // Observability
    GetMetrics(ctx context.Context) (*OrchestrationMetrics, error)
}
```

### Phase 3 Deliverables

- [ ] Go orchestration binary with all four Phase 2 components integrated
- [ ] Using beads.Storage Go interface (not CLI subprocess)
- [ ] Unified configuration file (gastown.config.yaml)
- [ ] Clean API for Gas Town components
- [ ] All workflows formula-driven
- [ ] Graceful degradation tested (1 agent, 5 agents, 30 agents)
- [ ] Integration tests covering the full orchestration lifecycle

---

## Phase 4: Production Hardening (Week 17-20)

### Goal

Security, resilience, and operational maturity.

### 4.1: Encryption at Rest

1. **Dolt data directory encryption:** Use OS-level encryption (LUKS on Linux,
   FileVault on macOS, BitLocker on Windows) for the `.beads/dolt/` directory.
2. **Connection encryption:** Enable TLS between the orchestration layer and
   Dolt server (`ServerTLS: true` in Config).
3. **Federation credential encryption:** Replace the per-session `credentialKey`
   with a persistent key stored in a secure keychain (macOS Keychain, Linux
   Secret Service, or a KMS).

### 4.2: RBAC Model

Define roles and permissions:

| Role | Create | Read | Update | Close | Delete | Admin |
|------|--------|------|--------|-------|--------|-------|
| Observer | -- | Yes | -- | -- | -- | -- |
| Worker (Polecat) | Discovered only | Own + assigned | Own + assigned | Own | -- | -- |
| Coordinator (Mayor) | Yes | All | All | All | -- | -- |
| Maintainer (Deacon) | Yes | All | All | All | Closed only | -- |
| Admin | Yes | All | All | All | Yes | Yes |

Implementation: wrap the `storage.Storage` interface with an authorization
layer that checks the caller's role before delegating to the underlying store.

```go
type AuthorizedStore struct {
    inner storage.Storage
    rbac  *RBACEngine
}

func (s *AuthorizedStore) UpdateIssue(ctx context.Context, id string, updates map[string]interface{}, actor string) error {
    role := s.rbac.GetRole(actor)
    issue, err := s.inner.GetIssue(ctx, id)
    if err != nil {
        return err
    }
    if !s.rbac.CanUpdate(role, issue, actor) {
        return fmt.Errorf("unauthorized: %s (role=%s) cannot update %s", actor, role, id)
    }
    return s.inner.UpdateIssue(ctx, id, updates, actor)
}
```

### 4.3: Audit Logging

Structured audit log for all agent actions, beyond Dolt commit history:

```json
{
  "timestamp": "2026-03-17T10:30:00Z",
  "actor": "polecat-toast",
  "role": "worker",
  "action": "update_issue",
  "issue_id": "gt-x8f2k",
  "fields_changed": ["status", "assignee"],
  "authorized": true,
  "latency_ms": 12,
  "source": "mcp-server",
  "session_id": "sess-abc123"
}
```

Write to: structured log file (JSON lines), OTel traces, and optionally to a
dedicated `audit_log` table in Dolt.

### 4.4: Chaos Testing

Simulate failure modes and verify recovery:

| Scenario | Method | Expected Recovery |
|----------|--------|-------------------|
| Agent crash mid-task | Kill agent process | Witness detects within 90s, reassigns within 5 min |
| Dolt server restart | `dolt sql-server` restart | Circuit breaker trips, auto-reconnect within 30s |
| Network partition (federation) | iptables rule | Sync fails gracefully, retries on next interval |
| Concurrent claim race | 10 agents claim same issue | Exactly 1 succeeds (CAS), others get ErrAlreadyClaimed |
| Database corruption | Truncate Dolt file | `bd doctor --fix` repairs, or restore from backup |
| MCP server crash | Kill Python process | Supervisor restarts, agents reconnect |
| Gate evaluator crash | Kill evaluator | Gates miss one poll cycle, evaluator restarts |

### 4.5: Backup and Restore

Formal SLA for data protection:

| Tier | RPO (max data loss) | RTO (max downtime) | Method |
|------|---------------------|--------------------|--------|
| Tier 1 (active work) | 5 minutes | 15 minutes | Federation push to backup remote |
| Tier 2 (closed work) | 1 hour | 1 hour | Hourly snapshot to S3 |
| Tier 3 (compacted) | 24 hours | 4 hours | Daily export to JSONL |

Backup commands:

```bash
# Automated backup (in cron or systemd timer)
bd backup --remote s3://gastown-backup/$(date +%Y%m%d)

# Restore from backup
bd restore --from s3://gastown-backup/20260317

# Verify backup integrity
bd backup verify --remote s3://gastown-backup/20260317
```

### 4.6: Runbooks

Write operational runbooks for:

1. **Dolt server unresponsive:** Check connections, restart server, verify
   circuit breaker recovery, check for lock contention.
2. **Agent stuck (not heartbeating):** Check Witness logs, manual unclaim,
   restart agent, investigate root cause.
3. **Federation sync conflict:** Check conflict type, apply resolution strategy,
   verify data consistency.
4. **Gate stuck past timeout:** Check gate evaluator logs, manual resolution
   via `bd gate resolve`, investigate external system.
5. **ID collision (counter mode):** Reseed counter, deduplicate issues, switch
   to hash mode if recurring.
6. **MCP routing error:** Check `_workspace_context` state, restart MCP server,
   verify `BEADS_REQUIRE_CONTEXT=1`.

### Phase 4 Deliverables

- [ ] TLS enabled between orchestration layer and Dolt server
- [ ] OS-level encryption on Dolt data directories
- [ ] RBAC model implemented and tested
- [ ] Structured audit logging to file + OTel
- [ ] Chaos testing suite passing all 7 scenarios
- [ ] Backup/restore tested with formal RPO/RTO validation
- [ ] Runbooks written for 6 failure modes

---

## Integration Points with Gas Town

This table maps every Gas Town component to its Beads integration point.

| Gas Town Component | Role | Beads Integration | Interface Used |
|---|---|---|---|
| **Mayor** (coordinator) | Cross-rig work tracking, dispatch decisions | `GetReadyWork()` for available work, `CreateIssue()` for new epics, Swarm Dispatcher for wave management | `storage.Storage`, `storage.DependencyQueryStore` |
| **Deacon** (maintenance) | Database health, compaction, cleanup | Runs patrol formulas (`mol-witness-patrol`, `mol-gate-patrol`), `bd doctor --fix` for repairs, `bd compact` for aged issues | `storage.CompactionStore`, `storage.AdvancedQueryStore` |
| **Witness** (health) | Agent health monitoring | `bd stale --json` for detection, `UpdateIssue()` for unclaim, agent bead state tracking | `storage.Storage` (agent queries) |
| **Refinery** (merge/quality) | Quality scoring, merge decisions | `UpdateIssue()` to set QualityScore, HOP dependency type for review chains, gate creation for CI checks | `storage.Storage`, `storage.DependencyQueryStore` |
| **Polecats** (workers) | Task execution | `ClaimIssue()` for atomic work claiming, `CloseIssue()` on completion, `CreateIssue()` for discovered work | `storage.Storage` |
| **Crew** (humans) | Manual oversight, work creation | `bd list`, `bd show`, `bd create` via CLI or Claude Code plugin, `bd ready` for work queue visibility | CLI layer |
| **Convoys** (cross-rig coordination) | Multi-rig epics | Mapped to `bd` epics with Swarm Dispatcher, cross-rig deps via `external:<rig>:<id>`, federation sync for status | `storage.DependencyQueryStore`, `storage.FederationStore` |
| **Wasteland** (cross-town) | Inter-town federation | `bd federation sync` for data exchange, `bd federation status` for connectivity, conflict resolution for divergent histories | `storage.SyncStore`, `storage.FederationStore` |

### Data Flow: Polecat Work Cycle

```
Mayor                          Beads                         Polecat
  |                              |                              |
  |-- CreateIssue (epic) ------->|                              |
  |-- CreateIssues (children) -->|                              |
  |-- AddDependency (graph) ---->|                              |
  |                              |                              |
  |     Swarm Dispatcher         |                              |
  |-- DispatchWork (wave 1) ---->|                              |
  |                              |                              |
  |                              |<---- GetReadyWork -----------|
  |                              |----> [issue-1, issue-2] ---->|
  |                              |                              |
  |                              |<---- ClaimIssue(issue-1) ----|
  |                              |----> OK (CAS succeeded) ---->|
  |                              |                              |
  |                              |       ... agent works ...    |
  |                              |                              |
  |                              |<---- Heartbeat --------------|
  |     Witness checks           |                              |
  |     last_activity            |                              |
  |                              |                              |
  |                              |<---- CloseIssue(issue-1) ----|
  |                              |                              |
  |     Swarm Dispatcher         |                              |
  |     detects wave 1 complete  |                              |
  |-- DispatchWork (wave 2) ---->|                              |
  |                              |                              |
```

---

## Success Metrics

These metrics define "done" for the Gas Town / Beads integration.

### Reliability

| Metric | Target | Measurement |
|--------|--------|-------------|
| Dolt server uptime | 99.9% (8.7h downtime/year) | OTel circuit_trips = 0 over 24h |
| Zero data corruption | 0 incidents/month | Audit log + `bd doctor --validate` |
| Agent recovery time | < 2 minutes | Witness detection (90s) + recovery (30s) |
| Gate evaluation latency | < 60 seconds | Gate creation to gate close timestamp |

### Scale

| Metric | Target | Measurement |
|--------|--------|-------------|
| Concurrent agents | 30+ without degradation | Load test P99 latency < 500ms |
| Databases per server | 15+ | Load test with production layout |
| Federation sync | 2+ towns | Cross-town sync integration test |
| Swarm throughput | 100+ issues/hour | Swarm dispatcher metrics |

### Correctness

| Metric | Target | Measurement |
|--------|--------|-------------|
| Claim atomicity | 100% (no double claims) | Concurrent claim test: exactly 1 winner |
| Dependency ordering | Correct topological sort | Wave dispatch matches Kahn's algorithm output |
| Federation consistency | Eventual consistency within sync interval | Cross-town issue comparison |
| Gate satisfaction | No false positives | Gate close only on verified condition |

### Operational

| Metric | Target | Measurement |
|--------|--------|-------------|
| MTTR (mean time to recovery) | < 15 minutes | Runbook-assisted incident resolution |
| Backup RPO | < 5 minutes (active work) | Federation push interval |
| Audit trail completeness | 100% of write operations | Audit log vs. Dolt commit count |
| Alert noise ratio | < 5% false positives | Alert count vs. actionable incident count |

---

## Timeline Summary

| Phase | Weeks | Focus | Key Deliverable |
|-------|-------|-------|-----------------|
| 0 | 1-2 | Integrate as-is | All rigs using bd for task tracking |
| 1 | 3-4 | Harden foundation | Load-tested, MCP fixed, monitored |
| 2 | 5-8 | Build missing pieces | Witness, gates, federation, swarm |
| 3 | 9-16 | Cleaner version | Go orchestration layer on beads.Storage |
| 4 | 17-20 | Production hardening | Security, chaos testing, runbooks |

Total: 20 weeks from start to production-ready Gas Town on Beads.

---

## Decision Log

Key decisions made during planning, for future reference.

| Decision | Rationale | Alternative Considered |
|----------|-----------|----------------------|
| Build on top of Beads, not fork | Beads data plane is solid; we need a control plane | Fork and modify (too much maintenance burden) |
| Use Go library, not CLI subprocess | 10x performance, type safety, transactions | CLI subprocess (simpler but slower) |
| One MCP server per project | Eliminates multi-repo routing bug entirely | Shared MCP with workspace isolation (complex, fragile) |
| Formula-driven coordination | Discoverable, configurable, composable | Hard-coded Go daemons (less flexible) |
| Ours strategy for federation conflicts | Local changes are authoritative for local work | Theirs (risky: remote overwrites local), manual (slow) |
| RBAC at orchestration layer, not Beads | Beads is pre-1.0; adding RBAC upstream is premature | Beads-level RBAC (couples us to upstream changes) |
