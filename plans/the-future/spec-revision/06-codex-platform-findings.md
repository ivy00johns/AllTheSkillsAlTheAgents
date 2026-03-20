# 06 — Codex Research and Platform Scaffold Findings

**Document type:** Alignment analysis and revision recommendations
**Date:** 2026-03-20
**Status:** Complete
**Inputs:** 9 Codex research docs, all platform scaffold files, spec overview + doc 17

---

## Part 1: Codex Research Integration Recommendations

### 1.1 System Atlas Insights — What the 4-Phase Model Adds to the Spec

The Codex research establishes a conceptual frame that the spec's 5-layer architecture does not fully replicate:

**The Sense → Decide → Act → Remember loop is more precise than the spec's layer stack.**

The spec's 5-layer model (Skill / Orchestration / Quality / Work / Runtime) describes components, not lifecycle. The 4-phase model describes transitions between states. These are complementary, and the spec does not include the phase-loop view.

Most under-specified handoffs in the spec:
- **Sense → Decide:** how evidence (screenshots, logs, test outputs) flows into planning decisions. The spec mentions an evidence store (doc 13) but does not show the path from a browser screenshot to a routing or gating decision.
- **Act → Remember:** what structured record gets written after every run. Doc 17's types.ts does not include a RunLedger type.
- **Remember → better Decide:** how accumulated scorecard data feeds routing. Doc 11 covers runtime adapters, doc 13 has scorecards, but the closed loop from scores back to routing is not specified.

**The "hidden fourth layer" — the policy fabric.**

Codex identifies ATSA as modeling a missing policy and contract layer. The spec distributes these concerns across Layer 1 (skills), Layer 2 (orchestration), and Layer 3 (quality). This distribution may create ownership ambiguity during implementation.

**Recommended:** A new section in doc 03 (or new doc) that names the policy fabric explicitly: contract compilation, ownership enforcement, gate rules, escalation paths, and evidence routing.

### 1.2 Integration Recommendations Ranked

| Rank | Recommendation | Effort | Impact |
|------|---------------|--------|--------|
| 1 | Add RunLedger type to types.ts — primary data structure for Remember phase | Low | High |
| 2 | Specify contract-bundle-to-spawn-config binding — critical cross-layer handoff | Medium | Critical |
| 3 | Add evidence routing from quality events to work items (review → bead pipeline) | Medium | High |
| 4 | Operationalize 4-phase model as a design filter in doc 03 | Low | Medium |
| 5 | Add "do not hard-fork upstream early" constraint as build principle | Low | Medium |

---

## Part 2: Gap Catalog Overlap Analysis

| Codex Gap | Severity | Claude Research Equivalent | Overlap |
|-----------|----------|---------------------------|---------|
| Runtime-neutral quality layer | Critical | gap-2 (LiteLLM routing) | Partial — cost routing ≠ quality routing |
| Policy and contract engine | Critical | gap-4 (Waggle registry) | Partial — skill security ≠ runtime compilation |
| Evidence graph | Critical | gap-5 (glass UI evidence displays) | Partial — UI surface ≠ data model |
| Quality-aware router | High | gap-2 (LiteLLM routing) | Partial — same seam, different target |
| Unified analytics + cost model | High | gap-2, gap-6 | Strong overlap — well covered |
| Security + multi-user | High | gap-3 (JWT, RBAC) | Strong overlap — directly applicable |
| Orchestration evals | High | gap-7 (testing pyramid) | Strong overlap |
| Productized operator UX | Medium-High | gap-5, agentic-ui-dashboard/ | Strong overlap |
| External event fabric | Medium | gap-1 (NATS event bus) | Partial — infra covered, routing rules not |
| Upgrade + compatibility strategy | Medium | No equivalent | **Unaddressed gap** |

**True gaps with no coverage in either research set:**
- Upgrade and compatibility strategy (Codex gap 10)
- The finding-to-work-item automated pipeline (Codex roadmap Phase 2)
- Quality-score-to-routing feedback loop (distinct from cost routing)

---

## Part 3: Build vs. Wrap Decision Inventory

| Component | Codex Recommendation | Spec Decision | Alignment |
|-----------|---------------------|--------------|-----------|
| beads (work graph) | Wrap at CLI/MCP boundary | Clean-sheet rewrite (doc 12) | **Diverges** |
| gastown (fleet control) | Mostly wrap via plugins | Clean-sheet rewrite (doc 09) | **Diverges** |
| gstack (quality layer) | Extract: browse, review, eval | Clean-sheet quality module (doc 10) | Aligned |
| current repo (policy/contracts) | Extract schemas, ownership | Directly incorporated (doc 15) | Aligned |
| Evidence store | Build net-new | Specified in doc 13 | Aligned |
| Policy compiler | Build net-new | Partially in doc 15 | Partial |
| Capability registry | Build net-new | Partially in doc 11 | Partial |
| Run ledger + analytics | Build net-new | Specified in doc 13 | Aligned |
| Operator UI | Build net-new | Not in spec | **Gap** |

**Critical observation:** The spec made a deliberate clean-sheet-rebuild choice for beads and gastown. This is defensible but undocumented as a conscious divergence. The spec should include a paragraph acknowledging this choice.

---

## Part 4: Scaffold vs. Spec Alignment Scorecard

### What Doc 17 Specifies vs. What Exists

**Spec (doc 17):** Single-package TypeScript/Bun monolith — `src/` with cli, core, data, tracker, orchestration, etc. Tech: Bun, Commander.js, better-sqlite3, mysql2 (Dolt).

**Scaffold:** Microservices architecture — Go + TypeScript split, Postgres + NATS + MinIO + ClickHouse. No `src/` directory, no CLI, no Dolt, no SQLite.

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Directory structure | 1 | Microservices vs. monolith |
| Tech stack | 2 | Go (3 services) + TS (2 services) vs. TS/Bun throughout |
| Data storage | 1 | Postgres + NATS + MinIO + ClickHouse vs. Dolt + SQLite |
| Schema/type alignment | 4 | 5 JSON schemas match spec's 5 core abstractions |
| Service responsibility | 3 | Service names map to spec layers correctly |
| Build phase alignment | 2 | Scaffold skips Phase 0, jumps to Phase 2+ topology |
| Open question resolution | 2 | Implicitly resolves local-first vs. hosted without documenting it |
| ADR practice | 4 | Excellent ADR 0001, consistent with spec |

**Overall alignment: 2.4/5.** Vocabulary and intent align; infrastructure premises diverge.

---

## Part 5: The Critical Divergence — Deployment Model

The spec is a **local-first monolith** (Dolt + SQLite, tmux agents, developer machine). The scaffold is a **service-oriented architecture** (Postgres + NATS, Docker, hosted).

These are two different product bets:
- Spec: optimized for solo power user, zero infrastructure overhead
- Scaffold: optimized for team product, scalable, hosted

**This is the P0 decision that blocks all subsequent work.** The spec and scaffold need to agree on an initial deployment target.

### Other Divergences

**Language:** Spec says TypeScript everywhere. Scaffold uses Go for 3 of 5 services.

**Event bus:** Spec uses SQLite mail bus. Scaffold uses NATS JetStream (significantly more capable but more complex).

**Analytics:** Spec uses SQLite metrics.db. Scaffold provisions ClickHouse (justified by claude_research gap-6 citing Langfuse production experience).

---

## Part 6: Premature Scaffold Decisions

Things the scaffold has decided that should wait:

1. **Go for control-plane and orchestrator** — language commitment before deployment model is resolved
2. **Postgres as primary DB** — prevents Dolt-based work graph from being primary store
3. **ClickHouse at Day 0** — adds operational overhead before analytics consumers exist
4. **MinIO provisioned** — no service currently writes evidence to it
5. **Router without scorecards** — can't do quality-aware routing without run history (Phase 3 infra at Phase 0)

---

## Part 7: Scaffold Decisions Ahead of Spec

Things the scaffold has that the spec should acknowledge:

1. **Multi-language service topology** — should be documented as ADR if accepted
2. **Shared contract schemas** (`packages/contracts/schemas/`) — sound cross-service pattern
3. **ADR practice** — `docs/adr/0001-core-principles.md` is excellent and consistent with spec
4. **"Mission" abstraction** — control-plane uses "missions" where spec uses "convoys" — naming divergence to resolve
5. **Approval workflow as first-class API** — `POST /approvals/:id/decide` exists in scaffold, not in spec

---

## Part 8: New Spec Content Recommended

### 8.1 Policy Fabric Layer (doc 03 addition)

Name the policy fabric explicitly between Orchestration and Quality layers. Owns: contract compilation, ownership enforcement, gate rules, escalation paths, evidence routing.

### 8.2 Run Ledger Specification (new doc 18)

What constitutes one "run," required fields, how runs aggregate into scorecards, how scorecards feed routing, retention policy.

### 8.3 Build/Wrap Annotations (doc 16 addition)

For each Phase deliverable: "building from scratch," "wrapping [upstream]," or "extracting from [upstream]" with rationale.

### 8.4 Upstream Relationship Register (doc 16 or new doc)

Which repos are dependencies vs. reference implementations. Upgrade cadence. Compatibility test requirements.

### 8.5 Four-Phase Design Filter (doc 01 or doc 03)

Every feature classified by which phase it strengthens. Features that improve handoffs > features that improve nodes.

### 8.6 Missing Types in types.ts

`RunLedgerEntry`, `WorkerScorecard`, `EvidenceRecord` — scaffold's JSON schemas provide the shape; spec needs TypeScript equivalents.

---

## Part 9: Priority-Ordered Recommendations

| Priority | Recommendation | Effort | Impact |
|----------|---------------|--------|--------|
| P0 | Resolve local-first vs. service-hosted deployment model. Document as ADR. Rewrite doc 17 if scaffold model accepted. | High | Unblocks all work |
| P0 | Specify contract-bundle-to-spawn-config binding (Decide→Act handoff) | Medium | Enables worker dispatch |
| P1 | Add RunLedgerEntry and WorkerScorecard to spec types.ts | Low | Enables analytics from day 1 |
| P1 | Add four-phase model as design filter to doc 03 | Low | Improves all design decisions |
| P1 | Add finding→work-item pipeline as Phase 2 deliverable | Medium | Closes quality loop |
| P2 | Add Run Ledger spec (new doc 18) | Medium | Enables dashboards + routing |
| P2 | Add Policy Fabric as named concern in doc 03 | Medium | Resolves ownership ambiguity |
| P2 | Add build/wrap/buy annotations to doc 16 | Low | Prevents premature forks |
| P3 | Add upstream relationship register | Low | Long-term maintenance |
| P3 | Address upgrade/compatibility strategy (Codex gap 10) | Medium | Maintenance health |

---

## Codex Open Questions Still Unresolved

The 5 most important to resolve before Phase 1:

1. **Local-first vs. service-hosted** — incompatible starting points (spec vs. scaffold)
2. **Quality services inline vs. async** — changes how review-engine connects to orchestration
3. **Canonical contract bundle serialization** — needed before any worker can be spawned
4. **Minimum evidence set for task completion** — needed before quality gate automation
5. **Router optimization criteria** — needed before meaningful routing

---

*Analysis based on full review of Codex research (9 docs), platform scaffold (20+ files), and spec (docs 00, 03, 16, 17). Generated 2026-03-20.*
