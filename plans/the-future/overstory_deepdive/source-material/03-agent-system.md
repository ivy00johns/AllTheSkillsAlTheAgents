# 03 — Agent System

## Capability Hierarchy

Overstory enforces a strict depth-limited hierarchy to prevent runaway spawning:

```
Depth 0: Coordinator / Orchestrator
    └── Depth 1: Lead / Supervisor
            └── Depth 2: Scout, Builder, Reviewer, Merger (leaf nodes)
```

Default max depth is 2. Configurable via `agents.maxDepth` in config.

### Spawning Rules

- **Coordinator** (depth 0) — spawns leads only, never workers directly
- **Lead** (depth 1) — can spawn scouts, builders, reviewers, mergers
- **Leaf nodes** (depth 2) — cannot spawn anything, must do their own work
- **Monitor** — runs at root (no worktree), cannot spawn, patrols the fleet

## The 10 Agent Roles

### Scout (`agents/scout.md`)
- **Purpose:** Read-only codebase exploration
- **Spawned by:** Lead
- **Tools:** Read, Glob, Grep, Bash (read-only git commands)
- **Cannot:** Write files, Edit files, spawn agents
- **Output:** Mail report to parent lead with findings
- **Key constraint:** Never modifies the codebase

### Builder (`agents/builder.md`)
- **Purpose:** Implementation — writes code, tests, docs
- **Spawned by:** Lead
- **Tools:** Read, Write, Edit, Glob, Grep, Bash (git, quality gates, tracker, mulch)
- **Key constraint:** Only modifies files within its declared scope
- **Quality gates:** Must run all gates before reporting `worker_done`
- **Propulsion principle:** Starts working immediately, no plan-and-wait

### Reviewer (`agents/reviewer.md`)
- **Purpose:** Read-only validation of builder work
- **Spawned by:** Lead
- **Tools:** Read, Glob, Grep, Bash (read-only git, quality gates)
- **Cannot:** Write or Edit files
- **Output:** PASS/FAIL verdict with actionable feedback
- **Key constraint:** Independent verification — never talks to the builder

### Lead (`agents/lead.md`)
- **Purpose:** Team coordination — decomposes work, delegates, verifies
- **Spawned by:** Coordinator
- **Tools:** Read, Write, Edit, Glob, Grep, Bash (git, ov sling, ov mail, ov status, tracker, mulch)
- **Can spawn:** Scouts, builders, reviewers, mergers
- **Key concept: Task Complexity Assessment**
  - **Simple** (1-3 files, well-understood) → lead does it directly
  - **Moderate** (3-6 files, clear spec) → skip scout, spawn one builder, self-verify
  - **Complex** (6+ files, multi-subsystem) → full scout → build → verify pipeline
- **Named failure modes:** SPEC_WITHOUT_SCOUT, SCOUT_SKIP, OVERLAPPING_FILE_SCOPE, etc.

### Merger (`agents/merger.md`)
- **Purpose:** Branch merge specialist
- **Spawned by:** Lead or Coordinator
- **Focus:** Resolving merge conflicts that automated tiers can't handle

### Coordinator (`agents/coordinator.md`)
- **Purpose:** Top-level orchestrator for a single project
- **Spawned by:** Orchestrator or directly by the user
- **Can spawn:** Leads (via `ov sling`)
- **Exit triggers:** Configurable — all agents done, tracker empty, shutdown signal
- **Runs in:** tmux session at the project root (no worktree)

### Orchestrator (`agents/orchestrator.md`)
- **Purpose:** Multi-repo coordinator of coordinators
- **Spawns:** Coordinators (one per project)
- **No worktree:** Operates from the root

### Monitor (`agents/monitor.md`)
- **Purpose:** Tier 2 continuous fleet patrol
- **Spawned by:** Coordinator (via `ov monitor start`)
- **No worktree:** Reads all state, writes nothing but mail
- **AI-powered:** Analyzes fleet state and makes recommendations

### Supervisor (`agents/supervisor.md`) [DEPRECATED]
- Per-project supervisor, replaced by coordinator + lead pattern

### ov-co-creation (`agents/ov-co-creation.md`)
- Special agent for developing overstory itself

## Agent Identity System

Each agent has a persistent identity stored in `.overstory/agents/{name}/identity.yaml`:

```typescript
interface AgentIdentity {
  name: string;
  capability: string;
  created: string;
  sessionsCompleted: number;
  expertiseDomains: string[];
  recentTasks: Array<{
    taskId: string;
    summary: string;
    completedAt: string;
  }>;
}
```

This enables:
- **Agent CVs** — track what an agent has done across sessions
- **Expertise accumulation** — agents build domain knowledge over time
- **Continuity** — a replacement agent can read its predecessor's CV

Managed by `src/agents/identity.ts`.

## Session Lifecycle

### The Three Layers

```typescript
interface AgentLayers {
  identity: AgentIdentity;        // Permanent (persists across assignments)
  sandbox: {                       // Persists across sessions
    worktreePath: string;
    branchName: string;
    taskId: string;
  };
  session: {                       // Ephemeral (one Claude runtime)
    id: string;
    pid: number | null;
    tmuxSession: string;
    startedAt: string;
    checkpoint: SessionCheckpoint | null;
  } | null;
}
```

### Session States

```
booting → working → completed
                  → stalled → zombie
```

State transitions are tracked in `sessions.db` via `SessionStore`.

### Checkpointing

Before compaction or handoff, agents save progress to
`.overstory/agents/{name}/checkpoint.json`:

```typescript
interface SessionCheckpoint {
  agentName: string;
  taskId: string;
  sessionId: string;
  timestamp: string;
  progressSummary: string;     // Human-readable work summary
  filesModified: string[];
  currentBranch: string;
  pendingWork: string;         // What remains
  mulchDomains: string[];
}
```

### Session Handoff

When an agent hits context limits or crashes, a handoff record is created:

```typescript
interface SessionHandoff {
  fromSessionId: string;
  toSessionId: string | null;  // null until continuation starts
  checkpoint: SessionCheckpoint;
  reason: "compaction" | "crash" | "manual" | "timeout";
  handoffAt: string;
}
```

The orchestrator spawns a continuation agent with the checkpoint as context.

## The Sling Mechanism

`ov sling` is the agent spawning command. It does a LOT:

1. **Validates** the hierarchy depth limit
2. **Creates** a git worktree on a new branch
3. **Generates** the dynamic overlay (Layer 2 instructions)
4. **Fetches** canopy profile content (if configured)
5. **Pre-loads** mulch expertise relevant to the task
6. **Deploys** runtime-specific config (hooks, guards, instruction file)
7. **Creates** a tmux session with the runtime spawn command
8. **Waits** for the agent TUI to become ready (polling pane content)
9. **Sends** the initial prompt (beacon verification for Claude Code)
10. **Registers** the session in `sessions.db`
11. **Records** the spawn in `events.db`
12. **Increments** the run's agent count

Options include:
- `--capability` — agent role
- `--name` — unique agent name (auto-generated if omitted)
- `--spec` — path to task spec file
- `--files` — exclusive file scope
- `--parent` — parent agent for hierarchy tracking
- `--depth` — current hierarchy depth
- `--skip-scout` / `--skip-review` — workflow overrides for leads
- `--runtime` — which runtime adapter to use
- `--base-branch` — base branch for worktree creation
- `--profile` — canopy profile name for prompt overlay

## Guard Rules

Each agent type has restrictions enforced through the runtime's guard mechanism:

### Tool Guards (in hooks/settings)
- Scouts: Read, Glob, Grep, Bash (read-only)
- Builders: Read, Write, Edit, Glob, Grep, Bash (scoped)
- Reviewers: Read, Glob, Grep, Bash (read-only)

### Bash Pattern Guards
- **Always allowed:** git status, git diff, git log, quality gate commands, tracker commands, mulch commands
- **Builder additions:** git add, git commit, ov mail send
- **Never allowed for leaf nodes:** ov sling (prevents unauthorized spawning)
- **Path boundary:** Bash commands are restricted to the agent's worktree path

Defined in `src/agents/guard-rules.ts`.

## Agent Manifest

The agent registry lives in `.overstory/agent-manifest.json`:

```typescript
interface AgentManifest {
  version: string;
  agents: Record<string, AgentDefinition>;
  capabilityIndex: Record<string, string[]>;
}

interface AgentDefinition {
  file: string;          // Path to base agent definition
  model: ModelRef;       // Model to use
  tools: string[];       // Allowed tools
  capabilities: string[];
  canSpawn: boolean;
  constraints: string[];
}
```

Loaded and queried via `src/agents/manifest.ts`.

## Insight Analysis

After a session completes, Overstory can analyze tool usage and file edits
to extract reusable insights:

```typescript
interface InsightAnalysis {
  insights: SessionInsight[];  // Patterns, conventions, failures
  toolProfile: ToolProfile;    // Top tools, counts, avg durations
  fileProfile: FileProfile;    // Hot files (edited multiple times)
}
```

These insights can be auto-recorded to mulch for organizational learning.
Implemented in `src/insights/analyzer.ts`.
