# 06 — The Eval System

## The Problem

Running 31 evals costs ~$4 every time, even when you only changed `/retro`.
And if you can't test your skills, you can't trust them. Most AI skill systems
have zero validation — you write the prompt, cross your fingers, and ship.

## Architecture: 3 Tiers

### Tier 1: Static Validation (Free, <1s)
**File:** `test/skill-validation.test.ts`
**What it does:**
- Parses every `$B` command in all SKILL.md files
- Validates each command exists in the command registry (`browse/src/commands.ts`)
- Validates snapshot flags against `SNAPSHOT_FLAGS` array
- Validates flag combinations are legal
- Runs on every `bun test` — catches typos and removed commands instantly

**Completeness guardrail:** A unit test validates that every E2E test name has
a touchfiles entry. New tests without entries fail `bun test` immediately.

### Tier 2: E2E (~$3.85/run)
**File:** `test/skill-e2e.test.ts`
**What it does:**
- Spawns a real Claude session via `claude -p` as a subprocess
- Pipes the skill prompt via stdin
- Streams NDJSON output for real-time progress (tool-by-tool)
- Records: turns used, tool calls, browse errors, exit reason
- Extracts machine-readable diagnostics per result

**Session Runner** (`test/helpers/session-runner.ts`):
- Spawns `claude -p` (not Agent SDK — works inside Claude Code sessions)
- `parseNDJSON()` is a pure function — independently testable
- Heartbeat logging during execution
- Extracts: `exit_reason`, `timeout_at_turn`, `last_tool_call`

### Tier 3: LLM-as-Judge (~$0.15/run)
**File:** `test/skill-llm-eval.test.ts`
**What it does:**
- Uses planted-bug fixtures (known bugs injected into test code)
- Claude Haiku attempts to find the bugs
- Claude Sonnet judges Haiku's response using structured rubrics
- `judgePassed()` extracts pass/fail — independently testable

## Diff-Based Test Selection

### How It Works
**File:** `test/helpers/touchfiles.ts`

Each test declares its file dependencies:
```typescript
const E2E_TOUCHFILES = {
  'qa-quick': ['qa/**', 'browse/src/**'],
  'retro': ['retro/**'],
  'ship-coverage-audit': ['ship/**'],
  // ...
}
```

**GLOBAL_TOUCHFILES** trigger ALL tests:
- `test/helpers/session-runner.ts` (eval infrastructure)
- `test/helpers/eval-store.ts` (persistence)
- `test/helpers/llm-judge.ts` (judge logic)
- `scripts/gen-skill-docs.ts` (generator)

**Execution flow:**
1. `git diff <base>...HEAD --name-only` → list of changed files
2. Cross-reference against each test's touchfiles
3. Only run tests whose dependencies were modified
4. `bun run eval:select` previews which tests would run

**Override:** `EVALS_ALL=1` or `:all` script variants force all tests.

### Cost Optimization
- Change `/retro`? Run 1 test (~$0.30) instead of 31 (~$4.00)
- Change the session-runner? Run all 31 (infrastructure change)
- Preview before spending: `bun run eval:select --json`

## Eval Persistence & Observability

### Data Flow
```
session-runner.ts         eval-store.ts
     ↓                         ↓
[HB] [PL]               savePartial()
(heartbeat)             (per test)
(progress.log)                ↓
     ↓                   _partial-e2e.json
     └─────→ eval-watch.ts ←──┘
             (dashboard reader)
```

### Non-Fatal I/O
All observability writes wrapped in try/catch. Failures never cause tests to fail.
Observability is important but must never be the reason a test suite breaks.

### Machine-Readable Diagnostics
Each result includes:
- `exit_reason`: 'success' | 'timeout' | 'error_max_turns' | 'error_api' | 'exit_code_N'
- `timeout_at_turn`: which turn triggered timeout
- `last_tool_call`: e.g., "Write(review-output.md)"

Enables `jq` queries for automated fix loops:
```bash
jq '.results[] | select(.exit_reason == "timeout")' eval-results.json
```

### Persistence
- **Incremental:** `savePartial()` writes `_partial-e2e.json` after each test
  (atomic: write `.tmp`, `renameSync`)
- **Final:** `EvalCollector.finalize()` writes timestamped file
  (e.g., `e2e-20260314-143022.json`)
- **Survives kills:** Partial results persist alongside final
- **Location:** `~/.gstack-dev/evals/`

### Comparison & Analysis
- `bun run eval:compare` — diffs two runs (auto-picks most recent)
- `bun run eval:summary` — aggregates stats across all runs
- Automatic interpretation: regressions, improvements, efficiency changes
- Commentary: "qa-quick regressed from 8/10 to 6/10 — investigate snapshot parsing"

## E2E Eval Failure Blame Protocol

From CLAUDE.md — a critical operational rule:

> When an E2E eval fails during `/ship`, **never claim "not related to our
> changes" without proving it.**

**Required before attributing a failure to "pre-existing":**
1. Run the same eval on main and show it fails there too
2. If it passes on main but fails on the branch — it IS your change. Trace the blame.
3. If you can't run on main, say "unverified — may or may not be related"

"Pre-existing" without receipts is a lazy claim. Prove it or don't say it.

## Why This Matters

gstack is the only AI skill system with:
1. **Static validation** that catches broken commands in <1s
2. **E2E testing** that spawns real Claude sessions
3. **LLM-as-judge** with planted bugs and structured rubrics
4. **Diff-based selection** that optimizes cost
5. **Eval persistence** with comparison and trend analysis
6. **Non-fatal observability** that never breaks the test suite
7. **A blame protocol** that prevents lazy failure attribution
