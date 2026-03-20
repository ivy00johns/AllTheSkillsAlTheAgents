# Deep Research Integration Proposal

**Status:** Awaiting Planner Approval  
**Date:** March 2026  
**Prepared by:** The Hive Architecture Team

---

## Executive Summary

The Hive's current research phase relies on claude.ai's deep research feature — a multi-source, citation-backed agentic workflow that produced the eight architectural gap reports (Deployment, Cost Management, Agent Identity, SKILL.md Security, Frontend Components, Database Architecture, Testing Strategy, and Competitive Landscape) that define The Hive's technical foundation.

This proposal requests approval to integrate an equivalent deep research capability directly into The Hive's Claude Code agentic build pipeline as a first-class SKILL.md Blueprint registered in the Waggle registry — so the Queen can route structured research tasks the same way it routes coding, testing, or review tasks.

> The eight gap reports that define The Hive's architecture were produced by this exact capability. Integrating it means future architectural decisions, security audits, competitive analyses, and technology evaluations follow the same rigorous standard — automatically, from inside The Hive itself.

---

## Problem Statement

Claude Code's built-in `WebSearch` and `WebFetch` tools are optimized for quick lookups: checking current package versions, verifying API docs, fetching a specific URL. Results are summarized by Claude Haiku 3.5 and intentionally capped at 125 characters per citation for copyright compliance.

This is appropriate for developer tooling but insufficient for architectural research. The Hive requires a research capability that can:

- Execute 10–30 iterative web searches that build on each other
- Fetch and synthesize full article content across multiple sources
- Produce structured, citation-backed reports with section hierarchy
- Verify claims across conflicting sources before drawing conclusions
- Surface funding data, CVE details, benchmark scores, and market figures with proper attribution

Once in production, The Hive will need to evaluate new frameworks, audit SKILL.md ecosystem vulnerabilities, track competitive developments, and make technology decisions for new worker castes. Without integrated deep research, these decisions revert to manual work outside the system — breaking the agentic workflow.

---

## Proposed Solution

A two-tier research architecture registered as Blueprints in the Waggle:

| Tier | Blueprint | Latency | Use case |
|------|-----------|---------|----------|
| 1 | `quick-research` | Seconds | Package versions, CVE details, API docs, current facts |
| 2 | `deep-research` | 5–30 min | Architectural analysis, competitive intelligence, security audits |

### Tier 1 — Quick Research Blueprint

Already available natively. Registering it explicitly in the Waggle lets the Queen route to it intentionally rather than falling back to it by default.

```yaml
---
name: quick-research
description: >
  Fast web lookup for current facts, package versions, API docs, and
  single-source verification. Returns in seconds. Use for: npm versions,
  CVE details, pricing, current role holders, recent news headlines.
allowed-tools: WebSearch, WebFetch
---
```

### Tier 2 — Deep Research Blueprint

Spawns a background agent that uses the Claude in Chrome extension to access claude.ai's Research mode, submits the query, waits for completion, and saves the report to `./docs/research/`.

**Prerequisites:**
- Claude in Chrome extension installed and authenticated
- Claude Code v2.0.60+ (background agent support)
- Pro, Team, Max, or Enterprise Claude subscription
- Claude Code launched with: `claude --chrome`

```yaml
---
name: deep-research
description: >
  Comprehensive multi-source research producing a cited report saved to
  ./docs/research/. Takes 5–30 minutes. Runs as background agent — Queen
  continues routing other tasks while research completes. Use for:
  architectural analysis, competitive landscape, security audits, technology
  evaluation, market intelligence.
  DO NOT use for quick lookups — use quick-research instead.
context: fork
allowed-tools: Bash(claude:*), WebSearch, WebFetch
---
```

### Queen Routing Logic

The Queen's LLM-based routing reads both Blueprint descriptions and selects based on task intent:

| Query | Routed to | Reason |
|-------|-----------|--------|
| "What version of @xterm/xterm is current?" | `quick-research` | Single fact |
| "Is CVE-2025-6514 patched in latest mcp-remote?" | `quick-research` | Single source check |
| "Evaluate KEDA vs HPA for LLM workloads" | `deep-research` | Multi-source, architectural |
| "Competitive analysis of agent orchestration platforms" | `deep-research` | Market intelligence |
| "Security audit of the SKILL.md supply chain" | `deep-research` | Multi-source verification |
| "Latest Anthropic API pricing" | `quick-research` | Single lookup |

---

## Integration Plan

### Phase 1 — Blueprint Registration (Day 1)

No code changes to any Hive service. Pure configuration.

1. Create `skills/research/` directory in The Hive monorepo
2. Add `skills/research/quick-research/SKILL.md`
3. Add `skills/research/deep-research/SKILL.md` with full workflow instructions
4. Register both in the Waggle, assign to the Researcher caste
5. Verify Queen routing on test prompts

### Phase 2 — Researcher Caste Configuration (Day 2–3)

Configure a dedicated Researcher worker caste:

| Setting | Value |
|---------|-------|
| Caste name | `researcher` |
| Default skills | `quick-research`, `deep-research` |
| Max task duration | 45 minutes |
| Output directory | `./docs/research/` |
| KEDA scaling | Scale to 0 when idle (cold start acceptable) |
| Parallelism | Max 2 concurrent |

### Phase 3 — Waggle Security Review (Day 3–4)

Both Blueprints pass the three-layer security pipeline before production activation:

- **Layer 1 — Source verification:** Both skills authored internally; no external import
- **Layer 2 — Static analysis:** Scan for suspicious patterns; Chrome automation instructions flagged for human review
- **Layer 3 — Sandboxed test execution:** Run against known test queries; verify output format and file path confinement

> **Security note:** The `deep-research` Blueprint uses Chrome automation. The approved-sites allowlist (claude.ai only) must be hardcoded in the skill instructions — never derived from task input — to prevent adversarial redirection.

---

## Alternatives Considered

| Approach | Assessment | Decision |
|----------|------------|----------|
| MCP search servers (Brave, Tavily, Exa) | Better raw results than built-in WebSearch; does not replicate claude.ai's multi-step research workflow or citation quality | Adopt as Tier 1 enhancement only |
| Perplexity Sonar Deep Research via MCP | Closest MCP equivalent; $2/M input + $8/M output + $3/M reasoning. Proprietary model, less transparent | Keep as Tier 2 fallback if Chrome unavailable |
| 199-biotechnologies/claude-deep-research-skill | 8-phase pipeline, open source. Requires Brave/Exa API keys. No access to claude.ai Research infrastructure | Adopt as Tier 2 fallback if Chrome unavailable |
| Recursive Claude spawning (`--allowedTools Bash(claude:*)`) | Powerful for parallelism; high token cost; lacks citation format of claude.ai Research | Reserve for batch research requiring parallelism |
| Manual research outside Claude Code | Current state; breaks agentic workflow | Eliminated by this proposal |

---

## Cost and Resource Impact

**Direct costs:** Deep research sessions run against the existing Claude Pro/Team/Max subscription — no per-query API cost for Tier 2. Tier 1 has no additional cost. If the Chrome bridge is unavailable in a headless/CI environment, fallback to the 199-bio skill requires Brave Search API access at ~$3/1,000 queries (estimated $0–30/month at current research volume).

**Operational costs:**

| Resource | Impact |
|----------|--------|
| Researcher worker pods | Scale to 0 when idle; no standing compute cost |
| Context window | ~800 tokens at Level 1 metadata; full instructions loaded only when routed |
| Storage | 50–200KB per report; negligible |
| Integration time | 1–2 engineering days; no changes to existing services |

**Expected return:** The eight gap reports represent ~40–60 hours of manual research completed in under 3 hours elapsed time. Equivalent depth becomes available for all future architectural decisions at the same latency, with no manual overhead.

---

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Chrome extension unavailable in CI/CD | High | Automatic fallback to 199-bio skill; detect headless mode and route accordingly |
| Research task blocks Queen for 30+ min | Medium | `context: fork` runs research in subprocess; Queen continues routing other tasks |
| Inconsistent output format | Low | Define output schema in skill instructions; validate filename and structure post-completion |
| Routing confusion (quick vs deep) | Low | Explicit "DO NOT use for quick lookups" in description; routing test in skill test suite |
| Adversarial input redirecting Chrome | Low | Hardcode `claude.ai` as only approved site in skill instructions |

---

## Approval Request

Requesting planner sign-off on the following:

1. Creation of `skills/research/` and both Blueprint files in the monorepo
2. Registration of `quick-research` and `deep-research` in the Waggle, assigned to the Researcher caste
3. Researcher worker caste configuration with 45-minute timeout, scale-to-zero policy, and `./docs/research/` output directory
4. Security review of both Blueprints through the Waggle three-layer pipeline before production activation
5. Procurement of Brave Search API access as headless fallback (estimated $0–30/month)

**Estimated integration time:** 1–2 engineering days  
**Changes to existing services:** None  
**New infrastructure dependencies:** None  
**Standing compute cost:** Zero (Researcher caste scales to 0 when idle)
