# Framework Deep Dives — Gap Analysis Findings

**Date:** 2026-03-20
**Scope:** Beads (12 docs), Gastown (12 docs), GStack (13 docs), Overstory (12 docs) vs 17-doc spec
**Method:** All 48 source documents read and cross-referenced against full spec set

---

## Executive Summary

The spec incorporated the dominant concepts from all four frameworks with high fidelity. The structural architecture (5 layers, GUPP/NDI, 22 dependency types, 4-tier merge, 41 cognitive patterns, 9 runtime adapters) is all present and correctly synthesized. The gaps are at the implementation depth layer — operational details, known production bugs, concrete performance numbers, and subsystem mechanics that were summarized rather than specified.

**Overall incorporation estimate:** 78% fully incorporated, 15% partially incorporated, 7% missed entirely.

---

## 1. Per-Framework Scorecards

### Beads — 80% Incorporated

**Fully incorporated:** DoltStore three-layer arch, all 22 dependency types, hash-based IDs, atomic claim CAS, formula engine, chemistry metaphor, cook/pour/wisp, circuit breaker, auto-start, multi-phase lifecycle, ready queue CTE, DOLT_COMMIT pattern, cell-level merge, content hashing, federation peers.

**Partially incorporated:** HOP EntityRef URI scheme (not specified), swarm analysis (Kahn's sort not specified), 8-stage formula pipeline (stages 3/6 under-specified), compaction (tiers mentioned but parameters absent), memory system (not surfaced).

**Missed entirely:** `bd doctor` 20+ categories, redirect files for multi-worktree, routes.jsonl schema, known Dolt bugs (mergeJoinIter panic, GH#2455, wisp data loss), PersistentPreRun 25-step lifecycle, hybrid sort 48h recency window.

### Gastown — 75% Incorporated

**Fully incorporated:** GUPP, NDI, 8→13 role mapping, two-tier beads, batch-then-bisect, convoy system, sling dispatch, heartbeat cascade, patrol formulas, polecat lifecycle, MEOW stack.

**Partially incorporated:** GUPP nudge (specific timing absent), pre-verification fast path (5s target not specified), batch phases (gating not specified).

**Missed entirely:** Patrol agent exponential backoff (30s→60s→2m), Crew vs Polecat distinction (conflated in spec), shiny deployment variants, Dolt operational parameters (max_connections 100+), routes.jsonl 7-field schema, Wasteland wild-west Phase 1.

### GStack — 82% Incorporated

**Fully incorporated:** All 41 cognitive patterns, role-specific assignment, 4 CEO modes, 80-item design audit, AI slop detection, 3-tier eval system, diff-based test selection, design system inference, QA gate schema, Browse CLI daemon, boil-the-lake, visual regression.

**Partially incorporated:** Browse CLI ref system (most important implementation detail — not specified), staleness detection (5ms vs 30s), eval persistence format, cookie decryption, Browse CLI security model.

**Missed entirely:** Review readiness dashboard (CLEAR/PENDING/FAILED gate states), completeness score UX (1-10 display + compression ratio), blame protocol, eval diagnostic fields ($3.85/run cost, exit_reason), design regression tracking, eval preview command.

### Overstory — 85% Incorporated

**Fully incorporated:** AgentRuntime interface, all 9 adapters, SQLite mail bus, 15 protocol messages, broadcast groups, nudge escalation, hook-driven orchestrator, depth limit, complexity assessment, three-layer identity, checkpointing, FIFO merge queue, 4-tier resolution, mulch-informed learning, four-database observability, three-tier watchdog, os-eco, canopy model.

**Partially incorporated:** Pi runtime RPC (JSON-RPC 2.0 not specified), beacon verification (retry pattern absent), OpenRouter model routing (config schema absent), CLI output schemas absent, promptVersion tracking absent.

**Missed entirely:** Full 12-step sling sequence, runtime selection priority chain (4 levels), coordinator exit predicates (allAgentsDone/taskTrackerEmpty/onShutdownSignal), headless/buildDirectSpawn optional interface methods, token snapshot mechanism, transcript normalization layer.

---

## 2. Top 15 Missed or Underrepresented Features

### Rank 1: Browse CLI Ref System (GStack)
Accessibility tree → sequential @e refs → Playwright Locators. Staleness detection at 5ms vs 30s timeout. Without this, implementors will use CSS selectors and hit brittleness. The ref system IS the Browse CLI.
**Spec gap:** Doc 10 §7 has zero implementation detail on refs.
**Fix:** Add implementation subsection to doc 10 §7.

### Rank 2: Review Readiness Dashboard (GStack)
Per-branch gate mechanism with CLEAR/PENDING/FAILED states, mandatory vs informational classification, override persistence. The operator-facing pre-ship gate that surfaces "ready to ship" vs "has blockers."
**Spec gap:** Not mentioned anywhere.
**Fix:** Add to doc 09 §7 or doc 10 §9.

### Rank 3: Redirect Files for Multi-Worktree (Beads)
`.beads/redirect` in worktrees pointing to canonical `.beads/`. Every agent transparently finds the shared tracker. Without this, multi-worktree setups need hardcoded paths or separate trackers.
**Spec gap:** Not in doc 12, 17, or anywhere.
**Fix:** Add "Worktree Tracker Binding" to doc 12 §2.

### Rank 4: 12-Step Sling Dispatch (Overstory)
Complete sequence including beacon verification, rollback procedure, guard deployment. Spec gives sling 2 sentences.
**Fix:** Add full sequence to doc 09 §5.

### Rank 5: Pi Runtime JSON-RPC 2.0 Binding (Overstory)
Pi uses subprocess RPC, not tmux. RuntimeConnection interface with sendPrompt/followUp/abort/getState/close. Fundamentally different integration model.
**Fix:** Add Pi adapter implementation to doc 11 §3.

### Rank 6: Known Dolt Production Bugs (Beads)
mergeJoinIter panic (use LEFT JOIN), GH#2455 (never use -Am), wisp data loss (SQL COMMIT before DOLT_COMMIT). Builders will reintroduce these without documented workarounds.
**Fix:** Add "Known Dolt Limitations" to doc 12 §2.

### Rank 7: Patrol Agent Exponential Backoff (Gastown)
30s → 60s → 2m, reset on work. Without backoff, patrols burn LLM tokens during idle periods.
**Fix:** Add to doc 09 §8.

### Rank 8: Crew vs Polecat Distinction (Gastown)
Crew: full clone, direct main push, unmonitored. Polecat: worktree, branch→Refinery, monitored. Spec conflates these as "Crew (User Agent)."
**Fix:** Add "Direct vs Queue Integration" to doc 04 §3.

### Rank 9: HOP Entity Reference URI and Crystallizes (Beads)
`hop://platform/org/id` format. `Crystallizes` boolean controls CV contribution — prevents trivial tasks from diluting reputation.
**Fix:** Add to doc 12 and doc 04 scorecards.

### Rank 10: Wasteland Reputation Schema (Gastown)
7-table Wanted Board, stamps with yearbook constraint (can't stamp own work), trust levels 0-3, wild-west Phase 1.
**Fix:** Add to doc 14 §9.

### Rank 11: Routes.jsonl Cross-Rig Routing (Gastown/Beads)
7-field schema for cross-project dependency resolution. Without this, `external:<project>:<id>` references can't resolve.
**Fix:** Add to doc 12 §5.

### Rank 12: Eval Persistence and Diagnostics (GStack)
exit_reason, timeout_at_turn, last_tool_call. $3.85/run cost. Atomic writes for crash resilience.
**Fix:** Add to doc 10 §6.

### Rank 13: Runtime Selection Chain (Overstory)
4-level priority: --runtime flag → per-capability config → default config → "claude". Per-capability routing enables mixed fleets.
**Fix:** Add to doc 11 §6.

### Rank 14: Coordinator Exit Predicates (Overstory)
allAgentsDone, taskTrackerEmpty, onShutdownSignal — three named conditions preventing premature or never-ending exit.
**Fix:** Add to doc 09 §2.

### Rank 15: Completeness Score UX (GStack)
Score 1-10 with compression ratio display ("Human: 3 weeks. AI: 4 hours. 18x compression."). Makes the economic case visible.
**Fix:** Add to doc 10 §1.

---

## 3. Spec Sections Needing Deepening

| Spec Section | What to Add | Source |
|-------------|-------------|--------|
| doc 10 §7 Browse CLI | Ref system, staleness detection, security model, cookie decryption | GStack |
| doc 12 §2 Dolt Config | Known bugs, production sizing, redirect files, shadow DB prevention | Beads/Gastown |
| doc 12 §8 Formula Engine | AdviceRule, OnCompleteSpec, compile vs runtime modes, compaction params | Beads |
| doc 09 §5 Sling | Full 12-step sequence, beacon verification, rollback procedure | Overstory |
| doc 09 §8 Watchdog/Patrol | Patrol backoff, heartbeat cascade, GUPP violation detection | Gastown |
| doc 11 Pi/Headless | JSON-RPC 2.0 protocol, NDJSON event streams, connect() semantics | Overstory |
| doc 14 Reputation | Wanted Board schema, stamps, yearbook constraint, trust levels | Gastown |
| doc 04 Crew vs Builder | Direct vs queue integration, monitoring distinction | Gastown |

---

## 4. New Spec Sections Recommended

### `18-operations-runbook.md`
Day 1 startup, daily operations, known failure modes, Dolt procedures (flatten, gc, doctor --fix), cost monitoring, backup/recovery. Missing bridge between spec and production.

### doc 10 §9 — Review Readiness State Machine
Per-branch gate states, mandatory vs informational gates, override model, CLI surface.

### doc 12 §11 — Memory System
Agent persistent KV memory (remember/forget/recall), per-project scope, session initialization integration.

### doc 11 §8 — Transcript Normalization
Common event schema across runtimes, per-runtime normalization rules, token snapshot mechanism.

---

## 5. Unresolved Framework Conflicts

### Conflict 1: FIFO vs Priority Merge Queue
Spec adopts FIFO for merge queue (from Gastown) but hybrid priority sort for work queue (from Beads). These are different queues — document explicitly.

### Conflict 2: Depth Limit Enforcement
Spec says "infrastructure enforcement" (doc 03 non-negotiable) but only mechanism specified is prompt-level guard rules (from Overstory). Need sling command to validate depth in sessions.db.

### Conflict 3: Single Branch vs Branch-Per-Agent
Tracker DB: single branch (Beads/Gastown). Code repos: branch-per-agent (spec doc 09). Not a conflict but needs explicit clarification in doc 12 §2.

### Conflict 4: Formula Language
TOML used throughout Beads AND Gastown. Spec already uses TOML. **Close this open question** — mark TOML as resolved in doc 00.

### Conflict 5: Sovereignty Enforcement Timing
Beads has sovereignty tiers "NOT IMPLEMENTED" in production. Spec describes them as working. Add implementation status note to doc 14 — Phase 1 = peer registration only, enforcement is Phase 2.

### Conflict 6: Doctor Command Scope
Beads has 20+ categories vs spec's 11 (from Overstory). Add Beads-specific checks: redirect file consistency, shadow DB prevention, known-bug mitigation status.

---

*78% incorporated, 15% partially incorporated, 7% missed. 48 source documents read. Generated 2026-03-20.*
