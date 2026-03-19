# 05 — Merge System

## The Problem

When 5+ agents work in parallel on isolated branches, merging their work back
into the canonical branch produces conflicts. Manual conflict resolution
doesn't scale. Overstory solves this with a FIFO merge queue and 4-tier
automatic conflict resolution.

## FIFO Merge Queue

The merge queue (`src/merge/queue.ts`) is backed by `merge-queue.db` (SQLite).
Branches are merged in the order they complete — first-done, first-merged.

```typescript
interface MergeEntry {
  branchName: string;
  taskId: string;
  agentName: string;
  filesModified: string[];
  enqueuedAt: string;
  status: "pending" | "merging" | "merged" | "conflict" | "failed";
  resolvedTier: ResolutionTier | null;
}
```

Status flow: `pending → merging → merged` (happy path) or
`pending → merging → conflict → failed` (all tiers exhausted).

## 4-Tier Conflict Resolution

Each tier is attempted in order. If a tier fails, the next is tried.
Disabled tiers are skipped. The resolver checks mulch for historical
conflict patterns to skip tiers known to fail for these files.

### Tier 1: Clean Merge

```bash
git merge --no-edit <branch>
```

Exit code 0 = success, done. No conflicts, no drama.

### Tier 2: Auto-Resolve (Keep Incoming)

When git reports conflicts, Overstory parses the conflict markers:

```
<<<<<<< HEAD
canonical content
=======
incoming (agent) content
>>>>>>> branch
```

**Default behavior:** Keep the incoming (agent) changes, discard canonical.

**Safety check:** Before auto-resolving, `hasContentfulCanonical()` checks
if the canonical side has non-whitespace content. If it does, auto-resolving
would silently discard real work — so the file is escalated to a higher tier
instead. This prevents data loss.

**Union merge:** Files with `merge=union` gitattribute get both sides
concatenated instead of incoming-only. Used for files like `.seeds/issues.json`
where dedup-on-read handles duplicates.

### Tier 3: AI-Resolve

For conflicts that auto-resolve can't handle safely, Overstory spawns a
headless Claude session:

```bash
claude --print "You are a merge conflict resolver. Output ONLY the resolved
file content. Rules: NO explanation, NO markdown fencing, NO conversation,
NO preamble. Output the raw file content as it should appear on disk.
Choose the best combination of both sides of this conflict:

[conflict content]"
```

**Validation:** The output is checked for prose patterns (`looksLikeProse()`).
If Claude responds conversationally instead of outputting code, the file
escalates to the next tier.

**Historical enrichment:** When mulch has recorded past successful resolutions
for overlapping files, they're included in the prompt as context.

**Runtime-neutral:** Uses `runtime.buildPrintCommand()` so any configured
runtime (not just Claude) can do AI resolution.

### Tier 4: Re-imagine

The nuclear option. Aborts the merge entirely and reimplements the changes
from scratch:

1. `git merge --abort`
2. For each modified file:
   - Get the canonical version: `git show main:file`
   - Get the branch version: `git show branch:file`
   - Spawn Claude with both versions: "Reimplement the changes from the
     branch version onto the canonical version"
3. Validate output isn't prose
4. Write and commit

This tier handles cases where the conflict is so entangled that resolution
isn't possible — the AI needs to understand the intent and rewrite.

## Mulch-Informed Learning

The merge system learns from history via mulch:

### Before Merging: Query History

```typescript
const history = await queryConflictHistory(mulchClient, entry);
// Returns: { skipTiers, pastResolutions, predictedConflictFiles }
```

**Skip tiers:** If a tier has failed >= 2 times for overlapping files
and never succeeded, it's skipped entirely. No point trying auto-resolve
on files that always need AI resolution.

**Past resolutions:** Successful resolution descriptions are injected into
the AI prompt for tier 3, giving context about what worked before.

**Predicted conflicts:** Files from historical patterns that overlap with
the current merge — early warning about likely trouble spots.

### After Merging: Record Pattern

```typescript
recordConflictPattern(mulchClient, entry, tier, conflictFiles, success);
// Records: "Merge conflict resolved at tier ai-resolve.
//           Branch: worker/builder-1/task-abc.
//           Agent: builder-1.
//           Conflicting files: src/api/routes.ts, src/types.ts."
```

This creates a durable record in mulch's architecture domain, tagged with
`merge-conflict`. Future merges query this history before starting.

## Pre-Merge Housekeeping

Before attempting a merge, the resolver:

1. **Checks current branch** — skips checkout if already on canonical
2. **Auto-commits os-eco state files** — `.seeds/`, `.overstory/`, `.mulch/`,
   `.canopy/`, `.claude/`, `CLAUDE.md` get auto-committed so they don't block
   merges. These change during normal orchestration and aren't "real" conflicts.
3. **Stashes remaining dirty files** — anything else gets stashed and restored
   after the merge
4. **Deletes overlapping untracked files** — untracked files that would be
   overwritten by the incoming branch are removed so git merge can proceed

## Merge Result

```typescript
interface MergeResult {
  entry: MergeEntry;          // Updated entry with final status
  success: boolean;
  tier: ResolutionTier;       // Which tier resolved it
  conflictFiles: string[];    // Files that conflicted
  errorMessage: string | null;
  warnings: string[];         // Content drop warnings, untracked file deletions
}
```

## Design Decisions

### Why FIFO, Not Priority-Based?

First-done, first-merged is the simplest strategy that avoids starvation.
Priority-based merging could theoretically merge important work first, but:
- It adds complexity with little benefit
- Earlier completions tend to be simpler (less conflict-prone)
- The canonical branch stays maximally up-to-date for later merges

### Why Keep Incoming by Default?

Agent work is the new work — it's what someone asked to be done. Canonical
content is what was there before. When they conflict, the agent's intent
usually wins. The safety check (`hasContentfulCanonical()`) prevents cases
where canonical content matters.

### Why Re-imagine Instead of Manual Resolution?

At scale (10+ agents), manual conflict resolution is the bottleneck. The
reimagine tier keeps the pipeline flowing. If it fails, the merge fails
cleanly and can be escalated to a human — but most of the time, the AI
can rewrite the intent onto the new base.
