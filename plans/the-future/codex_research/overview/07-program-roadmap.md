# 07 — Program Roadmap

## Program principle

Each phase must be independently valuable.
Do not wait for the "full vision" before getting a usable win.

## Phase map

| Phase | Theme | Primary outcome |
|-------|-------|-----------------|
| 1 | Portable perception and evidence | agents can see, review, and attach evidence anywhere |
| 2 | Unified graph and policy handoff | all work and quality findings become structured durable state |
| 3 | Quality-aware orchestration | routing, patrol, and merge flow become quality-driven |
| 4 | Productization and federation | the system becomes operable, observable, and expandable |

## Phase 1: Portable perception and evidence

### Goal

Get `gstack`'s highest-value capabilities out of the single-session box.

### Build

- package browse as a service callable from any worker runtime
- define evidence ids and storage conventions
- normalize review and QA outputs into machine-readable schemas
- attach evidence records to work items

### Why this is first

- it creates immediate leverage for every later phase
- it gives agents proof, not assertions
- it reduces "blind agent" failure modes quickly

### Exit criteria

- any worker can browse, screenshot, and publish evidence
- review findings can create structured issues
- operator can inspect evidence tied to a task

## Phase 2: Unified graph and policy handoff

### Goal

Make plans, contracts, tasks, gates, and findings durable and resumable.

### Build

- contract and ownership compiler
- spawn-time policy bundles for workers
- `review -> bead`, `qa -> bead`, `design -> bead` pipelines
- gate beads or equivalent durable policy objects

### Why this is second

- without durable policy objects, orchestration stays ad hoc
- this phase creates the shared language across the stack

### Exit criteria

- every important finding becomes durable state
- every worker gets only the contract slice it needs
- merge and approval gates are data-driven

## Phase 3: Quality-aware orchestration

### Goal

Turn execution from heuristic dispatch into adaptive routing.

### Build

- capability registry
- worker scorecards
- runtime selection policies
- patrol alerts based on quality and retry drift
- merge rules that include quality evidence, not just CI and conflict status

### Why this is third

- only now is there enough history to route intelligently
- otherwise the router is guessing

### Exit criteria

- router can justify why a worker or runtime was chosen
- quality regression changes routing or gate behavior automatically
- merge queue uses evidence and scorecards

## Phase 4: Productization and federation

### Goal

Make the system usable as a real platform, not just a powerful local stack.

### Build

- operator control plane
- cost and analytics dashboards
- auth and RBAC
- multi-project or multi-team boundaries
- federation and external event bridges
- orchestration eval suites

### Why this is last

- productization without working internals is theater
- federation without stable schemas is chaos

### Exit criteria

- one operator can manage multiple projects coherently
- approvals, evidence, and policy history are inspectable
- upstream changes can be absorbed without panic

## Suggested first backlog

1. Define the evidence schema and ids
2. Extract browse as a standalone callable service
3. Define `finding -> bead` and `evidence -> bead` references
4. Compile contract and ownership bundles from the current repo patterns
5. Add a thin router that can choose between at least two runtimes
6. Add scorecards and run ledger entries
7. Build a minimal operator timeline UI

## Success metrics

| Metric | Why it matters |
|--------|----------------|
| Time from finding to tracked work item | proves the quality loop is closed |
| Percentage of tasks with attached evidence | proves work is inspectable |
| Retry rate by worker profile | reveals routing and prompt weakness |
| Merge rejection rate by gate type | reveals where policy is paying off |
| Resume success rate after handoff or compaction | proves durability |
| Cost per successful bead or convoy | keeps the platform economically real |

## Program risk register

| Risk | Mitigation |
|------|------------|
| Upstream drift across three repos | adapter contracts and mirror-based upgrade cadence |
| Prompt bloat | compiled policy bundles and progressive disclosure |
| Too much local-only infrastructure | promote service boundaries before productization |
| Evidence sprawl | strict evidence schema and retention policy |
| Premature hard fork | wrap first, fork later |

## Most important discipline

Treat every phase as a product slice:

- observable
- testable
- useful by itself

That is how this becomes massive without becoming shapeless.
