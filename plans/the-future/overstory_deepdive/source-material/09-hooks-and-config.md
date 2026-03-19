# 09 — Hooks, Guards, and Configuration

## The Hook-Driven Orchestrator Loop

Overstory's orchestrator is not a daemon — it's a Claude Code session enhanced
by shell hooks. The hooks create an event-driven loop:

### SessionStart Hook
**Trigger:** When Claude Code starts a session
**Action:** Runs `ov prime`
**Effect:** Loads into context:
- Project configuration
- Recent activity from sessions.db
- Mulch expertise
- Canopy prompts
- Active run status

This is how the orchestrator "knows" about its project without being told.

### UserPromptSubmit Hook
**Trigger:** Every time the user sends a message
**Action:** Runs `ov mail check --inject`
**Effect:** Surfaces unread mail from agents:
- Builder completion reports
- Scout findings
- Error escalations
- Merge results
- Questions needing answers

This is how the orchestrator "hears" from agents between user messages.

### How It Works Together

```
User sends message
  → UserPromptSubmit hook fires
    → ov mail check --inject
      → Queries mail.db for unread messages to orchestrator
      → Formats them as text
      → Injects into Claude's context
  → Claude processes user message + injected mail
  → Claude decides what to do next
    → Maybe: ov sling (spawn agent)
    → Maybe: ov mail send (reply to agent)
    → Maybe: ov merge (merge completed work)
    → Maybe: ov status (check fleet)
```

The orchestrator never polls. It reacts to user interaction, with agent
mail automatically surfaced at each turn.

## Hook Deployment to Worktrees

When `ov sling` spawns an agent, it deploys hooks to the agent's worktree
via the runtime adapter's `deployConfig()`:

### Claude Code Hooks

Written to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "command": "ov prime --agent builder-1"
    }],
    "UserPromptSubmit": [{
      "command": "ov mail check --agent builder-1 --inject"
    }],
    "PreToolUse": [{
      "command": "ov log tool-start --agent builder-1"
    }],
    "PostToolUse": [{
      "command": "ov log tool-end --agent builder-1"
    }]
  },
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Glob", "Grep", "Bash(...)"]
  }
}
```

### Pi Guards

Written as extensions in `.pi/extensions/overstory-guard.json`:
- Tool restrictions via Pi's extension system
- Path boundary enforcement
- Command whitelist

### Codex/Gemini/Other

Each runtime has its own mechanism — some have hooks, some don't.
Runtimes without hook support get instructions embedded in the
instruction file itself.

## Guard Rules

Guards restrict what agents can do. Defined in `src/agents/guard-rules.ts`.

### Tool Guards

Each capability has an allowed tool list:

| Capability | Tools |
|------------|-------|
| scout | Read, Glob, Grep, Bash (read-only) |
| builder | Read, Write, Edit, Glob, Grep, Bash (scoped) |
| reviewer | Read, Glob, Grep, Bash (read-only) |
| lead | Read, Write, Edit, Glob, Grep, Bash (scoped + ov commands) |
| coordinator | All |

### Bash Pattern Guards

Fine-grained control over which bash commands are allowed:

**Always allowed (all agents):**
- `git status`, `git diff`, `git log`
- Quality gate commands (from config)
- Tracker commands (`sd show`, `sd ready`, etc.)
- Mulch commands (`ml prime`, `ml record`, etc.)

**Builder additions:**
- `git add`, `git commit`
- `ov mail send`, `ov mail check`, `ov mail list`, `ov mail read`, `ov mail reply`

**Lead additions:**
- `ov sling` (spawn sub-workers)
- `ov status` (monitor fleet)
- `ov nudge` (poke stalled workers)

**Never allowed for leaf nodes:**
- `ov sling` (prevents unauthorized spawning)
- `git push` (merging is handled by the coordinator)

### Path Boundary Enforcement

Agents are restricted to their worktree path:
- Bash commands that reference paths outside the worktree are blocked
- File operations (Read, Write, Edit) are scoped to the worktree
- Git operations are scoped to the worktree's branch

## Configuration System

### Config Hierarchy

1. **Hardcoded defaults** (in `src/config.ts`)
2. **`config.yaml`** — project-level, committed to git
3. **`config.local.yaml`** — machine-specific, gitignored

### Full Configuration Surface

```yaml
project:
  name: "my-project"
  root: "/path/to/project"
  canonicalBranch: "main"
  qualityGates:
    - name: "Tests"
      command: "bun test"
      description: "all tests must pass"
    - name: "Lint"
      command: "biome check ."
      description: "no lint errors"
    - name: "Types"
      command: "tsc --noEmit"
      description: "type checking passes"
  defaultProfile: "standard"

agents:
  manifestPath: ".overstory/agent-manifest.json"
  baseDir: "agents/"
  maxConcurrent: 10
  staggerDelayMs: 2000
  maxDepth: 2
  maxSessionsPerRun: 0       # 0 = unlimited
  maxAgentsPerLead: 5

worktrees:
  baseDir: ".overstory/worktrees"

taskTracker:
  backend: "auto"            # auto | seeds | beads
  enabled: true

mulch:
  enabled: true
  domains: []                # empty = auto-detect
  primeFormat: "markdown"    # markdown | xml | json

merge:
  aiResolveEnabled: true
  reimagineEnabled: true

providers:
  openrouter:
    type: "gateway"
    baseUrl: "https://openrouter.ai/api/v1"
    authTokenEnv: "OPENROUTER_API_KEY"

models:
  coordinator: "opus"
  lead: "sonnet"
  builder: "sonnet"
  scout: "haiku"
  reviewer: "sonnet"

watchdog:
  tier0Enabled: true
  tier0IntervalMs: 30000
  tier1Enabled: true
  tier2Enabled: false
  staleThresholdMs: 300000   # 5 minutes
  zombieThresholdMs: 600000  # 10 minutes
  nudgeIntervalMs: 60000     # 1 minute between escalation stages

logging:
  verbose: false
  redactSecrets: true

coordinator:
  exitTriggers:
    allAgentsDone: true
    taskTrackerEmpty: true
    onShutdownSignal: false

runtime:
  default: "claude"
  capabilities:
    builder: "pi"
    scout: "claude"
  printCommand: "claude"
  shellInitDelayMs: 0
  pi:
    provider: "anthropic"
    modelMap:
      opus: "anthropic/claude-opus-4-6"
      sonnet: "anthropic/claude-sonnet-4-6"
```

### Quality Gates

Quality gates are configurable per-project commands that agents must pass:

```yaml
qualityGates:
  - name: "Tests"
    command: "bun test"
    description: "all tests must pass"
```

Gates are:
- Injected into agent overlays as required pre-completion checks
- Added to allowed bash patterns in guard rules
- Referenced in the lead's `{{QUALITY_GATE_INLINE}}` template variable
- Listed in the builder's capabilities section

## Template System

### CLAUDE.md Template (`templates/CLAUDE.md.tmpl`)

The orchestrator's CLAUDE.md is generated from a template that includes:
- Project-specific config
- CLI command reference
- Agent hierarchy documentation
- Quality gate definitions

### Overlay Template (`templates/overlay.md.tmpl`)

The per-agent instruction file template. Variables include:
- `{{AGENT_NAME}}`, `{{TASK_ID}}`, `{{BRANCH_NAME}}`
- `{{SPEC_PATH}}`, `{{FILE_SCOPE}}`
- `{{PARENT_AGENT}}`, `{{DEPTH}}`
- `{{QUALITY_GATE_CAPABILITIES}}`, `{{QUALITY_GATE_INLINE}}`
- `{{TRACKER_CLI}}`, `{{TRACKER_NAME}}`
- `{{INSTRUCTION_PATH}}`
- `{{MULCH_EXPERTISE}}` (pre-loaded)
- `{{PROFILE_CONTENT}}` (from canopy)

### Hooks Template (`templates/hooks.json.tmpl`)

Template for `settings.local.json` deployed to agent worktrees.

## The Update Mechanism

`ov update` refreshes managed files from the installed package:

```bash
ov update                      # Refresh everything
ov update --agents             # Only agent definitions
ov update --manifest           # Only agent-manifest.json
ov update --hooks              # Only hooks.json
ov update --dry-run            # Show what would change
```

This keeps `.overstory/` in sync with the installed overstory version
without requiring a full re-init.
