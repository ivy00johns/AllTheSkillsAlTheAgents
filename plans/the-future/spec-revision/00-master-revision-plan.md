# Master Spec Revision Plan — The Hive

**Date:** 2026-03-20
**Branch:** `spec/revision-sprint-2026-03-20`
**Build target:** `~/AI/The-Hive`
**Inputs:** 6 research agent findings (01-06), ~70K lines of documentation consumed

---

## Executive Summary

Six parallel research agents consumed the entire documentation corpus (~70K lines across 100+ documents) and cross-referenced it against the 17-document spec. The spec is architecturally sound — 78% of source framework features were correctly incorporated. But it has **critical missing layers** that must be added before building:

1. **No API surface** — the spec is CLI-only but the dashboard needs HTTP/SSE/WebSocket
2. **No UI/frontend spec** — The Glass is a core differentiator with zero specification
3. **No cost enforcement** — `max_budget_cents` exists but nothing enforces it
4. **No agent credentials** — lifecycle states exist but crypto identity doesn't
5. **Spec vs scaffold diverge** — local monolith (spec) vs hosted microservices (scaffold), 2.4/5 alignment

---

## New Documents Needed

All 6 agents independently converged on the same core gaps. Here are the new spec documents needed, with unanimous or near-unanimous support:

### Doc 18 — API Layer Specification (ALL 6 agents agree)

**Why:** The spec defines only CLI commands. The dashboard requires REST endpoints, SSE streaming, and WebSocket terminals. Mission Control proves 83+ endpoints are needed at production scale.

**Contents:**
- Complete REST endpoint catalog (builds, agents, approvals, files, contracts, metrics, layouts)
- SSE event stream design (`/api/events`) with AG-UI protocol normalization
- WebSocket terminal protocol (`/api/terminal/:agentId`)
- Authentication: session cookies + agent API keys + system API keys (three principals)
- RBAC: viewer / operator / admin / fleet_admin hierarchy
- Rate limiting: login (5/min critical) / mutation (60/min) / heavy (10/min) / read (120/min)
- Error envelope: `{ data, meta, errors }`
- OpenAPI 3.1 contract (self-documenting via the spec's own contract system)
- Relationship between HTTP API and CLI commands

### Doc 19 — UI Layer Specification (Dashboard + Gap-5 agents agree)

**Why:** The Glass is listed as one of eight core differentiators but has zero specification. The Agentic UI Dashboard plan (19K lines) exists separately but is disconnected from the core spec.

**Contents:**
- Tauri v2 application structure (Rust backend + React frontend)
- Block/tile registry (Wave Terminal pattern) with 11 block types
- AG-UI protocol adoption: event type mapping, multi-agent routing
- State management: Zustand (global) + Jotai (per-block)
- SSE + REST + WebSocket hybrid protocol split
- Performance budgets: 60 FPS at 50 DAG nodes, 4 visible terminals at 30 FPS, 50ms SSE batching
- The Hive naming mapping (The Yard, The Glass, The Comb, The Keeper, etc.)
- SQLite schema for UI persistence (layouts, block state, approval history)
- Plugin architecture (8 swappable slots)

### Doc 20 — Security Hardening (MC + Gap-3 agents)

**Why:** Security is scattered across docs 03, 05, 09, 13. MC built its security iteratively and regrets it. A unified document prevents the same retrofitting.

**Contents:**
- EdDSA JWT agent identity (from Gap-3)
- scrypt password hashing, session tokens, CSRF protection
- API rate limiting, security headers, host allowlists
- Skill supply chain security (Sigstore, static analysis, Lethal Trifecta)
- Per-agent API keys with SHA-256 hashed storage
- Audit log requirements

### Doc 21 — Operations Runbook (Framework Dives agent)

**Why:** The spec has a Build Program and Repo Bootstrap but nothing for running the system. Every production incident from Beads becomes a procedure here.

**Contents:**
- Day 1 startup sequence, daily operations
- Known Dolt bugs and workarounds (GH#2455, mergeJoinIter panic)
- Patrol agent management, compaction scheduling
- Cost monitoring and budget alerts
- Backup/recovery procedures

---

## Existing Document Updates

### P0 — Must Fix Before Any Code

| Document | Issue | Fix |
|----------|-------|-----|
| doc 05 + doc 12 | Column name `body` vs `description` | Pick one, update both + types.ts |
| doc 14 + doc 16 | Sovereignty tier count (3 vs 4) | Add T4 to doc 14 or remove from doc 16 |
| doc 02 + doc 05b | Naming candidates diverge (different 5 themes) | Update 05b to reference doc 02's final set |
| doc 01 | Three broken doc number references | Fix refs: 02→03, 03→16, 04→17 |
| doc 00 | Close formula language question | Mark TOML as resolved (both Beads and Gastown use it) |

### P1 — Before Phase 2 Implementation

| Document | Section | What to Add | Source |
|----------|---------|-------------|--------|
| doc 03 | §3 Data Stores | Valkey Streams as The Airway implementation | Gap-6 |
| doc 03 | §3 Data Stores | Storage adapter pattern (abstract from day 1) | Codex |
| doc 03 | New: Policy Fabric | Name the contract/ownership/gate layer explicitly | Codex |
| doc 04 | §3 or new § | Agent Credential Lifecycle (EdDSA JWT, 7-step spawn) | Gap-3 |
| doc 04 | §3 | Crew vs Polecat distinction (direct vs queue integration) | Gastown |
| doc 05 | New § | pgvector for Honey (semantic memory) | Gap-6 |
| doc 05 | Schema | Add `outcome`, `error_summary`, `retry_count`, `completed_at`, `crystallizes` | MC + Beads |
| doc 06 | §4 | Séance handoff protocol | Gastown |
| doc 06 | § | Mail delivery guarantees (at-least-once vs best-effort) | Spec baseline |
| doc 08 | New § | Security and Provenance (Sigstore, static analysis, Lethal Trifecta) | Gap-4 |
| doc 08 | § | Cognitive pattern YAML format (undefined in both doc 08 and doc 10) | Spec baseline |
| doc 09 | §2 | Coordinator exit predicates (allAgentsDone, taskTrackerEmpty, onShutdownSignal) | Overstory |
| doc 09 | §5 | Full 12-step sling dispatch sequence with beacon verification | Overstory |
| doc 09 | §7 | CI failure injection pattern (84.6% self-correction) | Composio AO |
| doc 09 | §8 | Patrol backoff (30s→60s→2m), heartbeat cascade | Gastown |
| doc 09 | §8 | Depth limit infrastructure enforcement (not just prompt-level) | Framework conflict |
| doc 09 | New § | Interrupt/resume protocol for QA gates (async, not sync) | Dashboard |
| doc 09 | New § | HTTP server as parallel output channel alongside CLI | Dashboard |
| doc 09 | New § | Workload signals (normal/throttle/shed/pause) | MC |
| doc 09 | New § | Decomposition algorithm / heuristics for Plan phase | Spec baseline |
| doc 10 | §1 | Completeness score UX (1-10 + compression ratio) | GStack |
| doc 10 | §6 | Eval diagnostic fields ($3.85/run, exit_reason, last_tool_call) | GStack |
| doc 10 | §7 | Browse CLI ref system (accessibility tree → @e refs → Locators) | GStack |
| doc 10 | New § | Review readiness state machine (CLEAR/PENDING/FAILED) | GStack |
| doc 10 | New § | Platform Test Architecture (5-layer pyramid, pass^k, golden datasets) | Gap-7 |
| doc 10 | New § | Regression detection (baseline/post comparison) | MC |
| doc 10 | New § | Approval interrupt lifecycle (PendingApproval schema) | Dashboard |
| doc 11 | §3 | Pi runtime JSON-RPC 2.0 binding | Overstory |
| doc 11 | §6 | Runtime selection priority chain (4 levels) | Overstory |
| doc 11 | § | MCP security notes (CVE-2025-6514, pin mcp-remote ≥0.1.16) | Gap-4 |
| doc 11 | § | No-runtime-detected fallback behavior | Spec baseline |
| doc 11 | New § | Transcript normalization across runtimes | Overstory |
| doc 12 | §2 | Known Dolt limitations (3 bugs with GH numbers + workarounds) | Beads |
| doc 12 | §2 | Redirect files for multi-worktree tracker binding | Beads |
| doc 12 | §4 | 5-attempt retry loop on atomic claim | MC |
| doc 12 | §5 | Cross-project dependency resolution (routes.jsonl schema) | Beads/Gastown |
| doc 12 | §8 | AdviceRule, OnCompleteSpec, compile vs runtime modes, compaction params | Beads |
| doc 12 | New § | Memory system (remember/forget/recall KV store) | Beads |
| doc 13 | New § | Cost Enforcement Layer (LiteLLM proxy, model routing, spend alerts) | Gap-2 |
| doc 13 | New § | Database Scaling Inflection Points (SQLite→ClickHouse trigger) | Gap-6 |
| doc 13 | New § | Trajectory anti-pattern detection (retry spirals, infinite loops) | Gap-7 |
| doc 13 | New § | Push delivery (SSE event bus) alongside pull queries | Dashboard |
| doc 13 | New § | Per-agent terminal buffer spec | Dashboard |
| doc 13 | § | Data retention policy (activities 90d, audit 365d, logs 30d) | MC |
| doc 13 | § | Per-task token cost attribution (add task_id to metrics.db) | MC |
| doc 13 | § | AG-UI event translation layer | Dashboard |
| doc 14 | New § | Distributed reputation (Wanted Board schema, stamps, yearbook) | Gastown |
| doc 14 | § | Sovereignty enforcement timing (Phase 1 = registration only) | Beads/Framework |
| doc 15 | New § | Runtime file ownership registry (live filePath→agentId map) | Dashboard |
| doc 15 | § | Contract distribution mechanism (how contracts reach worktrees) | Spec baseline |
| doc 15 | § | Rate limiting as part of API contract | MC |

### P2 — Build Program Revisions

| Update | Detail |
|--------|--------|
| Add dashboard parallel track | Starts after spec Phase 2, 8 phases, converges at Phase 6 |
| Add HTTP server to Phase 2 | SSE endpoint + REST stubs alongside CLI |
| Add approval interrupt to Phase 3 | Agent suspension at QA gate, resume on decision |
| Add evaluation harness to Phase 1 | Golden datasets, Vitest patterns, trajectory eval |
| Add RBAC to Phase 6 | Viewer/Operator/Admin enforcement at HTTP layer |
| Add Tauri build pipeline to Phase 6 | Cargo + Vite build |
| Add build/wrap annotations | Per-deliverable: building from scratch / wrapping / extracting |
| Add operational cost estimates | Distinguish build costs ($280-550) from operational costs ($2,200-4,400/mo) |
| Update types.ts | Add RunLedgerEntry, WorkerScorecard, EvidenceRecord |

---

## Architecture Decisions to Resolve

These require human decision before proceeding:

### 1. Local-First Monolith vs Service-Hosted Architecture
**Spec says:** TypeScript/Bun monolith, Dolt + SQLite, tmux agents, local developer machine
**Scaffold says:** Go + TypeScript microservices, Postgres + NATS + MinIO + ClickHouse, Docker
**Alignment:** 2.4/5
**Decision needed:** Pick one and rewrite doc 17 (or the scaffold) to match. Both are defensible.

### 2. Single Process vs Two Processes for Dashboard
**Spec says:** CLI-only TypeScript/Bun process
**Dashboard says:** Rust/Tauri backend + React frontend as separate process
**Options:** (a) Rust wraps TypeScript, (b) Rust replaces process spawning, (c) TypeScript serves HTTP directly
**Recommendation:** Option (c) — add `platform serve` command, simplest path

### 3. AG-UI as Internal or External Protocol
**Spec says:** Custom event types in events.db
**Dashboard says:** AG-UI (17 event types, adopted by Google/LangChain/AWS/Microsoft)
**Options:** (a) AG-UI replaces internal events (rewrite doc 13), (b) Translation layer between internal and AG-UI
**Recommendation:** Option (b) — keep internal events, add AG-UI adapter for dashboard consumption

### 4. Platform Name
**Current:** 5 candidates scored in doc 02, no final pick. "Hive" scores highest on memorability.
**Research:** project-names.md and doc 02 both converge on "Hive." Build target is already `~/AI/The-Hive`.
**Recommendation:** Close this. It's The Hive.

### 5. SQLite Ownership Model for Dashboard
**Spec has:** sessions.db, events.db, metrics.db, mail.db
**Dashboard needs:** block state, layouts, approval history
**Options:** (a) Dashboard reads spec's DBs + own UI DB, (b) Spec's DBs extended with UI tables, (c) Dashboard maintains synced copy
**Recommendation:** Option (a) — clean separation, UI DB is additive

---

## Vocabulary Fixes

| Issue | Fix |
|-------|-----|
| The Comb = task graph AND shared memory | Disambiguate: The Comb = memory system, The Frame = task structure |
| Dashboard uses generic terms, spec uses Hive names | Align block types to Hive naming once doc 02 is resolved |
| doc 05b naming candidates stale | Mark as superseded by doc 02 |

---

## Revision Execution Plan

### Wave 1: P0 Fixes + Architecture Decisions (This Session)
- Fix 5 P0 cross-reference issues
- Resolve the 5 architecture decisions above
- Create doc 18 (API Layer) outline
- Create doc 19 (UI Layer) outline

### Wave 2: New Documents (Next Session)
- Write doc 18: API Layer Specification
- Write doc 19: UI Layer Specification
- Write doc 20: Security Hardening
- Write doc 21: Operations Runbook

### Wave 3: Existing Doc Enrichment (Parallel Agents)
- Deploy 6-8 agents to update existing docs with the ~50 enrichment items above
- Each agent owns 2-3 documents
- Contract: each update includes source attribution

### Wave 4: Build Program Revision
- Rewrite doc 16 with dashboard parallel track
- Update doc 17 with revised repo bootstrap
- Update doc 00 with new document map

---

## Research Agent Findings Files

| File | Agent | Lines | Key Finding |
|------|-------|-------|-------------|
| `01-spec-baseline-analysis.md` | Spec Baseline | ~500 | 3 P0 blockers, 5 P1 gaps, 8 cross-ref issues |
| `02-mission-control-findings.md` | Mission Control | ~400 | 10 patterns to steal, 4 new docs, 4 conflicts resolved |
| `03-ui-dashboard-findings.md` | UI Dashboard | ~500 | 5 critical gaps, 7 new subsystems, 5 arch decisions |
| `04-gap-research-findings.md` | Gap Research | ~400 | 6/8 gaps partially resolved, 2 critical (UI + DB) |
| `05-framework-dives-findings.md` | Framework Dives | ~400 | 78% incorporated, 15 missed features ranked, 6 conflicts |
| `06-codex-platform-findings.md` | Codex + Platform | ~500 | Scaffold 2.4/5 aligned, deployment model divergence |

---

*Generated by 6-agent research team. ~70K lines of documentation consumed. Branch: spec/revision-sprint-2026-03-20*
