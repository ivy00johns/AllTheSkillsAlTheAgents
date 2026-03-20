# Gap Research Findings: Resolution Status Against the 17-Document Spec

**Date:** 2026-03-20
**Scope:** 8 gap research documents + 7 synthesis documents vs 17-doc spec

---

## Executive Summary

Six of eight gaps are partially resolved at the architecture level but lack implementation-grade specificity. Two gaps (Gap 5: Glass UI and Gap 6: Database Architecture) are almost entirely unaddressed and represent the highest build-blocking risk.

---

## 1. Gap Resolution Scorecard

| Gap | Title | Status | Risk Level |
|-----|-------|--------|------------|
| Gap 1 | Deployment Architecture | Partially Resolved | Medium |
| Gap 2 | LLM Cost Management | Partially Resolved | High |
| Gap 3 | Agent Identity & Auth | Partially Resolved | High |
| Gap 4 | SKILL.md Security | Mostly Resolved | Medium |
| Gap 5 | Glass UI Frontend | **Open** | **Critical** |
| Gap 6 | Database Architecture | Partially Resolved (conflict) | **Critical** |
| Gap 7 | Testing Strategy | Partially Resolved | Medium |
| Gap 8 | Competitive Landscape | Partially Resolved | Low |

---

## 2. Per-Gap Analysis

### Gap 1: Deployment Architecture and DevOps — Partially Resolved

**What the gap identified:** Three-tier deployment model (Docker Compose → VPS → Kubernetes with KEDA v2.19). Critical finding: LLM workloads are I/O-bound (30-120s API waits, CPU at 1-6%), making standard HPA useless. KEDA queue-depth autoscaling is the correct solution.

**What the spec addresses:** Doc 11 (Runtime Adapters), doc 03 (System Architecture), doc 09 (runtime degradation).

**What remains:** No deployment topology document. No Docker Compose layout, Kubernetes manifests, KEDA config, secrets management, Dockerfile patterns, or tier migration triggers.

**Action:** New `18-deployment-topology.md`. Phase 5-6 material but needs specification before Phase 0 for correct directory structure.

---

### Gap 2: LLM Cost Management — Partially Resolved

**What the gap identified:** 20-30 parallel agents produce five-figure monthly bills without controls. Full stack: LiteLLM proxy, pre-dispatch token estimation, per-agent virtual API keys with hard caps, semantic model routing (70% Haiku saves 60-80%), prompt caching (90% cache reads at 10% price), ClickHouse spend attribution. Optimized: $2,200-4,400/mo vs $13,750-27,500 unoptimized.

**What the spec addresses:** Doc 13 cost metrics, doc 09 circuit breaker, doc 04 `max_budget_cents` field.

**What remains:** No LiteLLM proxy config, no pre-dispatch estimation, no virtual API key management, no task-to-model routing, no prompt caching strategy, no spend enforcement mechanism. `max_budget_cents` exists but nothing enforces it.

**Action:** Add "Cost Enforcement Layer" to doc 13. LiteLLM as mandatory gateway, five-level budget hierarchy, pre-dispatch estimation, model routing table, ClickHouse spend schema, Prometheus alerting rules.

---

### Gap 3: Agent Identity & Authentication — Partially Resolved

**What the gap identified:** Agents are ephemeral, non-deterministic, form delegation chains. Required: JWT with EdDSA/Ed25519 (64-byte sigs, 62x faster than RSA), capability-scoped tokens, per-worker Valkey ACL, revocation blocklist, 7-step spawn sequence. A2A explicitly deferred (solves cross-org, not intra-org).

**What the spec addresses:** Doc 04 lifecycle state machine, depth hierarchy, tool guards, capabilities field. Doc 03 "Persistent Agent Identity" (refers to CV accumulation, not crypto).

**What remains:** No JWT structure, no signing algorithm, no key management, no Valkey ACL, no revocation, no auth middleware, no confused deputy defense. Lifecycle is detailed but credential provisioning is absent.

**Action:** Add "Agent Credential Lifecycle" to doc 04. EdDSA JWT claims, Queen as CA, complete 7-step spawn-to-revoke sequence, Valkey ACL per caste. Record A2A deferral in doc 03 §8.

---

### Gap 4: SKILL.md Ecosystem Security — Mostly Resolved

**What the gap identified:** ClawHavoc attack (Feb 2026): 1,184 malicious skills on ClawHub. Snyk ToxicSkills: 36% have security flaws. Required: Sigstore provenance, multi-phase static analysis, dynamic sandboxing (GKE Sandbox/gVisor), "Lethal Trifecta" defense. CVE-2025-6514 (CVSS 9.6) in mcp-remote.

**What the spec addresses:** Doc 08 has strong skill system spec — three-layer model, progressive disclosure, guard rules, composition.

**What remains:** No security model for skill ingestion. No import pipeline, Sigstore, static analysis patterns, sandbox spec, or Lethal Trifecta principle.

**Action:** Add "Security and Provenance" section to doc 08. Three-layer security pipeline, Sigstore for external imports, static analysis patterns, Lethal Trifecta as structural principle. Add mcp-remote pinning note to doc 11.

---

### Gap 5: Glass UI Frontend — OPEN (Critical)

**What the gap identified:** Nine-screen Glass UI requires 19 npm packages. Three critical renames: `xterm` → `@xterm/xterm` v6, `reactflow` → `@xyflow/react` v12, `framer-motion` → `motion` v12. AG-UI protocol (17 event types, adopted by Google/LangChain/AWS/Microsoft/Mastra). Performance: 60 FPS at 50 DAG nodes, 4 visible terminals at 30 FPS, 50ms SSE batching. Block/tile registry (Wave Terminal pattern) for extensibility.

**What the spec addresses:** Doc 13 mentions dashboard mockup. Doc 00 names "The Glass." Doc 01 lists PTY multiplexing as a differentiator. No spec document addresses frontend technology.

**What remains:** Everything. No framework choice, terminal library, DAG library, state management, streaming protocol, AG-UI mapping, block architecture, performance budgets, or memory constraints.

**Action:** New `18-glass-ui.md` — the highest-priority missing document. The Glass is a core differentiator with zero specification.

---

### Gap 6: Database Architecture — Partially Resolved (Conflict)

**What the gap identified:** Production trident: PostgreSQL + Valkey + ClickHouse. Langfuse/LangSmith both converged here. PostgreSQL LISTEN/NOTIFY has fatal global lock on COMMIT. SQLite single-writer blocks 20-30 agents. ClickHouse acquired Langfuse for $400M. pgvector for semantic memory under 10M vectors.

**What the spec addresses:** Doc 12 bets on Dolt (sound for work tracking/federation). Doc 03 specifies Dolt + SQLite. Doc 06 SQLite mail bus. Doc 13 four SQLite databases.

**What remains:** SQLite events/metrics will produce 30-second dashboard queries at scale (Langfuse's exact failure mode). Streaming coordination layer (The Airway) unspecified — needs Valkey Streams. pgvector for Honey unmentioned. The Dolt bet is correct for work tracking; the conflict is events/metrics at scale.

**Action:** Targeted enrichment: Add "Database Scaling Inflection Points" to doc 13 (when to add ClickHouse). Add Valkey Streams spec for The Airway to doc 03. Add pgvector for Honey to doc 05. Not a Dolt replacement — a complement.

---

### Gap 7: Testing Strategy — Partially Resolved

**What the gap identified:** Five-layer testing pyramid: Vitest unit tests, LLM fixture replay, integration tests, trajectory evaluation (`agentevals`), LLM-as-judge with majority vote. `pass^k` > `pass@k` for production (90% pass@1 → 57% at pass^8). Golden datasets: 20-50 per caste. Trajectory anti-patterns: retry spirals, infinite loops, context bloat.

**What the spec addresses:** Doc 10 has 3-tier eval system, LLM-as-judge, design audit, slop detection.

**What remains:** No testing pyramid for the platform itself, no Vitest patterns, no fixture recording, no golden dataset structure, no `pass^k` measurement, no trajectory anti-pattern detection rules.

**Action:** Add "Platform Test Architecture" to doc 10. Add "Trajectory Anti-Pattern Detection" to doc 13. Make evaluation harness a Phase 1 deliverable.

---

### Gap 8: Competitive Landscape — Partially Resolved

**What the gap identified:** Market $7-8B → $52-93B by 2030. No competitor combines terminal multiplexing + DAG visualization + human approval + per-agent crypto identity. Primary buyer: platform engineer at 200-5K org. MIT licensing. GTM: developer-led, commercial tier for managed/SSO/audit.

**What the spec addresses:** Doc 01 product charter, doc 02 naming system.

**What remains:** No competitive matrix, positioning statement, GTM strategy, buyer persona, pricing model, or existential risk analysis.

**Action:** New `19-go-to-market.md` — not build-blocking but needed before public release.

---

## 3. Synthesis Document Key Findings

**AG-UI Protocol (agentic-ui-deep-dive-synthesis):** 17 event types adopted by Google, LangChain, AWS, Microsoft, Mastra, PydanticAI. Standard to adopt, not invent. Interrupt lifecycle maps to The Keeper's approval gates.

**CI Self-Correction (four-frameworks-orchestration):** Composio AO achieves 84.6% CI self-correction by auto-injecting failure output back into agent context. Should be added to doc 09.

**Séance Protocol (four-frameworks-field-guide):** Gas Town's handoff mechanism — new session asks previous session questions before proceeding. More concrete than spec's handoff protocol. Enrich doc 06.

**Cost Reality (four-frameworks-field-guide):** Gas Town's $100/hour burn rate for 20-30 agents. Spec's $280-550 are build costs, not operational costs — both numbers should be explicit.

**SPA Shell Pattern (mission-control-research):** Zustand-driven SPA (not URL routing) for persistent WebSocket/SSE connections. Correct pattern for The Glass.

**Vocabulary Conflict (project-names):** The Comb (task graph vs shared memory) needs disambiguation in doc 02.

---

## 4. Build-Blocking Priority

### Must Resolve Before Code

1. **Glass UI spec** (Gap 5) — Phase 6 has no design foundation
2. **Agent credentials** (Gap 3) — Phase 0 concern, retrofit is costly
3. **Cost enforcement** (Gap 2) — runaway agent drains budget in Phase 2

### Before Phase 3-4

4. **DB scaling inflection points** (Gap 6) — event schema must support future ClickHouse migration
5. **Valkey Streams for The Airway** (Gap 6) — streaming layer needed before The Glass
6. **SKILL.md security pipeline** (Gap 4) — Waggle schema must support eventual security layer

### Before Phase 5-6

7. **Deployment topology** (Gap 1) — KEDA config, Docker Compose layout
8. **Testing pyramid** (Gap 7) — evaluation harness should be Phase 1

### Strategic

9. **GTM and competitive positioning** (Gap 8) — before public release
10. **Vocabulary disambiguation** — Comb vs Frame naming

---

## 5. New Spec Documents Needed

| Document | Priority | Input |
|----------|----------|-------|
| `18-glass-ui.md` | Critical | gap-5, agentic-ui synthesis, MC research |
| `18-deployment-topology.md` | High | gap-1 |
| `19-go-to-market.md` | Medium | gap-8 |

## 6. Existing Sections Needing Enrichment

| Document | Section to Add | Input |
|----------|---------------|-------|
| doc 04 | Agent Credential Lifecycle | gap-3 |
| doc 08 | Security and Provenance | gap-4 |
| doc 09 | CI Failure Injection Pattern | four-frameworks |
| doc 10 | Platform Test Architecture | gap-7 |
| doc 13 | Cost Enforcement Layer | gap-2 |
| doc 13 | Database Scaling Inflection Points | gap-6 |
| doc 13 | Trajectory Anti-Pattern Detection | gap-7 |
| doc 11 | MCP Security Notes (CVE-2025-6514) | gap-4 |
| doc 06 | Séance Handoff Protocol | four-frameworks |
| doc 03 | Valkey Streams for The Airway | gap-6 |
| doc 05 | pgvector for Honey | gap-6 |
| doc 02 | Vocabulary Disambiguation | project-names |
| doc 16 | Evaluation harness as Phase 1 deliverable | gap-7 |

---

*Sources: 15 research documents in claude_research/, 17 spec documents. Generated 2026-03-20.*
