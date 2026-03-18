# 06 — Build vs Wrap Decisions

## Thesis

The fastest path to the future is:

- keep strong upstream systems upstream
- wrap them at clear boundaries
- extract only the pieces that are already product-like
- fork only when repeated adapter pressure proves the seam is wrong

## Decision table

| System | Keep upstream | Wrap | Extract | Fork only if | Avoid |
|--------|---------------|------|---------|--------------|-------|
| `beads` | Yes | Yes | Lightly | storage or schema changes are repeatedly blocked upstream | rewriting the task graph first |
| `gastown` | Mostly | Yes | Selectively | the execution model must become multi-user or service-hosted | cloning the whole Mad Max UX and terminology before product fit |
| `gstack` | Partly | Yes | Strongly | service extraction proves impossible without deep changes | loading the full skill pack into every worker |
| current repo | No need as product | Yes | Strongly | schema generation cannot become runtime-neutral | treating prompt files alone as the final platform |

## Repo-by-repo guidance

### beads

Recommended strategy:

- treat beads as the durable work graph
- integrate through CLI, library, or MCP boundary
- add structured references from work items to external evidence

Why:

- its responsibility is clear
- its value compounds with real usage history
- replacing it early creates unnecessary database and sync work

Likely custom surface:

- finding-to-bead creation
- evidence reference fields
- policy metadata labels

### gastown

Recommended strategy:

- use as the reference execution control plane
- begin with plugins, wrappers, and template changes
- only fork after operator UX and service-hosting requirements are proven

Why:

- it already solved hard problems:
  - session lifecycle
  - worktree isolation
  - multi-runtime dispatch
  - merge and patrol behavior

What not to inherit too early:

- all terminology
- every built-in UX assumption
- full local-town operating model

### gstack

Recommended strategy:

- extract service-shaped assets
- keep skill-pack semantics as reference logic, not the final deployment format

Extract first:

- browse daemon
- review engine shape
- design audit logic
- eval framework

Do not extract first:

- every slash command
- every Claude-specific prompt detail
- every developer workflow opinion

### current repo

Recommended strategy:

- use it as a compiler source, not as the runtime

Extract first:

- contract schemas
- ownership planning
- QA gate schema
- role capability metadata

Why:

- it already models the missing policy layer
- it is easier to convert prompt rules into generated policies than to invent them from zero

## Adapter surfaces to define now

| Adapter | Purpose |
|---------|---------|
| `quality-runner` | call review, browse, QA, and design services in a provider-neutral way |
| `bead-publisher` | persist findings, decisions, gates, and resumable workflow state |
| `policy-compiler` | turn plans and contracts into spawn constraints and merge rules |
| `evidence-publisher` | store screenshots, traces, and logs with durable ids |
| `worker-scorecard` | publish quality and cost outcomes back to the router |

## The anti-patterns

### Anti-pattern 1: The mega-fork

Symptoms:

- copy code from all repos into one new repo
- patch everything locally
- lose upstream velocity immediately

Why it fails:

- too much surface area
- no stable boundaries
- impossible upgrade story

### Anti-pattern 2: Prompt-only unification

Symptoms:

- try to solve all integration with longer prompts
- no structured artifacts
- no shared evidence or policy objects

Why it fails:

- invisible state
- fragile handoffs
- no operational introspection

### Anti-pattern 3: Database-first rewrite

Symptoms:

- replace beads before proving the product flow

Why it fails:

- lots of engineering effort
- little product learning

## The recommended approach in one sentence

Wrap `beads`, harness `gastown`, extract `gstack`, compile policy from the
current repo, and only fork where repeated product pressure leaves no choice.
