# When To Use This vs `ui-brief` — and Two Modes

How this skill differs from its sibling, and how to pick between with-brief and standalone mode.

## `ui-brief` vs `claude-design-brief`

These two skills are siblings, not duplicates. They produce different artifacts for different downstream tools.

| | `ui-brief` | `claude-design-brief` *(this)* |
|---|---|---|
| **Target tool** | Claude Code, frontend-agent, orchestrator | Claude Design (claude.ai canvas / artifact) |
| **Output format** | Long Markdown spec (200–400 lines) saved to repo as `UI-CHALLENGE.md` | Short paste-ready prompt (60–150 lines) saved as `CLAUDE-DESIGN-PROMPT.md` |
| **Use case** | Build the production site / app | Produce hi-fi mockups for stakeholder review |
| **Includes** | Skill-coverage list, DoD with E2E + axe, tech stack, component primitives with implied APIs, screenshot-diff DoD | Pre-answered Q&A for the 13 categories, reference apps, palette/font specifics with fallbacks, "what to ship as artifact" instruction |
| **Excludes** | Q&A pre-answers, "ship as artifact" instructions | Implementation discipline, test commands, monorepo concerns |
| **Length** | 200–400 lines | 60–150 lines |

The two compose cleanly: `ui-brief` for the production build, then `claude-design-brief` from the same research to get a mockup prompt for stakeholder review. They share research and opinion; the artifacts are distinct.

If both skills could fit, ask the user which they want — the answer is usually obvious from context (Claude Design canvas vs Claude Code production build).

## Two Modes — With Existing Brief vs Standalone

The skill produces both flavors. Pick the right entry path based on whether the project already has a written design opinion.

### With-brief mode (a `UI-CHALLENGE.md` exists)

The user has already produced a `ui-brief` spec for the production build, and now wants a Claude Design prompt for stakeholder mockups. The Claude Design prompt is a **translation** of the brief, not a duplicate. Quote 5–8 load-bearing rules from the brief in the Source Material section; reuse the same references; commit to the same hard rules. The two outputs must agree — if they disagree, the project has no coherent design.

Hallmark: a `UI-CHALLENGE.md` already exists at the repo root or in `docs/`.

### Standalone mode (no prior brief)

The user is going straight from research → Claude Design without writing a `ui-brief` first. The prompt has to carry every load-bearing decision on its own. This is a thinner artifact than `ui-brief` but every section still has to be opinion-dense.

Hallmark: no `UI-CHALLENGE.md`. Source material is research notes, a brand brief, a brainstorm transcript, or a verbal vision.

### Both modes share

- The 13-category answer block (coverage guide).
- The reference language (positive + negative).
- The page-by-page frame spec.
- The "what to ship" canvas instruction.
- Length target: 60–150 lines, hard ceiling 250.

What changes between modes is **Section 6 — Source Material**: with-brief mode quotes 5–8 load-bearing rules from `UI-CHALLENGE.md`; standalone mode either omits Section 6 or summarizes the underlying research in 5–8 lines.

### Greenfield vs Rebuild orthogonal

Mode (with-brief / standalone) is a different axis from greenfield (no prior UI exists) vs rebuild (replacing a current site/app). Both axes apply. Most common quadrant in practice: rebuild + standalone (user hates the current site, wants mockups fast, no time for a long brief).
