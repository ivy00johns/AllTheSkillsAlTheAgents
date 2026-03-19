# 12 — Frontier Assessment

## What Is Genuinely Novel

### Overstory's Frontier Contributions

**1. The Orchestrator-Is-Your-Session Model**
No other system makes the user's interactive AI session the orchestrator.
Gas Town has a separate daemon. Codex has a separate orchestration layer.
The skills ecosystem relies on Claude's built-in Agent tool.

Overstory's approach means the orchestrator has the full power of Claude's
reasoning — it can adapt, improvise, and make nuanced decisions. It's not
a state machine following rules; it's a thinking agent with infrastructure
commands.

This is frontier because it eliminates the "orchestrator bottleneck" problem
where the coordinator has less intelligence than the agents it's coordinating.

**2. Nine Runtime Adapters with Mixed Fleets**
No other orchestration system supports 9 different AI coding runtimes
simultaneously. Gas Town is Claude-only. The skills ecosystem is Claude-first
with aspirational multi-runtime support.

Overstory can actually run Claude leads, Pi builders, Codex scouts, and
Gemini reviewers in the same build. The runtime abstraction is clean
enough that each adapter is ~200-400 lines.

This is frontier because it breaks vendor lock-in at the orchestration
level, not just the API level.

**3. Mulch-Informed Merge Resolution**
The merge system learns from history. Tiers that consistently fail for
certain file patterns are automatically skipped. Past successful
resolutions are injected into AI prompts. Conflict patterns are predicted
before merges begin.

No other system does this. Gas Town has formula-based merges but no
learning. The skills ecosystem doesn't address merging at all.

**4. Three-Layer Agent Persistence**
Identity (permanent) → Sandbox (persists across sessions) → Session
(ephemeral). Agent CVs accumulate expertise over time. Checkpoints
enable handoffs across sessions.

Gas Town has similar agent tracking but not the clean three-layer
separation. The skills ecosystem has no agent persistence.

### Skills Ecosystem's Frontier Contributions

**1. Contract-First Build Architecture**
The ~42% failure rate statistic for specification problems is the kind
of empirical insight that changes how you build systems. Machine-readable
contracts with 6 format templates, enforced at the orchestrator level,
with audit verification — this is mature engineering.

No other system has this level of contract discipline. Gas Town uses
Beads for task tracking but doesn't have machine-readable contracts.

**2. Self-Improving Skill Ecosystem**
The closed loop: skill-audit → skill-deep-review → skill-improvement-plan
→ skill-updater → re-audit. Skills get better over time, automatically.
Evaluation benchmarking with variance analysis measures whether changes
actually improved triggering accuracy.

No other system has skills that improve themselves. This is genuinely novel.

**3. Structured QA Gating with LLM-as-Judge**
The QA report schema with 5-dimension scoring, structured blockers with
severity levels, and gate rules that actually block the build — this is
more sophisticated than any other AI orchestration quality system.

The LLM-as-judge rubrics for automated quality assessment take this further:
an AI evaluates another AI's work using structured criteria.

**4. Progressive Disclosure for Context Efficiency**
The three-tier loading model (metadata → SKILL.md → references) is
elegant. Frontmatter uses ~100 tokens always. The full skill loads only
when triggered. Heavy reference material loads on demand.

This matters because context window is the scarcest resource in AI
orchestration. The skills ecosystem is unusually disciplined about this.

**5. The Platform Vision**
The product charter and system architecture documents describe something
no one has built: an evidence-native, policy-driven, runtime-neutral
software factory. The concepts — Work Graph Service, Policy Compiler,
Evidence Store, Router with Scorecards — are architecturally sound and
genuinely forward-looking.

## What Is Table Stakes

These are things any serious orchestration system must have. Having them
is necessary but not differentiating:

| Capability | Overstory | Skills | Status |
|------------|-----------|--------|--------|
| Git worktree isolation | Yes | Via Claude Code | Table stakes |
| Agent role specialization | Yes | Yes | Table stakes |
| File ownership | Yes | Yes | Table stakes |
| Quality gates | Yes (basic) | Yes (rich) | Table stakes |
| CLI interface | Yes | N/A (prompt-based) | Table stakes |
| Multi-model support | Yes | Partial | Table stakes |

## What the Combined System Could Become

### The Vision: An Operating System for Autonomous Software Delivery

Neither project alone achieves this. But combined:

**Layer 1: Intent Understanding (from Skills)**
- Brainstorming skill explores user intent
- Plan-builder creates structured plans
- Contract-author generates machine-readable specifications

**Layer 2: Policy Compilation (from Skills + Overstory)**
- File ownership maps (Skills) → guard rules (Overstory)
- Quality gate schemas (Skills) → hook enforcement (Overstory)
- Contract templates (Skills) → spec deployment (Overstory)
- Workflow discipline (Skills) → behavioral guards (Overstory)

**Layer 3: Intelligent Dispatch (from Overstory)**
- Multi-runtime selection based on task requirements
- Per-capability model routing
- Depth-limited hierarchy with configurable limits
- Staggered spawning for rate limit compliance

**Layer 4: Isolated Execution (from Overstory)**
- Git worktree per agent
- Tmux or headless subprocess per agent
- Runtime-specific guard deployment
- Mail-based coordination

**Layer 5: Quality Assurance (from Skills + Overstory)**
- Structured QA reports with dimensional scoring (Skills)
- Contract-auditor verification (Skills)
- Automated merge with 4-tier resolution (Overstory)
- Watchdog with AI triage (Overstory)
- Quality gate enforcement in hooks (Overstory)

**Layer 6: Organizational Learning (from Overstory + Skills)**
- Mulch expertise records from every session
- Merge pattern learning
- Skill self-improvement cycle
- Agent identity accumulation

**Layer 7: Operator Experience (from Platform Vision)**
- Control Plane API for programmatic access
- Operator Console for visual management
- Evidence Store for audit trail
- Run Ledger for analytics
- Router with worker scorecards

### What No One Has Seen

**1. Evidence-Native Development**
Every agent action produces evidence. Not assertions — evidence.
Screenshots, test results, contract diffs, review findings, merge
outcomes. The system doesn't trust "done" — it verifies.

Current state: Skills has the QA report schema. Overstory has the event
store. Neither captures evidence as a first-class object with links to
the work that produced it.

**2. Policy-Driven Agent Behavior**
Instead of relying on prompt engineering to make agents behave, compile
explicit policies from contracts, ownership maps, and quality requirements.
Agents can't violate policies because the infrastructure prevents it.

Current state: Overstory's guard rules are a primitive form of this.
Skills' file ownership maps are another. Neither has a general-purpose
policy compiler.

**3. Adaptive Quality Control**
Quality thresholds that adjust based on outcomes. If a builder consistently
passes QA, their work can be fast-tracked. If a builder consistently fails,
their scope is reduced. Worker scorecards drive routing decisions.

Current state: Overstory's mulch records patterns but doesn't use them
for routing. Skills' QE agent scores quality but doesn't feed back into
dispatch decisions.

**4. Cross-Runtime Optimization**
The right runtime for the right task. Claude for complex reasoning, Pi
for fast iteration, Codex for sandboxed execution, Gemini for multi-modal
tasks. The system learns which runtime is best for which task type.

Current state: Overstory supports mixed fleets but doesn't optimize
runtime selection. The config is static, not adaptive.

**5. Self-Healing Orchestration**
When something goes wrong, the system diagnoses and fixes itself. Not
just restarts — actual root cause analysis and corrective action.

Current state: Overstory's watchdog detects problems and the triage tier
classifies them. But corrective action is limited to nudge/escalate/terminate.
True self-healing would mean spawning a replacement builder with the
checkpoint context and a note about what went wrong.

## The Build Sequence

If we're building the combined system, the phases should be:

### Phase 1: Bridge
- Port Skills' contract system into Overstory's spec format
- Port Skills' QA schema into Overstory's quality gate system
- Port Skills' role metadata into Overstory's agent manifest

### Phase 2: Deepen
- Add evidence capture to Overstory's event store
- Add policy compilation to Overstory's guard system
- Add adaptive routing to Overstory's runtime selection

### Phase 3: Scale
- Build the Control Plane API
- Build the Operator Console
- Build the Evidence Store

### Phase 4: Learn
- Close the feedback loop: outcomes → mulch → skill improvement → better outcomes
- Add worker scorecards
- Add cross-runtime optimization

### Phase 5: Frontier
- Federation between control planes
- Self-healing orchestration
- Autonomous quality policy evolution

## The One-Line Summary

Overstory is the best infrastructure for running AI agent swarms.
AllTheSkillsAllTheAgents is the best prompt architecture for making those
agents smart. The combined system — with evidence, policies, and
adaptive learning — would be an operating system for autonomous software
delivery that no one has built.
