---
name: architecture-rescue
version: 1.0.0
description: "Find deepening opportunities in a codebase: shallow modules, missing seams, leaky abstractions. Apply the deletion test (would removing this module concentrate complexity or just move it?) and the two-adapter rule (one adapter = hypothetical seam, two = real seam). Present numbered candidates with locality/leverage benefits. Drop into a grilling session before proposing concrete interfaces. Use this skill when the codebase feels tangled, tests are hard to write, modules feel 'shallow', or it's time for a quarterly architecture review. Trigger on: 'improve architecture', 'rescue this codebase', 'find refactoring opportunities', 'this is a mess', 'ball of mud', 'consolidate modules', 'make it testable', 'shallow modules', 'deepen modules'."
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed-tools: ["Read", "Grep", "Glob", "Write"]
composes_with: ["grill-me", "maintain-context", "diagnose-loop"]
spawned_by: []
---

# architecture-rescue

Diagnose a tangled codebase. Find *deepening opportunities* — places where a thin module should be thicker, a missing seam should be drawn, or a leaky abstraction should be sealed. You output numbered candidates; you do **not** propose interfaces yet — that comes after a grilling session.

## Glossary (in passing — full defs in `references/architecture-language.md`)

- **Module** — a unit of code that hides a decision behind a name.
- **Interface** — the surface a caller sees; everything that isn't implementation.
- **Depth** — interface-to-implementation ratio. Deep = small interface, large implementation. Shallow = the inverse, and usually a smell.
- **Seam** — a place you can substitute behavior (for testing, swapping, isolating).
- **Adapter** — a thin shim translating between two interfaces.
- **Leverage** — change one place, many callers benefit.
- **Locality** — related decisions live next to each other.

The reference doc carries an `_Avoid_:` alias list for each term — stay inside the canonical vocabulary in everything you write.

## The deletion test

> *Imagine deleting this module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, the module was earning its keep.*

Example: a `UserService` whose every method is `return userRepo.findX(...)` — delete it and callers just call the repo. Complexity vanishes. It's a pass-through. Contrast: a `BillingService` that delete-tests into 40 callers each redoing tax + proration logic. Complexity reappears. The module *was* concentrating something.

## The two-adapter rule

> *One adapter = a hypothetical seam. Two adapters = a real seam — promote it to an explicit interface.*

Example: `S3Storage` alone is a wrapper around one SDK. Two implementations — `S3Storage` and `LocalDiskStorage` — and there is now a real `BlobStore` interface hiding in the codebase. Name it. Make it explicit. Stop pretending the second adapter is incidental.

## Process

1. **Survey the tree.** `Glob` the source roots, count files per module, note the top-level decomposition. Read 3–5 modules end-to-end — pick ones the user names as "messy" or, lacking that, the largest and most-imported.
2. **Apply the tests.** For each candidate, run the deletion test in your head. Look for two-adapter pairs (search for `class.*implements`, parallel filenames like `*Memory.*` / `*Postgres.*`, or duplicated method shapes across files).
3. **Write up numbered candidates.** Each candidate: file references, problem statement, plain-English solution, **locality** benefit, **leverage** benefit. Be specific — line numbers, not vibes.
4. **Hand off to `grill-me`.** The candidate list is the *agenda*. Invoke `grill-me` to walk the design tree on whichever candidate the user picks. Do not skip to interface design — the grilling reveals the third option you couldn't see from one design.
5. **If grilling introduces a new term** (a renamed concept, a domain noun the codebase didn't have), invoke `maintain-context` so the new term lands in `CONTEXT.md` / the project glossary before code changes.
6. **Only after grilling, propose the explicit interface.** Use the *Design It Twice* pattern in `references/interface-design.md` — sketch two genuinely different interfaces, compare, pick or merge.

## Candidate output format

```text
### N. <short name>

- **Files:** path/to/foo.ts:120-180, path/to/bar.ts
- **Problem:** <one or two sentences — what's shallow, leaky, or missing>
- **Solution (plain English):** <what you'd do, not how>
- **Locality:** <what moves closer together>
- **Leverage:** <who benefits, and how many callers>
```

Keep findings tight. A page of well-aimed candidates beats a 30-page report no one reads.
