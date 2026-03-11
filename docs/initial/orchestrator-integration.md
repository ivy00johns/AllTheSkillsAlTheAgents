# Orchestrator Integration: QE Agent

This document describes how the lead coordinator's workflow changes when using the QE agent. These are **modifications to the main SKILL.md**, not a replacement.

---

## What Changes

The QE agent takes over most of Phase 8 (Validation). Instead of the lead manually running contract diffs, curl commands, and edge case tests, the lead spawns the QE agent after implementation agents report done, then reviews the structured QA report.

### Before (lead does all validation):

```
Phase 6: Spawn implementation agents in parallel
Phase 7: Coordinate during implementation
Phase 8: Lead manually runs contract diff → agent validation → e2e testing
```

### After (QE agent handles validation):

```
Phase 6: Spawn implementation agents in parallel
Phase 7: Coordinate during implementation
Phase 8: Spawn QE agent with contracts + service info
Phase 9: Lead reviews QA report → triages issues → re-spawns agents for fixes
```

---

## Modified Phase 8: Spawn QE Agent

When ALL implementation agents report done and have passed their own validation checklists, spawn the QE agent.

### QE Agent Prompt

```
You are the QE agent for this build. Read agents/qe.md for your full process.

## Contracts to Test Against

### API Contract (v[N])
[paste the current versioned API contract]

### Data Layer Contract (v[N])
[paste the current versioned data layer contract]

### Shared Types (v[N])
[paste or reference the shared types file]

## Services

Start services in this order:
1. [database command] — port [XXXX]
2. [backend command] — port [XXXX]
3. [frontend command] — port [XXXX]

## Agent Ownership (for assigning blame)

- Frontend agent owns: [directories]
- Backend agent owns: [directories]

## Acceptance Criteria (from the plan)

[paste the acceptance criteria / validation section from the original plan]

## Your Ownership

- You own: tests/, qa-report.md
- Do NOT touch any production code
- Read-only: everything else

## Tech Stack

[e.g., React 18 + TypeScript frontend, FastAPI backend, PostgreSQL database]

## Contract Changelog

[paste the running changelog so QE knows about any mid-build contract changes]
```

### Key Differences from Implementation Agent Spawning

- The QE agent spawns **sequentially** (after implementation agents finish), not in parallel with them
- The QE agent gets **all contracts** (it needs to verify both sides), not just one
- The QE agent gets **agent ownership info** so it can assign issues to the right agent
- The QE agent gets the **contract changelog** so it knows if any mid-build changes happened that might have been incompletely applied

---

## New Phase 9: Review QA Report and Triage

When the QE agent reports done, read `qa-report.md`. Your job is now triage, not testing.

### If verdict is PASS:

1. Read the passed tests section — verify the QE agent actually tested thoroughly (not just rubber-stamped)
2. Check that every contracted endpoint has at least one test result
3. Check that the happy path was tested end-to-end
4. If satisfied: the build meets the Definition of Done

### If verdict is FAIL:

For each critical issue:

1. **Identify the responsible agent** (the QE report should suggest this)
2. **Determine the fix type**:
   - **Implementation bug**: Re-spawn the responsible agent with the QE's reproduction steps
   - **Contract bug**: Follow the Contract Change Protocol, then re-spawn affected agents
   - **Unclear ownership**: Read the code yourself to determine which agent is responsible
3. **Re-spawn and fix** — send the agent the exact issue from the QA report:
   ```
   The QE agent found this issue:

   CRIT-1: POST /api/v1/sessions returns 500 when body is empty
   - Expected: 422 with error envelope {"error": "...", "code": "...", "details": [...]}
   - Actual: 500 with stack trace "TypeError: Cannot read property 'title' of undefined"
   - Reproduction: curl -s -X POST http://localhost:8000/api/v1/sessions -H "Content-Type: application/json" -d '{}'

   Fix this and verify it works before reporting done.
   ```
4. **Re-run QE** — after fixes, either:
   - Re-spawn the QE agent for a full retest (if many fixes were made)
   - Ask the QE agent to verify just the fixed issues (if fixes were isolated)

### Triage Priority

1. Contract conformance failures (fix first — these block everything)
2. Integration failures (happy path broken)
3. CORS issues (common, high-impact, usually one-line fix)
4. Edge case failures (fix if they affect acceptance criteria)
5. Warnings (fix if time permits)

---

## Modified Execute Section

The Execute section in the main SKILL.md changes from:

```
10. Validate — contract diff first, then agent-level validation, then end-to-end testing
11. Fix failures — re-spawn agents for implementation bugs; follow cascading failure protocol for contract bugs
```

To:

```
10. Spawn QE agent — with all contracts, service info, agent ownership, and acceptance criteria
11. Review QA report — triage issues by type (contract bug vs implementation bug vs unclear)
12. Fix failures — re-spawn agents with QE's reproduction steps; re-run QE after fixes
```

---

## When NOT to Use the QE Agent

- **Very simple projects** (1-2 endpoints, minimal frontend): The lead can validate faster than spawning and reading a QE report
- **Spike/prototype builds**: If the goal is "does this approach work?" not "is this production-ready?"
- **Single-agent builds**: No integration surfaces to test across

**Rule of thumb**: If Phase 8 would take the lead less than 5 minutes of manual testing, skip the QE agent. If it would take 15+ minutes, the QE agent pays for itself.

---

## File Placement

Place the QE agent file at `agents/qe.md` relative to the main skill:

```
build-with-agent-team/
├── SKILL.md              (orchestrator)
├── agents/
│   └── qe.md             (this file)
├── contracts/
│   └── templates/        (future: contract templates)
└── references/           (future: tech stacks, examples)
```
