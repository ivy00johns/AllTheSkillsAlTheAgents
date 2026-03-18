# 11 — gstack vs gastown + beads

## The Fundamental Difference

**gstack** answers: *How should an agent think about code?*
**gastown** answers: *How do you run 30 agents at once?*
**beads** answers: *How do you track work that outlives any single agent?*

These are orthogonal problems. That's why combining them is so powerful.

## What gstack Has That gastown Doesn't

### 1. Browser Interaction
gastown manages agents. gstack's agents can actually *use* the app:
- Navigate pages, fill forms, click buttons
- Take screenshots for evidence
- Verify visual design quality
- Import cookies for authenticated testing
- 50+ commands at ~100ms latency

gastown's agents are blind — they can read code but can't see the UI.

### 2. Cognitive Review Patterns
gastown follows ZFC (Zero Framework Cognition) — "agents decide, Go transports."
But it doesn't tell agents HOW to decide. gstack provides 41 thinking frameworks
that activate specific analytical perspectives.

gastown's agents think however they think. gstack's agents think like
Bezos, Rams, or Kernighan — deliberately.

### 3. Design Intelligence
gastown has no concept of visual design quality. gstack has:
- 80-item design audit
- AI slop detection (10 patterns)
- Design system inference from live sites
- DESIGN.md export
- Design regression tracking

### 4. Eval System for Skills
gastown tests its Go code with standard Go tests. gstack tests its
*agent behavior* with E2E evals, LLM-as-judge, and planted-bug fixtures.
This is a fundamentally different kind of testing — validating that
prompt-driven workflows produce correct outcomes.

### 5. Template-Driven Accuracy
gstack's skills are generated from source code metadata. gastown's agent
templates are static Markdown. When gastown adds a new `gt` command, the
agent instructions don't automatically update.

### 6. Shipping Pipeline
`/ship` is a complete workflow: test → version → changelog → commit → push → PR.
gastown has the Refinery (merge queue) but no equivalent integrated
release pipeline.

## What gastown Has That gstack Doesn't

### 1. Multi-Agent Orchestration at Scale
gastown manages 20–50+ agents simultaneously:
- Persistent agent identity (CVs, work history)
- Three-layer model (Identity → Sandbox → Session)
- Tmux session management
- Cross-rig coordination

gstack runs exactly one agent at a time.

### 2. Persistent Work Tracking (via beads)
- Dependency graphs with 5 relationship types
- Hash-based IDs (zero merge conflicts)
- Distributed sync via Dolt
- Semantic compaction for context management
- Gates for async coordination

gstack has review dashboard persistence but no task/issue tracking.

### 3. Agent Lifecycle Management
- Spawn, monitor, nudge, handoff, seance (query past sessions)
- Stuck-agent detection (GUPP violations)
- Automatic recovery (Witness, Deacon)
- `gt feed` TUI for real-time monitoring
- Web dashboard for overview

gstack has no lifecycle management — its single agent just runs.

### 4. Merge Queue (Refinery)
When 5 agents are writing code in parallel, someone has to merge their work:
- Conflict detection and resolution
- Quality verification
- Integration branch management

gstack doesn't need this — single agent, no conflicts.

### 5. Multi-Runtime Support
gastown works with Claude, Gemini, Codex, Cursor, and 6 more runtimes.
gstack is Claude Code only.

### 6. Plugin Ecosystem
gastown has plugins for infrastructure tasks:
- compactor-dog (Dolt maintenance)
- github-sheriff (PR categorization)
- git-hygiene (repo cleanup)
- stuck-agent-dog (stuck agent detection)

gstack has no plugin system.

### 7. Communication Infrastructure
- Mail system (persistent, cross-session)
- Nudges (immediate, tmux-injected)
- Convoys (work order batching)
- ACP (Agent Client Protocol)

gstack's single agent doesn't need communication.

## What beads Has That gstack Doesn't

### 1. Dependency Graphs
5 relationship types: blocks, parent-child, discovered-from, related,
conditional-blocks. gstack has no concept of task dependencies.

### 2. Ready Queue
`bd ready` shows unblocked work. When task A's blocker completes,
task A automatically appears in the ready queue. gstack has no
equivalent — it doesn't track tasks.

### 3. Semantic Compaction
`bd compact` generates Haiku summaries of old work, freeing context
while preserving meaning. gstack's only context management is the
review dashboard.

### 4. Distributed Sync
`bd dolt push/pull` syncs work across machines, teams, and time.
gstack's state is local to `~/.gstack/`.

### 5. Workflow Templates (Formulas/Molecules)
Declarative TOML workflows with steps, variables, gates, and composition.
gstack's workflows are hardcoded in SKILL.md templates.

### 6. Gates
Block work on human approval, timers, or GitHub events.
gstack has review gates but they're simple pass/fail, not async coordination.

## The Synergy Map

```
gastown (orchestration)
  ├── Manages 20-50+ agents
  ├── Each agent could run gstack skills:
  │   ├── /review for code review
  │   ├── /qa for browser testing
  │   ├── /plan-design-review for design audit
  │   └── /ship for release
  ├── Polecats with browse CLI = agents that can SEE
  └── Refinery validates with /review before merging

beads (persistence)
  ├── Tracks all work as dependency graph
  ├── gstack /ship creates beads for tracking
  ├── gstack /qa findings become beads
  ├── gstack /review issues become beads
  ├── Semantic compaction preserves review history
  └── Gates coordinate between review phases

gstack (intelligence)
  ├── Provides cognitive patterns for all agent decisions
  ├── Browser CLI gives agents eyes
  ├── Eval system validates agent behavior
  ├── Design intelligence detects quality issues
  └── Completeness principle guides scope decisions
```

## What the Combined System Looks Like

**The Mayor** orchestrates work distribution using beads.
**Polecats** run with gstack skills loaded — they can browse, review, QA.
**The Refinery** runs `/review` before merging agent work.
**The Witness** monitors polecat health and nudges stalled reviews.
**Beads** tracks every review finding, design issue, and QA bug as a
dependency-aware work item that persists across sessions.
**Eval system** validates that the entire pipeline produces correct outcomes.

No one has built this. Each system is powerful alone. Combined, they're
an autonomous software engineering organization.
