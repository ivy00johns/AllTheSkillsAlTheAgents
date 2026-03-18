# 12 — Frontier Assessment: "Not Production"

Steve Yegge's article makes it clear: **Gas Town is not production software.**
This document unpacks what that means, who it's for, and where it's going.

## What "Not Production" Means

### 1. It's 100% Vibe Coded

> "I've never seen the code, and I never care to."

377,251 lines of Go code, 6,457 commits — none of it reviewed by a human.
Steve describes this with the same casual confidence he applies to Beads
(225k LoC, "tens of thousands of people using every day"). The code works
because frontier models are good enough to produce working code at scale.
But "working" ≠ "reviewed" ≠ "production-grade."

### 2. The Codebase is Young

Gas Town (Go version) started December 14, 2025. The article was written
January 1, 2026 — 17 days in. As of March 2026, it's about 3 months old.
Features are being invented and implemented in days. The MEOW stack, wisps,
patrols, convoys, agents-as-beads, swarms-as-beads, the Refinery, the
Deacon, Dogs — all invented and shipped in 2-3 weeks.

### 3. It's Dangerous

> "Gas Town is an industrialized coding factory manned by superintelligent
> robot chimps, and when they feel like it, they can wreck your shit in an
> instant."

20-30 concurrent AI agents making changes to your codebase, merging to main,
and spawning more work. If something goes wrong, it goes wrong fast and at
scale. The system requires an experienced "chimp-wrangler" (Stage 7+).

### 4. It's Expensive

> "You won't like Gas Town if you ever have to think, even for a moment,
> about where money comes from."

Multiple Claude Code accounts, 20-30 concurrent Opus sessions, running
potentially 24/7. Steve projects needing a third account within a week of
launch. This is bleeding-edge infrastructure for people with unlimited
AI budgets.

### 5. It's Chaotic by Design

> "Some bugs get fixed 2 or 3 times, and someone has to pick the winner.
> Other fixes get lost. Designs go missing and need to be redone."

Gas Town optimizes for **throughput**, not efficiency. The philosophy is:
ship more work, accept some waste, correct as you go. This is fundamentally
different from traditional software engineering's focus on correctness
and predictability.

## Who Gas Town IS For

### The Stage 7-8 Developer

Someone who:
- Already juggles 5+ Claude Code instances daily
- Has committed to vibe coding as a methodology
- Treats themselves as a Product Manager, not an engineer
- Can afford unlimited AI API costs
- Is comfortable with tmux
- Can tolerate chaos and occasional breakage
- Wants to "fly" rather than be precise

### The Builder of Builder Tools

Gas Town's real audience may be other tool builders who will:
- Study its architecture (MEOW, GUPP, NDI)
- Build more accessible versions of its concepts
- Create UIs that make it approachable
- Integrate its patterns into existing tools

## What Gas Town Gets Right (Even as Not-Production)

### 1. Persistent Agent Identity

Separating agent identity from session lifecycle is a genuine insight.
The Beads-backed identity system means work attribution, CV chains, and
learning persist across session boundaries.

### 2. Durable Workflows

The MEOW stack solves a real problem: LLM sessions crash, contexts fill,
models get confused. Externalizing workflow state into Git-backed beads
makes work survive any individual session failure.

### 3. The Merge Queue Problem

Any multi-agent system that modifies code hits the merge conflict problem.
The Refinery's batch-then-bisect approach is a proven strategy (Bors,
GitHub merge queues) applied to AI-generated code.

### 4. Hierarchical Supervision

The Deacon → Witness → Polecat supervision hierarchy addresses the real
problem of agents getting stuck. The heartbeat cascade and nudge system
creates self-healing behavior.

### 5. Graceful Degradation

Gas Town works with 1 agent or 30. With tmux or without. With the full
patrol system or just manual slinging. This makes it practically useful
at every stage of adoption.

## Where Gas Town is Going

### Near-Term (2026)

From the article and codebase:

- **Federation** — remote workers on hyperscalers (GCP, AWS)
- **The Wasteland** — already implemented: DoltHub-backed federated work
  marketplace with reputation stamps
- **Plugins** — infrastructure is in place, formulas in the Mol Mall
- **The Mol Mall** — marketplace for workflow formulas
- **Better UIs** — Emacs, web, mobile
- **Multi-runtime** — already supports Claude, Codex, Gemini, Cursor, etc.

### Three Scaling Dimensions

Steve identifies three dimensions Gas Town will improve on:

1. **Model cognition** — smarter models = more reliable GUPP, better NDI
2. **Agent friendliness** — coding agents becoming more Gas Town-aware
3. **Training corpus** — Gas Town and Beads getting into frontier model
   training data, creating a virtuous cycle

### The Bigger Vision

Gas Town isn't trying to be Kubernetes or Temporal. It's building toward
a world where:

- **Work is molecular** — decomposable, composable, durable
- **Agents are persistent** — identities with track records
- **Reputation is portable** — the Wasteland's stamp system
- **AI orchestrates AI** — humans design, agents execute
- **Throughput beats precision** — move fast, fix things, keep flying

## The Honest Assessment

Gas Town is simultaneously:

- **Visionary** — it correctly identifies that multi-agent orchestration is
  the next layer above coding agents, and builds it
- **Premature** — it requires frontier-level expertise and budget that
  excludes 99% of developers
- **Prophetic** — many of its patterns (persistent identity, durable
  workflows, merge queues, supervision hierarchies) will become standard
- **Fragile** — 100% vibe coded, 3 months old, chaos-tolerant by design

The article's warnings are genuine. Gas Town is a research prototype
disguised as a tool, built by one person pushing the absolute frontier of
what's possible with AI-assisted development. It works — but only for the
person who built it and people who think exactly like him.

The real value may not be Gas Town itself but the concepts it proves out:
MEOW, GUPP, NDI, the Wasteland, molecular work, persistent agent identity.
These ideas will outlive the specific implementation.

> "Gas Town itself may not live longer than 12 months, but the bones of
> Gas Town — the MEOW stack — may live on for several years to come."
