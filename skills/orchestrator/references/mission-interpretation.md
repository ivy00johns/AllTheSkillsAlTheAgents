# Mission Interpretation

> The single most common failure mode of `/orchestrator` is treating the
> mission/plan as a feature list to be flattened into agent prompts, when it's
> actually a multi-phase script the orchestrator should EXECUTE end-to-end.

This reference covers two things:

1. How to read a mission/plan correctly (phases, explicit skill mentions, deferred items)
2. The skill-trigger heuristic — when each composable skill earns its keep

## Read the mission as a script, not a wishlist

When the user hands you a mission document (`MISSION.md`, `PLAN.md`, or a long
paste), look for organizing markers:

- **Numbered steps** (`1.`, `2.`, …) → individual deliverables you must close
  out one by one
- **Phase headings** (`## Phase 0`, `## Phase 1`, …) → groups of steps that
  happen in order; later phases consume earlier-phase outputs
- **Explicit skill mentions** (`/skill-name`, "use the X skill", references
  to specific tooling like Nano Banana, ux-review, Playwright, claude-mem) →
  directives to YOU to INVOKE those skills, not to mention them in agent
  prompts

The mission is a contract you signed by invoking `/orchestrator`. The
deliverable is "every step closed out" — either done, or with a written
reason for being deferred. Don't ship a build that silently drops half the
list.

### Build the mission skill manifest

Before any agent dispatch, scan the entire mission for skill mentions and
write `coordination/MISSION_SKILLS.md`:

```markdown
# Mission skill manifest — <project>

Scanned from MISSION.md on <date>. Each skill must be either invoked
(✅) or have a one-line reason for skipping recorded here.

## Phase 0 — Discovery
- [ ] repo-deep-dive ×3 (Stripe, eBay, Mastodon)
- [ ] llm-wiki — bootstrap wiki for project
- [ ] wiki-research — extract relevant pages before plan

## Phase 1 — Brainstorm
- [ ] brainstorming
- [ ] plan-builder
- [ ] writing-plans
- [ ] mermaid-charts — architecture diagram

## Phase 2 — Contracts + Visual assets
- [ ] contract-author
- [ ] nano-banana — 8 listing photos + hero + fraud-shield

## Phase 3 — Parallel build
- [ ] backend-agent, frontend-agent, db-migration-agent, infrastructure-agent
- [ ] security-agent, observability-agent, performance-agent, docs-agent
- [ ] qe-agent (mandatory)
- [ ] frontend-design + ui-ux-pro-max during frontend-agent's work
- [ ] claude-api — fraud-scoring module with prompt caching
- [ ] feature-dev — mid-build shipping-label feature

## Phase 4 — Verify
- [ ] contract-auditor
- [ ] code-review
- [ ] security-review
- [ ] simplify
- [ ] playwright — E2E happy path
- [ ] ux-review — full UX audit

## Phase 5 — Ship
- [ ] deployment-checklist
- [ ] railway-deploy
- [ ] git-commit, git-pr, git-pr-feedback

## Phase 6 — Post-launch
- [ ] schedule — fraud rollout flag ramp
- [ ] loop — status check every 5 min
- [ ] claude-mem:timeline-report
- [ ] claude-mem:knowledge-agent

## Phase 7 — Meta (ecosystem refactor)
- [ ] skill-review, skill-update, skill-writer

## Phase 8 — Tidy
- [ ] git-post-merge-cleanup, sync-skills
```

Tick boxes as you go. At end-of-build, every box must be either ✅ or
annotated with a deferral reason. Empty boxes are bugs.

## Skill-trigger heuristic

A working orchestrator session weaves in other skills at the points where
they earn their keep. This table maps "build situation" → "skill to invoke".

| Situation in the build | Skill to invoke | Where in the flow |
|---|---|---|
| Mission references existing repos as inspiration ("study Stripe / eBay / Mastodon") | `repo-deep-dive` per repo | Phase 0, before plan |
| Mission asks for a persistent knowledge base or "second brain" | `llm-wiki` | Phase 0, alongside repo-deep-dive |
| Project has an Obsidian wiki already | `wiki-research` | Phase 0, before reading raw source |
| Mission is one paragraph; need to flesh out the design first | `brainstorming` | Phase 1, before plan-builder |
| Have research notes/PRD that need to become an executable plan | `plan-builder` | Phase 1 |
| Need a long, structured plan document | `writing-plans` | Phase 1 |
| Architecture has >10 services or layers | `mermaid-charts` | Phase 1, output goes into wiki/docs |
| Multi-service build with API surface, events, or shared types | `contract-author` | Phase 2, before any agent dispatch |
| Mission asks for product imagery, hero banners, category icons, lifestyle shots | `nano-banana` | Phase 2, BEFORE frontend agent (so it has real assets to reference) |
| Need a paste-ready hi-fi mockup prompt for Claude Design | `claude-design-brief` | Phase 2, before frontend handoff |
| Need a long-form UI brief for a frontend agent | `ui-brief` | Phase 2, before frontend-agent dispatch |
| Frontend build with any UI surface | Require frontend-agent to invoke `frontend-design` + `ui-ux-pro-max` | Phase 3, in the frontend-agent prompt |
| Anthropic SDK / fraud-scoring / any Claude API integration | `claude-api` | Phase 3, in the relevant backend slice |
| Mid-build feature addition with codebase understanding required | `feature-dev` | Phase 3, after core scaffolding |
| Any project that ships code | `qe-agent` (mandatory), `security-agent` | Phase 3 |
| Need to validate every implementation against its contract | `contract-auditor` | Phase 4 |
| Diff review pass | `code-review` (or `/code-review:code-review`) | Phase 4 |
| Security-only diff pass | `security-review` (or `/security-review`) | Phase 4 |
| Find dead code, premature abstractions, duplicated logic | `simplify` | Phase 4 |
| E2E happy-path validation with a real browser | `playwright` | Phase 4 |
| Full visual + accessibility + responsive audit | `ux-review` | Phase 4, ON the running app |
| Ready to ship | `deployment-checklist`, then `railway-deploy` (or equivalent) | Phase 5 |
| Conventional commit | `git-commit` | Throughout |
| Open the PR | `git-pr` | Phase 5 |
| Handle review comments | `git-pr-feedback` | Phase 5 |
| Need to monitor a deploy or watch state change every N minutes | `loop` | Phase 6 |
| Schedule a recurring routine (flag ramp, nightly job) | `schedule` | Phase 6 |
| Narrate what happened in the build | `claude-mem:timeline-report` | Phase 6 |
| Build a queryable expert brain from the build's observation history | `claude-mem:knowledge-agent` | Phase 6 |
| Search persistent memory for prior solutions before designing | `claude-mem:mem-search` | Phase 0 or wherever a "have we solved this?" question lands |
| Post-build skill ecosystem audit | `skill-review`, `skill-update`, `skill-writer` | Phase 7 |
| Stale worktrees and branches | `git-post-merge-cleanup`, `sync-skills` | Phase 8 |

## When the user explicitly names a skill

If the mission says "use Nano Banana for X" or "/ux-review the UI after build",
that's a binding directive. The audit trail in `MISSION_SKILLS.md` either
shows that skill ✅ invoked or carries the reason for the deferral. There
is no third option — silently skipping a named skill is what produced the
"why no listings, no fancy UI, no images" failure mode.

## How the conductor metaphor works

The orchestrator is a conductor:

- **Conductors don't play every instrument**, but they signal each section
  when it's their measure. The orchestrator doesn't write CSS — but it
  signals `frontend-design` + `ui-ux-pro-max` when the frontend agent is up,
  and `nano-banana` when imagery is needed, and `ux-review` when the build
  is done.
- **Conductors hold the score**, which here is the mission + the
  `MISSION_SKILLS.md` checklist. If the mission has eight movements (Phases
  0–7), you conduct eight movements. Stopping at movement three because the
  band sounds OK is not the job.
- **Conductors keep tempo across waves**. Wave gates, contract diffs, and
  QA gates are the metronome — between every wave of parallel agents, you
  pause and check the integrated state before signaling the next entrance.
