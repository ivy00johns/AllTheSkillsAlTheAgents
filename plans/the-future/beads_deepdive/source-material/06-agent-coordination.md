# 06 -- Agent Coordination Reference

This document is a comprehensive reference for the Beads agent coordination
primitives: agent beads, state machines, slot architecture, gates, swarm
coordination, HOP entity tracking, the state-label pattern, and the audit
system.

Beads provides data-layer primitives. The actual coordination logic (patrol
loops, heartbeat monitoring, work assignment) lives in external agents.
Beads is the database; the agents are the application.

Source: `cmd/bd/agent.go`, `cmd/bd/slot.go`, `cmd/bd/gate.go`,
`cmd/bd/swarm.go`, `internal/types/types.go`, `internal/audit/audit.go`.

---

## 1. Agent Beads -- Data Model

Agents are regular issues with the `gt:agent` label and dedicated fields.
There is no separate `agent` issue type -- the label is the discriminator.
This was changed from a type-based approach to support Gas Town separation.

### Agent-Specific Fields

All defined in `internal/types/types.go` on the `Issue` struct:

| Field          | DB Type        | Go Type      | Description                                |
|----------------|----------------|--------------|--------------------------------------------|
| `hook_bead`    | VARCHAR(255)   | `string`     | Current work item (0..1 cardinality)       |
| `role_bead`    | VARCHAR(255)   | `string`     | Role definition reference (required)       |
| `agent_state`  | VARCHAR(32)    | `AgentState` | State machine value                        |
| `last_activity`| DATETIME       | `*time.Time` | Updated on each action                     |
| `role_type`    | VARCHAR(32)    | `string`     | Config-defined classification              |
| `rig`          | VARCHAR(255)   | `string`     | Rig name (empty for town-level singletons) |

### Agent Detection

```go
// isAgentBead checks for the gt:agent label (cmd/bd/agent.go)
func isAgentBead(labels []string) bool {
    for _, l := range labels {
        if l == "gt:agent" { return true }
    }
    return false
}
```

All agent commands verify the `gt:agent` label before operating.

---

## 2. Agent ID Format

Agent IDs encode topology information. The format is parsed by
`parseAgentIDFields()` in `cmd/bd/agent.go`.

### ID Patterns

| Example                    | Role Type | Rig      | Pattern                        |
|----------------------------|-----------|----------|--------------------------------|
| `gt-mayor`                 | mayor     | (none)   | `<prefix>-<role>`              |
| `gt-deacon`                | deacon    | (none)   | `<prefix>-<role>`              |
| `gt-gastown-witness`       | witness   | gastown  | `<prefix>-<rig>-<role>`        |
| `gt-gastown-refinery`      | refinery  | gastown  | `<prefix>-<rig>-<role>`        |
| `gt-gastown-crew-nux`      | crew      | gastown  | `<prefix>-<rig>-<role>-<name>` |
| `gt-gastown-polecat-toast` | polecat   | gastown  | `<prefix>-<rig>-<role>-<name>` |

### Role Classifications

Configured via `config.yaml` under `agent_roles`:

| Config Key               | Roles              | Description                        |
|--------------------------|--------------------|------------------------------------|
| `agent_roles.town_level` | `"mayor,deacon"`   | Singletons with no rig             |
| `agent_roles.rig_level`  | `"witness,refinery"` | One per rig                      |
| `agent_roles.named`      | `"crew,polecat"`   | Multiple per rig with names        |

The parser scans from right to left to find a known role name. This allows
rig names to contain hyphens (e.g., `gt-my-project-witness` where the rig
is `my-project`).

### Auto-Creation

When `bd agent state` is called for a non-existent agent ID, the agent bead
is auto-created with:
- `IssueType = TypeTask` (the `gt:agent` label marks it as an agent)
- Role type and rig extracted from the ID
- Labels: `gt:agent`, `role_type:<value>`, `rig:<value>`

---

## 3. State Machine

Defined as the `AgentState` type in `internal/types/types.go`:

```
idle -> spawning -> running/working -> done -> idle
                         |
                      stuck -> (needs human intervention)
                         |
                      dead  (set by Witness on heartbeat timeout)
```

### State Constants

| State      | Constant       | Description                                    |
|------------|----------------|------------------------------------------------|
| `idle`     | `StateIdle`    | Agent is waiting for work                      |
| `spawning` | `StateSpawning`| Agent is starting up                           |
| `running`  | `StateRunning` | Agent is executing (general)                   |
| `working`  | `StateWorking` | Agent is actively working on a task            |
| `stuck`    | `StateStuck`   | Agent is blocked and needs help                |
| `done`     | `StateDone`    | Agent completed its current work               |
| `stopped`  | `StateStopped` | Agent has cleanly shut down                    |
| `dead`     | `StateDead`    | Agent died without clean shutdown              |

### Transition Rules

- Agents self-report all transitions except `dead`
- The `dead` state is set by the Witness on heartbeat timeout
- `bd agent state <id> <state>` updates both `agent_state` and
  `last_activity` atomically
- `bd agent heartbeat <id>` updates only `last_activity`

### Validation

`AgentState.IsValid()` accepts all eight states plus the empty string
(unset). The `validAgentStates` map in `cmd/bd/agent.go` is the runtime
check used by the CLI.

---

## 4. Slot Architecture

Defined in `cmd/bd/slot.go`. Slots are named fields on agent beads that
reference other beads.

| Slot   | Field       | Cardinality | Purpose                          |
|--------|-------------|-------------|----------------------------------|
| `hook` | `hook_bead` | 0..1        | Current work attached to agent   |
| `role` | `role_bead` | 1           | Role definition bead             |

### Enforcement

The `hook` slot enforces exclusive access:

```go
if slotName == "hook" && agent.HookBead != "" {
    return fmt.Errorf("hook slot already occupied by %s; "+
        "use 'bd slot clear %s hook' first", agent.HookBead, agentID)
}
```

To change work, the agent must:
1. `bd slot clear <agent> hook` -- detach current work
2. `bd slot set <agent> hook <new-bead>` -- attach new work

### CLI Commands

| Command                           | Description                           |
|-----------------------------------|---------------------------------------|
| `bd slot set <agent> <slot> <bead>` | Set a slot value                    |
| `bd slot clear <agent> <slot>`    | Clear a slot (set to empty)           |
| `bd slot show <agent>`            | Display all slot values               |

All slot commands support routing for cross-repo agent beads.

---

## 5. Witness System

Beads provides data primitives, NOT the patrol loop. The Witness is an
external agent that uses these primitives to monitor agent health.

### Beads Primitives for Witness

| Primitive                         | What It Does                              |
|-----------------------------------|-------------------------------------------|
| `bd agent heartbeat <id>`         | Writes `last_activity = time.Now()`       |
| `bd agent state <id> dead`        | Marks agent as dead                       |
| `bd list --label=gt:agent`        | Enumerates all agent beads                |
| `bd agent show <id> --json`       | Returns agent fields including timestamps |

### Witness Protocol (External)

The Witness agent (not implemented in Beads) would:
1. Periodically list all agents: `bd list --label=gt:agent --json`
2. For each agent, check `last_activity` against a timeout threshold
3. If `time.Since(last_activity) > threshold`:
   - `bd agent state <id> dead`
   - Escalate via notification system

The heartbeat timeout is not enforced by Beads itself. The Witness is
responsible for the polling interval and timeout threshold.

---

## 6. WispType TTL Tiers

Defined as the `WispType` enum in `internal/types/types.go`. Wisps are
classified for TTL-based compaction.

### Tier 1: Short-lived (6h TTL)

| Type          | Constant            | Purpose              |
|---------------|---------------------|----------------------|
| `heartbeat`   | `WispTypeHeartbeat` | Liveness signals     |
| `ping`        | `WispTypePing`      | Health check ACKs    |

### Tier 2: Medium-lived (24h TTL)

| Type          | Constant            | Purpose                      |
|---------------|---------------------|------------------------------|
| `patrol`      | `WispTypePatrol`    | Patrol cycle reports         |
| `gc_report`   | `WispTypeGCReport`  | Garbage collection reports   |

### Tier 3: Long-lived (7d TTL)

| Type          | Constant              | Purpose                    |
|---------------|-----------------------|----------------------------|
| `recovery`    | `WispTypeRecovery`    | Force-kill, recovery actions |
| `error`       | `WispTypeError`       | Error reports               |
| `escalation`  | `WispTypeEscalation`  | Human escalations           |

### Validation

`WispType.IsValid()` accepts all seven constants plus the empty string
(unset, for beads that are not wisps).

---

## 7. Gates -- Async Coordination

Gates are issues of type `"gate"` that represent async wait conditions.
They block workflow steps until their conditions are satisfied.

### Gate Fields (on Issue struct)

| Field       | Type            | Description                                   |
|-------------|-----------------|-----------------------------------------------|
| `await_type`| `string`        | `gh:run`, `gh:pr`, `timer`, `human`, `mail`, `bead` |
| `await_id`  | `string`        | Condition identifier (run ID, PR number, etc.) |
| `timeout`   | `time.Duration` | Max wait time before escalation                |
| `waiters`   | `[]string`      | Comma-separated notification targets           |

### Gate Types and Resolution

| Type     | Resolved When                                         | Escalated When                        |
|----------|------------------------------------------------------|---------------------------------------|
| `human`  | `bd gate resolve <id>` (manual close)                | Never (human decides)                 |
| `timer`  | `current_time > created_at + timeout`                | Never (timers resolve, not escalate)  |
| `gh:run` | `status=completed AND conclusion=success`            | `conclusion in (failure, canceled)`   |
| `gh:pr`  | `state=MERGED`                                       | `state=CLOSED AND merged=false`       |
| `bead`   | Target bead `status=closed`                          | (not implemented)                     |

### Gate Lifecycle

Gates are created during formula cooking when a step has a `gate` field.
They are wisps (ephemeral, local-only).

**Blocking mechanism**: Gates use `DepWaitsFor` dependencies with
`WaitsForMeta{Gate: "all-children"/"any-children", SpawnerID}`.

**Evaluation**: `bd gate check` iterates open gates and evaluates
conditions. For GitHub gates, it shells out to `gh run view` or
`gh pr view`. For timer gates, it compares timestamps. For bead gates,
it opens the target rig's database read-only and checks the bead's status.

### Gate CLI Commands

| Command                              | Description                                |
|--------------------------------------|--------------------------------------------|
| `bd gate list`                       | Show open gates                            |
| `bd gate list --all`                 | Show all gates including closed            |
| `bd gate check`                      | Evaluate and auto-close resolved gates     |
| `bd gate check --type=gh`            | Check only GitHub gates                    |
| `bd gate check --type=timer`         | Check only timer gates                     |
| `bd gate check --type=bead`          | Check only cross-rig bead gates            |
| `bd gate check --dry-run`            | Preview without changes                    |
| `bd gate resolve <id>`               | Manually close a gate                      |
| `bd gate show <id>`                  | Display gate details                       |
| `bd gate add-waiter <gate> <waiter>` | Register for wake notification             |

### Workflow Name Discovery

For `gh:run` gates where `await_id` is a workflow name (non-numeric), the
check command auto-discovers the most recent run ID by querying
`gh run list --workflow <name>` and takes the newest run (deterministic
ordering by creation time). The discovered ID is written back to the gate's
`await_id` field.

---

## 8. Swarm Coordination

Swarms orchestrate parallel work on epics. They use a molecule with
`mol_type = "swarm"` linked to an epic via `relates-to` dependency.

### MolType Constants

| Constant         | Value      | Description                                    |
|------------------|------------|------------------------------------------------|
| `MolTypeSwarm`   | `"swarm"`  | Coordinated multi-agent work                   |
| `MolTypePatrol`  | `"patrol"` | Recurring operational loops (Witness, Deacon)  |
| `MolTypeWork`    | `"work"`   | Regular single-agent work (default)            |

### WorkType Constants

| Constant                  | Value                | Description                         |
|---------------------------|----------------------|-------------------------------------|
| `WorkTypeMutex`           | `"mutex"`            | One exclusive worker (default)      |
| `WorkTypeOpenCompetition` | `"open_competition"` | Many submit, buyer picks            |

### Swarm Analysis (`analyzeEpicForSwarm`)

The analysis engine performs:

1. **Graph construction**: Get all child issues of the epic via parent-child
   dependencies. Build adjacency lists for blocking dependencies within
   the epic's children.

2. **Structural issue detection**:
   - Heuristic checks for dependency inversions (foundation issues with no
     dependents, integration issues with no dependencies)
   - Disconnected subgraph detection via DFS from roots
   - Cycle detection via DFS with in-progress/completed tracking

3. **Ready front computation**: Kahn's topological sort with level tracking.
   - Wave 0: nodes with no internal dependencies (in-degree 0)
   - Wave N+1: all blockers resolved in waves 0..N
   - Reports: `MaxParallelism` (largest wave) and `EstimatedSessions`
     (total issue count)

### Swarm Status (`getSwarmStatus`)

Status is COMPUTED from beads, not stored separately. Issues are categorized:

| Category   | Criteria                                          |
|------------|---------------------------------------------------|
| Completed  | `status == closed`                                |
| Active     | `status == in_progress`                           |
| Ready      | Open with all blocking dependencies satisfied     |
| Blocked    | Open with at least one open blocking dependency   |

### Swarm CLI Commands

| Command                                  | Description                          |
|------------------------------------------|--------------------------------------|
| `bd swarm validate <epic-id>`            | DAG analysis, ready fronts           |
| `bd swarm validate <epic-id> --verbose`  | Include detailed issue graph         |
| `bd swarm create <epic-id>`              | Create swarm molecule                |
| `bd swarm create <id> --coordinator=...` | With specific coordinator            |
| `bd swarm status <id>`                   | Computed status (not stored)         |
| `bd swarm list`                          | List all swarm molecules             |

### Auto-Wrapping

When `bd swarm create` receives a single issue (not an epic), it
auto-wraps: creates an epic with the issue as its only child, then creates
the swarm molecule for that epic.

---

## 9. HOP (Human Ontological Platform)

HOP tracks entity provenance and work quality for CV chains. Fields are
defined on the `Issue` struct in `internal/types/types.go`.

### Creator (`*EntityRef`)

```go
type EntityRef struct {
    Name     string  // Human-readable: "polecat/Nux", "mayor"
    Platform string  // Execution context: "gastown", "github"
    Org      string  // Organization: "steveyegge"
    ID       string  // Unique within platform/org: "polecat-nux"
}
```

URI format: `hop://<platform>/<org>/<id>`

Example: `hop://gastown/steveyegge/polecat-nux`

### Validations (`[]Validation`)

```go
type Validation struct {
    Validator *EntityRef  // Who approved/rejected
    Outcome   string      // "accepted", "rejected", "revision_requested"
    Timestamp time.Time   // When validation occurred
    Score     *float32    // Optional quality score (0.0-1.0)
}
```

Validation outcomes: `accepted`, `rejected`, `revision_requested`.

### QualityScore (`*float32`)

Aggregate quality score from 0.0 to 1.0, set by Refinery agents on merge.
Included in the issue's content hash for integrity.

### Crystallizes (`bool`)

Distinguishes work that compounds from work that evaporates:
- `true`: code, features -- affects CV weighting (Decision 006)
- `false`: ops, support -- operational work

### HOP Dependency Types

| Type             | Constant          | Description                                |
|------------------|-------------------|--------------------------------------------|
| `authored-by`    | `DepAuthoredBy`   | Creator relationship                       |
| `assigned-to`    | `DepAssignedTo`   | Assignment relationship                    |
| `approved-by`    | `DepApprovedBy`   | Approval relationship                      |
| `attests`        | `DepAttests`      | Skill attestation with `AttestsMeta`       |
| `delegated-from` | `DepDelegatedFrom`| Work delegated from parent; completion cascades up |

### AttestsMeta

Used with the `attests` dependency type for skill attestation:
`"X attests Y has skill Z"`.

---

## 10. State Labels Pattern (`bd set-state`)

The state label pattern provides dual-channel state tracking: events for
source of truth, labels for fast lookup.

### Mechanism

When `bd set-state <id> dim=val` is called:

1. **Creates TypeEvent issue as child**: Immediately closed, priority 4.
   The event bead is the source of truth for the state change.

2. **Removes old label**: Strips any existing `dimension:oldvalue` label
   from the issue.

3. **Adds new label**: Applies `dimension:newvalue` label for fast-lookup
   filtering.

### TypeEvent

```go
const TypeEvent IssueType = "event"
```

System-internal type used by `set-state` for audit trail beads. Not
exposed as a user-facing issue type. The `IssueType.IsTrusted()` method
returns true for event types, used during multi-repo hydration to
determine trust.

### Event Issue Fields

| Field       | Value                                    |
|-------------|------------------------------------------|
| IssueType   | `"event"`                                |
| Status      | `StatusClosed` (immediately)             |
| Priority    | 4 (lowest, background)                   |
| EventKind   | Namespaced: `"patrol.muted"`, `"agent.started"` |
| Actor       | Entity URI or agent ID who caused event  |
| Target      | Entity URI or bead ID affected           |
| Payload     | Event-specific JSON data                 |

### Query Pattern

```bash
bd list --label=patrol:active     # Fast: label-based filtering
bd list --label=agent:running     # All agents in running state
```

---

## 11. Audit System

Two parallel audit channels provide complementary capabilities.

### Channel 1: interactions.jsonl

Append-only JSONL file at `.beads/interactions.jsonl`.

Source: `internal/audit/audit.go`

```go
type Entry struct {
    ID        string            // Random hex: "int-a1b2c3d4"
    Kind      string            // Required: "llm_call", "tool_call", etc.
    CreatedAt time.Time         // UTC timestamp

    // Common metadata
    Actor     string            // Who performed the action
    IssueID   string            // Related issue ID

    // LLM call fields
    Model     string            // Model name
    Prompt    string            // Full prompt text
    Response  string            // Full response text
    Error     string            // Error message if failed

    // Tool call fields
    ToolName  string            // Tool/command name
    ExitCode  *int              // Process exit code

    // Labeling (append-only)
    ParentID  string            // Parent entry for threading
    Label     string            // "good", "bad", etc.
    Reason    string            // Explanation

    Extra     map[string]any    // Extension point
}
```

**API**: `audit.Append(entry)` -- atomic append to JSONL file. Creates file
if missing. Auto-generates ID and timestamp if not set. Returns entry ID.

**Design**: Intentionally append-only. Callers must not mutate existing
lines. The file is shared via git across clones/tools (file permissions
0644).

### Channel 2: interactions SQL Table

Same schema as the JSONL file, stored in Dolt. Advantages:
- Versioned via Dolt's commit history
- Server-side SQL queries
- Cross-repo replication

### Channel 3: events Table

Separate operational audit table for structured events:

| Event Kind       | Description                                |
|------------------|--------------------------------------------|
| `created`        | Issue was created                          |
| `updated`        | Issue fields were modified                 |
| `status_changed` | Status transition                          |
| `claimed`        | Agent claimed work                         |

### Best-Effort Principle

Audit logging in Beads follows a best-effort principle: audit failures
must never fail the primary operation. From `internal/compact/haiku.go`:

```go
_, _ = audit.Append(e) // Best effort: audit logging must never fail compaction
```

---

## 12. Agent CLI Commands

### State Management

| Command                         | Description                                    |
|---------------------------------|------------------------------------------------|
| `bd agent state <id> <state>`   | Set agent_state + last_activity, auto-creates  |
| `bd agent heartbeat <id>`       | Update last_activity only                      |
| `bd agent show <id>`            | Display all agent fields (`--json` supported)  |
| `bd agent backfill-labels`      | Add role_type/rig labels to existing agents    |

### Slot Management

| Command                              | Description                             |
|--------------------------------------|-----------------------------------------|
| `bd slot set <agent> <slot> <bead>`  | Set slot (errors if hook occupied)      |
| `bd slot clear <agent> <slot>`       | Clear slot value                        |
| `bd slot show <agent>`               | Display all slot values                 |

### State Label Management

| Command                        | Description                                  |
|--------------------------------|----------------------------------------------|
| `bd set-state <id> dim=val`    | Event bead + label pattern                   |

### Routing

All agent and slot commands support cross-repo routing. The
`resolveAndGetIssueWithRouting` function handles both local and remote
agent beads transparently.

---

## 13. Known Limitations

1. **Witness is external**: Beads provides heartbeat and state primitives
   but has no built-in patrol loop. The Witness agent must be implemented
   and deployed separately.

2. **ClaimIssue not implemented in embeddeddolt**: The embedded Dolt
   storage backend panics on `ClaimIssue` calls. Only the server-mode
   Dolt backend supports atomic claim operations.

3. **No timeout enforcement for gates**: Gates with timeouts are not
   auto-closed. `bd gate check` must be called periodically (by an
   external agent or cron job) to evaluate and close expired gates.

4. **Dolt server concurrency**: Under approximately 20 concurrent agents,
   the Dolt server can experience contention issues. This is a known
   limitation of the current Dolt concurrency model.

5. **HOP not fully operational**: The Refinery agent (which sets
   `QualityScore` on merge) is an external component that is not yet
   fully implemented. HOP entity tracking fields are populated but the
   full CV chain pipeline is not automated.

6. **Ephemeral and NoHistory mutually exclusive**: An issue cannot be both
   `Ephemeral` (not synced via git) and `NoHistory` (stored in wisps
   table but not GC-eligible). The `Issue.Validate()` method enforces
   this constraint:

   ```go
   if i.Ephemeral && i.NoHistory {
       return fmt.Errorf("ephemeral and no_history are mutually exclusive")
   }
   ```

---

## 14. Key Source Files

| File                                    | Purpose                                        |
|-----------------------------------------|------------------------------------------------|
| `cmd/bd/agent.go`                       | Agent state, heartbeat, show, backfill commands |
| `cmd/bd/slot.go`                        | Slot set/clear/show commands                    |
| `cmd/bd/gate.go`                        | Gate list, check, resolve, show commands        |
| `cmd/bd/gate_discover.go`              | GitHub workflow run discovery                    |
| `cmd/bd/swarm.go`                       | Swarm validate, create, status, list commands   |
| `internal/types/types.go`              | Issue struct, AgentState, MolType, WispType, etc.|
| `internal/audit/audit.go`              | Append-only JSONL audit logging                  |
| `internal/config/`                     | Agent role configuration (town/rig/named)        |

---

## 15. Dependency Type Reference (Coordination-Relevant)

| Type                | Constant              | Affects Ready | Description                           |
|---------------------|-----------------------|---------------|---------------------------------------|
| `blocks`            | `DepBlocks`           | Yes           | Standard blocking dependency          |
| `parent-child`      | `DepParentChild`      | Yes           | Hierarchy relationship                |
| `waits-for`         | `DepWaitsFor`         | Yes           | Fanout gate for dynamic children      |
| `conditional-blocks`| `DepConditionalBlocks`| Yes           | Blocks only when condition met        |
| `relates-to`        | `DepRelatesTo`        | No            | Informational link (swarm-to-epic)    |
| `authored-by`       | `DepAuthoredBy`       | No            | HOP: creator relationship             |
| `assigned-to`       | `DepAssignedTo`       | No            | HOP: assignment relationship          |
| `approved-by`       | `DepApprovedBy`       | No            | HOP: approval relationship            |
| `attests`           | `DepAttests`          | No            | HOP: skill attestation                |
| `delegated-from`    | `DepDelegatedFrom`    | No            | Delegation; completion cascades up    |

The `DependencyType.AffectsReadyWork()` method returns true for `blocks`,
`parent-child`, `conditional-blocks`, and `waits-for`. This determines
whether a dependency prevents an issue from appearing in ready fronts.

### WaitsForMeta

```go
type WaitsForMeta struct {
    Gate      string // "all-children" or "any-children"
    SpawnerID string // Step ID whose children to wait for
}
```

Constants:
- `WaitsForAllChildren = "all-children"` -- wait for all dynamic children
- `WaitsForAnyChildren = "any-children"` -- proceed when first child completes
