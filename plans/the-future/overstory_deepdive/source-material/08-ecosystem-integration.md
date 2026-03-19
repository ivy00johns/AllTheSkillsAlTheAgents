# 08 — Ecosystem Integration (os-eco)

## The Four-Tool Ecosystem

Overstory is one part of a composable ecosystem. Each tool owns one concern:

```
┌───────────────────────────────────────────────────────────┐
│                     os-eco Ecosystem                       │
│                                                           │
│  overstory (ov)  ── orchestration ── spawn, merge, watch  │
│  seeds (sd)      ── issues        ── git-native tracking  │
│  mulch (ml)      ── expertise     ── patterns, decisions  │
│  canopy (cn)     ── prompts       ── versioned, profiles  │
│                                                           │
│  Each is an independent npm package with its own:         │
│  - CLI, data store, release cycle                         │
│  - Can be used standalone                                 │
│  - Integrates via file conventions + subprocess calls     │
└───────────────────────────────────────────────────────────┘
```

## Seeds (sd) — Git-Native Issue Tracking

Seeds is the task tracker backend for Overstory. It stores issues in
`.seeds/` as JSON files tracked by git — making issues first-class
citizens in the repo.

### Key Commands Used by Overstory

```bash
sd ready                      # Find unblocked work
sd show <id>                  # View issue details
sd create --title "..." --type task --priority 2
sd update <id> --status in_progress
sd close <id>                 # Complete work
sd dep add <id> <depends-on>  # Dependency management
sd sync                       # Sync with git
sd prime                      # Load context
```

### Integration Points

- **`ov sling`** — spawns agents with task IDs from seeds
- **Agent overlays** — include `sd` commands in allowed bash patterns
- **Coordinator exit triggers** — `taskTrackerEmpty` checks `sd ready`
- **`ov group`** — batch coordination wraps seed issue groups
- **Builder completion** — builders run `sd close` when done
- **Lead workflow** — leads use `sd show`, `sd update`, `sd ready`

### The Tracker Abstraction

Overstory doesn't hardcode seeds. The tracker system (`src/tracker/`) is
pluggable:

```typescript
interface TrackerClient {
  ready(): Promise<TrackerIssue[]>;
  show(id: string): Promise<TrackerIssue>;
  create(opts): Promise<string>;
  update(id, opts): Promise<void>;
  close(id, reason): Promise<void>;
  sync(): Promise<void>;
}
```

Three backends:
- `src/tracker/seeds.ts` — Seeds (sd) adapter
- `src/tracker/beads.ts` — Beads (bd) adapter
- `src/tracker/factory.ts` — `resolveBackend()` auto-detects which is available

Config controls: `taskTracker.backend: "auto" | "seeds" | "beads"`

## Mulch (ml) — Structured Expertise

Mulch is Overstory's organizational memory. Agents learn from experience
and share knowledge across sessions via structured expertise records.

### What Mulch Stores

Records in `.mulch/` organized by domain:

| Type | Purpose | Example |
|------|---------|---------|
| `convention` | Coding standards, project norms | "Always use tab indentation" |
| `pattern` | Reusable solutions | "Merge conflicts in types.ts resolve at tier 3" |
| `failure` | What went wrong and why | "mock.module() leaks across test files" |
| `decision` | Architectural choices | "Use SQLite over file-based messaging" |
| `reference` | Pointers to docs/tools | "See mx-56558b for mock.module() issue" |
| `guide` | How-to instructions | "Adding a new runtime adapter" |

### Key Commands Used by Overstory

```bash
ml prime                      # Load all expertise at session start
ml prime --files src/foo.ts   # File-specific expertise
ml prime [domain]             # Domain-specific expertise
ml record <domain> --type <type> --description "..."
ml search <query>             # Search across domains
ml query <domain>             # Query a specific domain
ml learn                      # Discover what to record
ml sync                       # Sync with git
ml status                     # Domain health
```

### Integration Points

- **`ov prime`** — loads mulch expertise as part of session priming
- **`ov sling`** — pre-fetches file-specific expertise for agent overlays
- **Agent definitions** — all agents have mulch commands in their toolset
- **Merge resolver** — queries mulch for historical conflict patterns
- **Merge resolver** — records merge outcomes to mulch for future learning
- **Insight analyzer** — auto-records session insights to mulch
- **Builder completion** — builders record conventions and patterns discovered
- **Lead completion** — leads record orchestration insights

### The Mulch Client (`src/mulch/client.ts`)

Wraps the `@os-eco/mulch-cli` programmatic API for structured commands
and falls back to CLI subprocess calls for operations not yet in the API:

```typescript
interface MulchClient {
  prime(opts?): Promise<string>;
  record(domain, opts): Promise<void>;
  search(query, opts?): Promise<string>;
  status(): Promise<MulchStatus>;
  diff(opts?): Promise<MulchDiffResult>;
  learn(): Promise<MulchLearnResult>;
  prune(opts?): Promise<MulchPruneResult>;
  doctor(): Promise<MulchDoctorResult>;
  ready(): Promise<MulchReadyResult>;
  compact(opts?): Promise<MulchCompactResult>;
}
```

### Classification System

Records have three classification levels:
- **foundational** — core conventions confirmed across sessions
- **tactical** — session-specific patterns (default)
- **observational** — one-off findings, unverified

Agents are instructed to classify their records appropriately.

## Canopy (cn) — Versioned Prompt Management

Canopy manages prompt templates with inheritance, versioning, and
profile-based customization.

### What Canopy Provides

- **Versioned prompts** — each prompt has a version number
- **Inheritance** — prompts can extend parent prompts
- **Profiles** — named configurations (e.g., "production", "lightweight")
- **Sections** — prompts are composed of named sections
- **Emission** — rendered prompts can be emitted to files

### Key Commands Used by Overstory

```bash
cn prime                      # Load prompt workflow context
cn list                       # List all prompts
cn render <name>              # Render with inheritance resolved
cn emit --all                 # Render prompts to files
cn update <name>              # Update a prompt
cn sync                       # Stage and commit changes
```

### Integration Points

- **`ov sling --profile <name>`** — applies a canopy profile to the agent overlay
- **`ov prime`** — loads canopy context as part of session priming
- **Agent overlays** — `profileContent` field embeds rendered canopy prompts
- **Session tracking** — `promptVersion` on AgentSession tracks which prompt
  version was used (e.g., "builder@17")

### The Canopy Client (`src/canopy/client.ts`)

```typescript
interface CanopyClient {
  list(): Promise<CanopyListResult>;
  show(name: string): Promise<CanopyShowResult>;
  render(name: string): Promise<CanopyRenderResult>;
  validate(): Promise<CanopyValidateResult>;
  emit(opts?): Promise<void>;
}
```

### Profile Architecture

Canopy profiles add a **third layer** to agent instructions:

```
Layer 1: Base agent definition (agents/builder.md)     → HOW (capabilities, constraints)
Layer 2: Canopy profile (cn render builder --profile X) → WHAT KIND (project-specific tuning)
Layer 3: Dynamic overlay (ov sling)                     → WHAT (task ID, file scope, spec)
```

This three-layer model means the same builder agent can behave differently
for a React project vs a Go project vs a data pipeline — all without
changing the base definition or the overlay generator.

## Ecosystem Health (`ov ecosystem`)

Shows the status of all os-eco tools:

```bash
ov ecosystem          # Tool versions and health
ov ecosystem --json   # Machine-readable
```

Checks:
- Which tools are installed
- Version numbers
- Basic health status

## Bootstrap (`ov init`)

`ov init` sets up the `.overstory/` directory and optionally bootstraps
the ecosystem tools:

```bash
ov init --tools mulch,seeds,canopy   # Bootstrap specific tools
ov init --skip-mulch                 # Skip mulch bootstrap
ov init --skip-canopy                # Skip canopy bootstrap
ov init --skip-onboard               # Skip CLAUDE.md onboarding
```

## The Upgrade Story

Each tool upgrades independently:

```bash
ov upgrade                    # Upgrade overstory
ov upgrade --all              # Upgrade all 4 ecosystem tools
ov upgrade --check            # Compare versions without installing
```

## Design Philosophy

### Why Separate Tools?

The alternative was a monolith (like Gas Town's `gt` command). Separate tools
were chosen because:

1. **Independent evolution** — mulch can add features without touching overstory
2. **Optional adoption** — use seeds without mulch, use canopy without seeds
3. **Replaceable** — swap seeds for beads by changing one config value
4. **Smaller blast radius** — a bug in mulch doesn't break orchestration
5. **Team flexibility** — different team members can maintain different tools

### The Integration Tax

The downside: integration is done through subprocess calls and file conventions.
This means:
- Slower than in-process API calls
- More fragile (depends on CLI output format stability)
- Harder to test in isolation
- Configuration is spread across multiple tools

The bet: the modularity benefits outweigh the integration cost at this scale.
