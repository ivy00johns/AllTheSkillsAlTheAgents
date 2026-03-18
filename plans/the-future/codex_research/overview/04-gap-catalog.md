# 04 — Gap Catalog

## Thesis

The future platform is not missing "more agent prompts."
It is missing the shared control fabric that turns three strong systems into one
coherent product.

## Gap summary

| Gap | Severity | Why it matters |
|-----|----------|----------------|
| Runtime-neutral quality layer | Critical | gstack intelligence does not travel cleanly across runtimes |
| Policy and contract engine | Critical | no shared system decides gates, conformance, or ownership across the stack |
| Evidence graph | Critical | screenshots, review outputs, logs, and QA artifacts are not first-class shared objects |
| Quality-aware router | High | gastown can route agents, but not yet using durable quality or capability scores |
| Unified analytics and cost model | High | no repo gives full fleet-level operational visibility |
| Security and multi-user model | High | all three are still local-first and operator-centric |
| Orchestration evals | High | gstack evals skills, but the combined system itself is not validated end to end |
| Productized operator UX | Medium-High | CLI and tmux are powerful but not the full answer for a broader product |
| External event fabric | Medium | GitHub, CI, staging, incidents, and deployments are not unified into one policy system |
| Upgrade and compatibility strategy | Medium | upstream velocity is high and integration drift will be constant |

## Gap 1: Runtime-neutral quality layer

### What exists

- `gstack` has excellent quality logic
- it is mostly expressed as Claude-oriented skills and workflows

### What is missing

- portable APIs for:
  - code review
  - browser QA
  - design audit
  - release checks
  - eval execution

### What to build

- `quality-runner` service
- provider-neutral request schema
- artifact output schema
- minimal runtime adapters for Claude, Codex, Gemini

## Gap 2: Policy and contract engine

### What exists

- the current repo already models contract-first design and QA gates
- `gastown` has patrols and merge flow
- `beads` has gates and formulas

### What is missing

- one place that can compile:
  - contracts
  - ownership
  - gate rules
  - escalation paths
  - convoy or formula policies

### What to build

- `policy-compiler`
- contract and gate schemas
- merge-time conformance checks
- spawn-time ownership planning

## Gap 3: Evidence graph

### What exists

- screenshots in gstack
- logs and runtime state in gastown
- work items in beads

### What is missing

- a shared evidence model linking:
  - screenshot
  - DOM snapshot
  - failing test
  - review note
  - design finding
  - runtime log
  - commit or branch
  - bead or convoy

### What to build

- evidence object store plus metadata index
- references from beads into evidence ids
- operator timeline view

## Gap 4: Quality-aware router

### What exists

- `gastown` supports multiple runtimes and cost tiers
- `gstack` has evals and quality heuristics

### What is missing

- routing that uses:
  - historical review accuracy
  - browser success rate
  - design compliance rate
  - retry rate
  - cost per successful task

### What to build

- capability registry
- worker scorecards
- policy-based runtime selection

## Gap 5: Unified analytics and cost model

### What exists

- partial dashboards in `gastown`
- partial eval persistence in `gstack`
- partial metrics in `beads`

### What is missing

- one operational dashboard for:
  - cost per convoy
  - cycle time per bead
  - retry and stall rate
  - merge success rate
  - quality trend
  - evidence volume

### What to build

- run ledger
- cost ledger
- metrics pipeline
- operator dashboards and alerts

## Gap 6: Security and multi-user model

### What exists

- local-first tooling
- minimal process and filesystem assumptions

### What is missing

- authentication
- authorization
- tenant boundaries
- secret handling
- encrypted persistent data
- audit logs

### What to build

- workspace RBAC
- signed actor identities
- encrypted evidence and state storage
- policy audit trail

## Gap 7: Orchestration evals

### What exists

- `gstack` can test skills

### What is missing

- tests for the combined system:
  - spawn flow
  - routing quality
  - convoy completion
  - review-to-fix loop
  - merge policy correctness
  - resume and recovery behavior

### What to build

- fixture towns
- planted orchestration failures
- branch-level simulation harness
- golden convoy outcomes

## Gap 8: Productized operator UX

### What exists

- tmux, TUI, CLIs, dashboards

### What is missing

- a coherent operator surface for:
  - intent intake
  - live state
  - policy editing
  - evidence review
  - run replay
  - approval workflows

### What to build

- web control plane
- run explorer
- evidence timeline
- approval inbox

## Gap 9: External event fabric

### What exists

- ad hoc integrations

### What is missing

- a unified event stream for:
  - PR opened
  - CI failed
  - deploy completed
  - staging unhealthy
  - incident triggered
  - timer or SLA breached

### What to build

- event bus
- rule engine
- event-to-bead and event-to-convoy bridges

## Gap 10: Upgrade and compatibility strategy

### What exists

- fast-moving upstream repos

### What is missing

- formal compatibility boundaries
- adapter versioning
- upstream sync protocol

### What to build

- compatibility matrix
- adapter contract tests
- upstream mirror and patch queue

## The central pattern

Most gaps are not "missing features inside one repo."
Most gaps are missing shared abstractions between repos:

- shared schemas
- shared evidence ids
- shared policy decisions
- shared scorecards
- shared operator surfaces

That is why the right answer is a thin platform layer, not a giant fork.
