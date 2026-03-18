# 09 — Repo Reading Map

## Purpose

This is the practical map for studying the codebases without drowning in them.
If you are building the future stack, these are the highest-yield files to read
first.

## gstack reading map

### Start here

- `README.md` — overall philosophy and skill inventory
- `ARCHITECTURE.md` — the system-level design decisions
- `BROWSER.md` — the browse CLI surface and ref model

### For the browser and perception layer

- `browse/src/commands.ts` — the command registry
- `setup-browser-cookies/SKILL.md` — how authenticated browser state is taught to the agent

### For the quality layer

- `review/SKILL.md` — review workflow and bug-finding posture
- `review/checklist.md` — review mechanics
- `review/design-checklist.md` — lightweight design gate logic
- `qa/SKILL.md` — find, fix, verify loop
- `qa/references/issue-taxonomy.md` — normalized QA categories
- `plan-design-review/SKILL.md` — design inference and audit behavior
- `ship/SKILL.md` — release and final validation path

### For drift resistance and evals

- `scripts/gen-skill-docs.ts` — generated-doc pipeline
- `test/helpers/session-runner.ts` — real-session eval runner
- `test/helpers/touchfiles.ts` — diff-based eval selection
- `test/fixtures/review-eval-vuln.rb` — planted-bug eval fixture example

### What these files teach

- how to extract `gstack` into services instead of prompts
- how to preserve eval rigor
- how to carry browser capability into other runtimes

## gastown reading map

### Start here

- `README.md` — the high-level operating model
- `docs/glossary.md` — required vocabulary decoding

### For execution control and runtime abstraction

- `internal/runtime/runtime.go` — runtime abstraction entry point
- `internal/cmd/sling.go` — core dispatch primitive
- `internal/cmd/convoy.go` — convoy surface
- `internal/cmd/mayor.go` — Mayor entry points
- `internal/cmd/handoff.go` — session restart and transfer
- `internal/cmd/seance.go` — prior-session interrogation flow

### For orchestration and durable workflow logic

- `internal/convoy/operations.go` — convoy state management
- `internal/mail/router.go` — message routing
- `internal/mail/mailbox.go` — mailbox behavior
- `internal/formula/README.md` — formula model overview
- `internal/formula/parser.go` — formula parsing
- `internal/formula/formulas/mol-polecat-work.formula.toml` — worker lifecycle example
- `internal/formula/formulas/mol-refinery-patrol.formula.toml` — merge patrol example

### For lifecycle, patrol, and merge

- `internal/witness/manager.go` — witness control loop
- `internal/witness/protocol.go` — witness protocol
- `internal/refinery/manager.go` — merge queue manager
- `internal/refinery/engineer.go` — merge and review behavior
- `internal/refinery/score.go` — merge scoring concepts

### For prompt and plugin seams

- `templates/polecat-CLAUDE.md` — worker prompt template
- `templates/witness-CLAUDE.md` — witness prompt template
- `plugins/quality-review/plugin.md` — especially relevant quality seam

### What these files teach

- where to inject contracts and gates
- where to add quality-aware routing
- where a service-hosted control plane would need to diverge

## beads reading map

### Start here

- `README.md` — essential model and workflow
- `docs/ARCHITECTURE.md` — big-picture internals
- `docs/CLI_REFERENCE.md` — the operational surface
- `AGENT_INSTRUCTIONS.md` — how agents are expected to use beads

### For the storage and graph core

- `internal/storage/dolt/store.go` — main storage engine
- `internal/storage/dolt/schema.go` — schema definition
- `internal/storage/dolt/dependencies.go` — dependency graph behavior
- `internal/storage/dolt/queries.go` — query surfaces
- `internal/storage/dolt/transaction.go` — transaction behavior
- `internal/storage/dolt/federation.go` — federation logic

### For CLI and workflow surfaces

- `cmd/bd/create.go` — issue creation
- `cmd/bd/update.go` — state mutation and claims
- `cmd/bd/close.go` — completion flow
- `cmd/bd/prime.go` — context injection model
- `cmd/bd/graph.go` — graph-oriented user surface
- `cmd/bd/formula.go` — workflow surface
- `cmd/bd/stale.go` — stale and witness-adjacent behavior

### For production-risk and integration seams

- `integrations/beads-mcp/src/beads_mcp/server.py` — MCP routing and context risk surface
- `FEDERATION-SETUP.md` — how federation is expected to work
- `docs/DOLT.md` and `docs/DOLT-BACKEND.md` — operational storage detail
- `docs/OBSERVABILITY.md` — metrics hooks
- `docs/design/dolt-concurrency.md` — concurrency design context

### What these files teach

- what can remain the system of record
- what must stay outside beads
- where production hardening pressure will appear first

## Current repo reading map

This repo is not one of the three target systems, but it is the clearest
source of the missing contract and policy layer.

### Start here

- `README.md` — architecture and intent
- `docs/architecture.md` — diagrams and role map
- `docs/skill-ecosystem-design-spec.md` — the deeper blueprint

### For contract and policy compilation

- `skills/orchestrator/SKILL.md` — coordination contract
- `skills/orchestrator/references/phase-guide.md` — full orchestration phases
- `skills/contracts/contract-author/SKILL.md` — contract generation model
- `skills/contracts/contract-auditor/SKILL.md` — conformance checking

### For QA and gate semantics

- `skills/roles/qe-agent/SKILL.md` — QE workflow
- `skills/roles/qe-agent/references/qa-report-schema.json` — the most reusable gate artifact in the repo
- `skills/workflows/context-manager/SKILL.md` — compaction and continuation model

### What these files teach

- how to compile ownership and contracts before execution
- how to turn QA into machine-readable gate decisions
- how to keep orchestration rules structured instead of conversational

## Suggested study order by build goal

| Goal | Read first |
|------|------------|
| Extract browser and evidence layer | `gstack/BROWSER.md`, `gstack/browse/src/commands.ts`, `gstack/qa/SKILL.md` |
| Improve multi-agent execution | `gastown/internal/runtime/runtime.go`, `gastown/internal/cmd/sling.go`, `gastown/internal/refinery/manager.go` |
| Make work durable and resumable | `beads/internal/storage/dolt/store.go`, `beads/cmd/bd/prime.go`, `beads/cmd/bd/formula.go` |
| Add contracts and gate policies | `skills/orchestrator/SKILL.md`, `skills/contracts/contract-author/SKILL.md`, `skills/roles/qe-agent/references/qa-report-schema.json` |

## Final rule

Do not read these repos front to back.
Read them by intended layer:

- quality
- control
- memory
- policy

That keeps the future architecture legible while you build it.
