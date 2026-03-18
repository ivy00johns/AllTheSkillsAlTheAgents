# 13 — Multi-Phase Implementation Plan

## Overview

Four phases to build the convergence. Each phase is independently valuable —
you get wins at every stage, not just at the end.

---

## Phase 1: Browser Eyes for Agents (2–4 hours CC time)

### Goal
Give every gastown polecat access to gstack's browse CLI and ref system.

### Why First
Browser interaction is the single biggest capability gap. Agents that can't
see the UI are flying blind. This unlocks QA, design review, and visual
verification for every agent in the fleet.

### Work Items

**1.1 — Browse binary distribution**
- Build browse binary as part of gastown's install/setup
- Place in a shared location (`~/gt/.tools/browse`)
- Add to polecat PATH via CLAUDE.md or hook

**1.2 — Browse skill extraction**
- Extract gstack's browse SKILL.md sections (command reference, snapshot flags,
  setup instructions) into a standalone skill
- This skill teaches any agent how to use the browse CLI
- No dependency on gstack's other skills

**1.3 — Polecat template integration**
- Update `templates/polecat-CLAUDE.md` to include browse setup
- Each polecat gets browse available at `$B`
- Ref system works in any runtime (not just Claude)

**1.4 — Cookie sharing**
- Authenticated sessions: browse daemon runs per-rig
- Cookies imported once (by crew member), shared with polecats
- Polecats can QA authenticated pages

### Deliverables
- Every polecat can: `$B goto https://myapp.localhost:3000`
- Every polecat can: `$B snapshot -i` → see interactive elements → `$B click @e3`
- Visual verification before marking work complete

### Risk
- Browse daemon is per-process. Multiple polecats need separate daemons or shared access.
- Solution: One daemon per rig, polecats connect via HTTP (browse already supports this).

---

## Phase 2: Cognitive Quality Layer (4–8 hours CC time)

### Goal
Infuse gastown agents with gstack's cognitive patterns and review intelligence.

### Why Second
Browser eyes (Phase 1) let agents see. Cognitive patterns teach them what to
look for. Together: agents that see AND think deliberately.

### Work Items

**2.1 — Cognitive pattern extraction**
- Extract the 41 patterns into a standalone reference document
- Organized by role: CEO (14), Eng (15), Design (12)
- Each pattern: name, thinker, one-line insight, when to apply

**2.2 — Role-specific pattern assignment**
- Backend polecats: McKinley (boring default), Brooks (essential/accidental),
  Kernighan (debugging), Unix Philosophy, Postel's Law
- Frontend polecats: Rams (subtraction), Norman (3 levels), Tufte (data-ink),
  Krug (don't think), Victor (immediate feedback)
- QA polecats: Grove (paranoid), Munger (inversion), Majors (own your code)
- Refinery: Full eng review patterns

**2.3 — Review skill adaptation**
- Port `/review` two-pass logic into a Refinery-compatible format
- CRITICAL pass (SQL injection, race conditions, enum completeness) runs pre-merge
- INFORMATIONAL pass produces beads for future work
- Fix-first heuristic: Refinery auto-applies mechanical fixes

**2.4 — Design intelligence integration**
- Port design system inference to run once per rig (on initial deploy or first QA)
- Save as `DESIGN.md` in rig root
- All polecats read DESIGN.md as constraint
- Frontend polecats get the 7-item lite design review

**2.5 — AI slop detection as Refinery gate**
- Run AI slop check on all frontend changes before merge
- 10-pattern detection with confidence scoring
- Block merges that score 5+ slop patterns

**2.6 — Completeness principle in Mayor decisions**
- Mayor applies lake/ocean calculus when breaking down work
- Effort estimates show compression ratios
- Default to completeness when AI makes it cheap

### Deliverables
- Backend polecats think like McKinley + Kernighan
- Frontend polecats think like Rams + Norman
- Refinery runs cognitive review before every merge
- AI slop detection prevents generic AI output from landing
- Design system enforced across all agents

### Risk
- Cognitive patterns increase skill size → context pressure on polecats
- Solution: Progressive disclosure. Patterns in references/, loaded on demand.

---

## Phase 3: Beads Integration Layer (8–16 hours CC time)

### Goal
Connect gstack's quality outputs to beads' persistent tracking.

### Why Third
Phases 1–2 give agents eyes and brains. Phase 3 gives them memory.
Review findings, QA bugs, and design issues become trackable work items
that persist across sessions, have dependencies, and flow through the
ready queue.

### Work Items

**3.1 — Review-to-bead pipeline**
- `/review` findings → `bd create --type bug --deps discovered-from:<parent>`
- CRITICAL findings → priority 0 (blocker)
- INFORMATIONAL findings → priority 2 (normal)
- Auto-link to the commit/file that contains the issue

**3.2 — QA-to-bead pipeline**
- `/qa` bugs → beads with:
  - Screenshots as note attachments
  - Steps to reproduce in description
  - Severity mapping to priority (critical→0, high→1, medium→2, low→3)
  - Diff-aware: link to the PR/commit that introduced the bug

**3.3 — Design-to-bead pipeline**
- Design audit issues → beads with category tags (typography, color, spacing, etc.)
- Design regression → bead linked to previous design review
- AI slop detection → bead with pattern names and evidence

**3.4 — Review dashboard → beads migration**
- Replace `~/.gstack/projects/{slug}/{branch}-reviews.jsonl` with beads queries
- Review readiness = `bd list --label review --status closed --json`
- Decision tracking = beads with type=decision
- Benefits: distributed sync, semantic compaction, dependency awareness

**3.5 — Formula-based workflows**
- `/ship` as a formula: review → test → version → changelog → PR
- Each step is a bead with dependencies
- Gates: review gate (human), test gate (CI), design gate (automated)
- Formula persists across sessions — resume after crash

**3.6 — Ready queue for quality work**
- `bd ready --label quality` shows unblocked quality work
- Polecats pick up quality fixes from ready queue
- Dependencies ensure fixes happen in order (block on upstream fixes)

### Deliverables
- Every review finding is a tracked bead
- Every QA bug is a tracked bead with evidence
- Workflows are resumable formulas, not ephemeral sessions
- Quality work flows through the ready queue

### Risk
- Beads has overhead per operation (~50ms for Dolt queries)
- At scale (100+ findings per review), this adds up
- Solution: Batch creation API, async writes, wisp mode for ephemeral findings

---

## Phase 4: Contract Architecture + Eval Pipeline (16–32 hours CC time)

### Goal
Add AllTheSkillsAllTheAgents' contract system and gstack's eval pipeline
to create a self-validating, contract-driven build system.

### Why Last
This is the most complex integration. Phases 1–3 must be stable before
adding contract enforcement and eval validation on top.

### Work Items

**4.1 — Contract system integration**
- Port contract-author skill into gastown formula
- Mayor invokes contract authoring before spawning polecats
- Contracts generated in `contracts/` directory per rig
- Each polecat receives its relevant contract section

**4.2 — Contract auditor as Refinery step**
- Before merging polecat work, Refinery runs contract audit
- Static analysis: implementation matches contract?
- Mismatches → beads with priority 0 (blocker)
- Merge blocked until contract conformance passes

**4.3 — File ownership enforcement**
- File ownership map from contracts → enforced by gastown
- Polecat-1 touches a file owned by Polecat-2 → merge rejected
- Ownership violations → bead + nudge to correct agent

**4.4 — QA gate with beads**
- `qa-report.json` schema → bead with structured data
- Gate rules evaluated from beads: contract_conformance < 3 → blocked
- QE agent mandatory in every convoy (enforced by Mayor)

**4.5 — Eval system as gastown plugin**
- Port gstack's session-runner, LLM-judge, and planted-bug fixtures
- Deacon runs evals periodically (e.g., nightly or per-convoy)
- Diff-based selection: only eval skills touched by recent changes
- Results tracked as beads with regression alerting

**4.6 — Eval-driven quality monitoring**
- Agent quality metrics tracked over time:
  - Review accuracy (true positive rate on planted bugs)
  - QA thoroughness (bugs found per session)
  - Design compliance (slop score per merge)
- Trends surfaced in `gt feed` and web dashboard
- Alerts when quality degrades below threshold

**4.7 — Multi-runtime cognitive patterns**
- Cognitive patterns work for Claude (CLAUDE.md)
- Adapt for Gemini (GEMINI.md), Codex (AGENTS.md)
- Pattern effectiveness may vary by model — eval tracks this
- Model-specific tuning based on eval results

**4.8 — Template generation for gastown**
- Port gstack's template system to gastown agent templates
- Polecat CLAUDE.md generated from source code metadata
- When `gt` adds a command, agent instructions auto-update
- Validation: CI checks template freshness

### Deliverables
- Contract-first builds with automated conformance checking
- File ownership enforced at merge time
- Self-validating pipeline (eval system monitors agent quality)
- Quality trends tracked over time with regression alerts
- Multi-runtime support with model-specific tuning
- Template-generated agent instructions that can't drift

### Risk
- Complexity explosion: 4 systems integrated = many interaction points
- Solution: Each integration point has its own eval. Regressions caught early.
- Context pressure: contracts + patterns + browse = large skill footprint
- Solution: Progressive disclosure. Load contracts on spawn, patterns on demand.

---

## Phase Summary

| Phase | Investment | Standalone Value | Cumulative Value |
|-------|-----------|-----------------|-----------------|
| **1: Browser Eyes** | 2–4 hrs | Agents can see and interact with UI | Visual QA for all agents |
| **2: Cognitive Quality** | 4–8 hrs | Agents think deliberately | Eyes + brains |
| **3: Beads Integration** | 8–16 hrs | Quality findings persist and track | Eyes + brains + memory |
| **4: Contracts + Evals** | 16–32 hrs | Self-validating pipeline | The full system |

**Total:** 30–60 hours of CC time (~1–2 weeks of part-time work)
**Human equivalent:** 6–12 months of team effort
**Compression:** ~20x

## The End State

Tell the Mayor: "Build a full-stack app with authentication, real-time updates,
and a dashboard."

The Mayor:
1. Authors contracts (shared types, API, data layer)
2. Spawns 6 polecats (backend, frontend, infra, DB, QA, docs)
3. Each polecat has: browse CLI, cognitive patterns, beads tracking, contract awareness
4. Polecats build in parallel, each verifying their own UI work
5. Refinery runs cognitive review + contract audit before merging
6. QA polecat does browser-based testing with find-fix-verify
7. Design polecat enforces the design system, detects AI slop
8. All findings tracked as beads with dependencies
9. Eval system validates the pipeline's quality continuously
10. `/ship` runs as a formula: version → changelog → PR

One person. 30 agents. Production-quality output. Self-validating.
Nothing like this exists today.
