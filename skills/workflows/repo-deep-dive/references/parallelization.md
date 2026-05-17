# Parallelization, Scope, and Working With the Research Doc

How to run deep dives faster, when to shrink the scope, and how to reconcile the research doc with the codebase.

## Parallelization Strategy

Deep dives are expensive but parallelizable. Use subagents aggressively:

**Phase 2 (architecture mapping):** Dispatch 3-4 agents to explore different code areas simultaneously. Each reports back a summary of what they found.

**Phase 3 (subsystem deep dives):** Once you have the architecture map, dispatch one agent per subsystem document. Each agent writes its document independently. This is the biggest time saver — 8 documents written in parallel instead of sequentially.

**Phase 4 (comparison/assessment):** These require the earlier documents as context, so they run after Phase 3 completes. But the comparison and frontier docs can be written in parallel with each other.

When running without subagents, work through the documents sequentially. The architecture doc (02) should be written first since all subsystem docs reference it.

## Adapting the Scope

Not every project needs 14 documents. Adjust the scope based on the codebase:

| Codebase Size | Documents | Approach |
|---------------|-----------|----------|
| < 10k LoC | 6-8 | Combine subsystems, shorter docs |
| 10k-100k LoC | 10-12 | Standard deep dive |
| 100k+ LoC | 12-14 | Full treatment, split large subsystems |

The comparison and frontier documents are always included — they're the strategic payoff that makes the deep dive worth more than just reading the source.

## Working with the Deep Research Document

The Deep Research doc is your starting hypothesis. The codebase is the ground truth.

Common patterns:

- **Research says X, code confirms X** — great, cite both and note the consistency
- **Research says X, code shows Y** — this is gold. Document the discrepancy. Often the research reflects the project's aspirations while the code shows current reality.
- **Research mentions feature Z, code has no trace** — planned but unimplemented, or removed. Note it in the gap analysis.
- **Code has feature W, research doesn't mention it** — undocumented capability. These discoveries are some of the most valuable outputs of a deep dive.

## What Makes a Great Deep Dive

The best deep dives share these qualities:

1. **They teach** — someone reading the output understands the project deeply, not just superficially
2. **They're honest** — gaps, limitations, and "this is impressive" moments are both documented
3. **They connect** — the comparison docs don't just list differences, they identify convergence opportunities
4. **They're actionable** — the frontier assessment tells you what to build next, not just what exists
5. **They're precise** — hard numbers, specific file paths, exact function names — not vague summaries
