---
name: diagnose-loop
version: 1.0.0
description: |
  Disciplined bug-diagnosis loop where Phase 1 — building a fast deterministic feedback loop — IS the skill. The remaining phases (reproduce, hypothesize, instrument, fix, regression-test, cleanup) mechanically consume the loop's signal. Make sure to use this skill whenever the user reports a hard bug, a flaky test, a performance regression, or says they've been "staring at this for an hour." Trigger on: "diagnose this", "debug this", "why is this broken", "it sometimes fails", "performance regression", "I can't reproduce it", "what's wrong with this", "this test is flaky", "intermittent failure".
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: []
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
composes_with: ["playwright", "qe-agent"]
spawned_by: []
---

# Diagnose Loop

> **Tradeoff caveat.** This skill biases toward thoroughness over speed. For trivial bugs with obvious causes (typos, off-by-one, a missing import the stack trace already points at), skip phases and just fix it. For everything else — flaky tests, performance regressions, "it works on my machine," intermittent failures, anything you've stared at for more than 15 minutes — the discipline is the point. Adapted from mattpocock's `diagnose` pattern.

## Phase 1 — Build a feedback loop (THE SKILL)

**Spend disproportionate effort here. Be aggressive. Be creative. Refuse to give up.**

Every later phase mechanically consumes Phase 1's output. A fast deterministic loop turns hypothesizing into a binary search; a slow or noisy loop turns it into guessing. Building the loop is the work — the rest is bookkeeping.

A good loop has three properties: it runs in seconds, it returns a binary pass/fail signal, and it fails for the same reason every time. Optimize for those before doing anything else.

### Ten ranked ways to construct a loop

In order of cost — pick the cheapest one that actually reproduces the bug.

1. **Existing failing test** — cheapest possible signal; the harness already exists.
2. **New failing test that captures the bug** — write the assertion, watch it fail, then start.
3. **`curl` / HTTP request that reproduces** — for API and webhook bugs; capture as a shell script so it replays in one line.
4. **CLI command + `diff` against known-good output** — golden-file testing for any tool that emits text.
5. **Headless browser script** (Playwright/Puppeteer) for UI bugs — compose with the `playwright` skill.
6. **Trace/log replay** — when the bug only happens in production, dump the request and replay it locally.
7. **Throwaway harness script** in the repo's language — a 20-line file that imports the buggy module and exercises it directly.
8. **Property-based / fuzz test** — when the bug is data-dependent and you don't yet know which input triggers it.
9. **`git bisect`** — when the bug is recent and a known-good commit exists; the loop *is* the bisect script.
10. **Differential testing** against a reference implementation — for parser, compiler, or protocol bugs where "correct" is defined elsewhere.

**Last resort:** Human-in-the-loop bash harness — the user runs a step, the agent reads stdout. See `scripts/hitl-loop.template.sh`. Use this only when none of the above are reachable (e.g., bug needs physical hardware, a paid third-party service, or a manual UI step). Concrete snippets for all ten methods live in `references/feedback-loop-recipes.md`.

## Iterate on the loop itself

Make the loop faster, sharper, and more deterministic *before* using it to investigate. A 30-second loop that fires automatically beats a 5-second loop you have to remember to run. Sharpen by narrowing the test surface, stripping irrelevant setup, and removing log noise that hides the signal.

## Non-deterministic bugs

If the bug reproduces less than half the time, you don't have a loop yet — you have a coin flip. Raise the reproduction rate from ~1% to ~50% before doing anything else. Methods:

- Tighten the loop (smaller test surface, fewer dependencies)
- Run it in parallel (`for i in {1..20}; do ...; done &`) to surface races
- Deliberately stress the system: throttled CPU, slow network, constrained memory, deliberate clock skew

## Phase 2 — Reproduce

Run the loop and confirm it shows *the user's* failure, not a nearby one. Read the failing assertion or output character-by-character against the reported symptom. Two bugs that look alike are still two bugs.

## Phase 3 — Hypothesize

Generate three to five ranked falsifiable hypotheses. Each one uses the format in `references/hypothesis-format.md`: "If `<X>` is the cause, then `<changing Y>` will make the bug disappear." Show the list to the user before testing any of them — the user often knows which one is most likely from context the agent doesn't have.

## Phase 4 — Instrument

Test one hypothesis at a time. Change one variable per loop iteration. Tag every debug log, print, or breakpoint with a unique token like `[DEBUG-7f3a]` (any short random string works) so Phase 6 cleanup is a single `grep -r '\[DEBUG-7f3a\]'`. Untagged debug output is how `console.log("here")` ships to production.

## Phase 5 — Fix and regression test

Write the regression test at the *correct seam* — the smallest scope where the bug is observable. If the natural seam doesn't exist (the test would have to reach into private implementation details to observe the failure), note this in the PR. A missing seam is a signal that the module has an architectural problem; recommend a follow-up invocation of `architecture-rescue` rather than papering over it with a brittle test.

## Phase 6 — Cleanup and post-mortem

1. `grep -r '\[DEBUG-xxxx\]' .` — every tagged line comes out.
2. Run the original Phase 1 loop one more time. It must still fail on the pre-fix commit and pass on the post-fix commit.
3. Commit the *hypothesis* — the real root cause — in the PR message, not just "fixed bug." Future-you debugging a regression will thank present-you.
4. If a missing seam blocked Phase 5, recommend `architecture-rescue` as a follow-up issue.

## Anti-pattern

> **Forbidden:** Skipping Phase 1. If you don't have a fast deterministic loop, no amount of staring at code will find the bug. Reading code without a loop is guessing with extra steps.
