# 08 — Formulas Catalog

42 built-in formula TOML files embedded in the `gt` binary, located at
`internal/formula/formulas/`.

## Development Workflows

| Formula | Description |
|---------|-------------|
| `shiny` | "Engineer in a Box" — design → implement → review → test → submit |
| `shiny-secure` | Shiny + security audit step |
| `shiny-enterprise` | Maximum ceremony workflow |
| `design` | Design-only workflow |
| `code-review` | Code review formula |
| `security-audit` | Security audit workflow |
| `rule-of-five` | Meta-formula: wraps any workflow with 4 additional reviews |

## Release Workflows

| Formula | Description |
|---------|-------------|
| `beads-release` | 20-step release process for the Beads project |
| `gastown-release` | Release process for Gas Town |

## Polecat Workflows

| Formula | Description |
|---------|-------------|
| `mol-polecat-work` | Full polecat lifecycle (10 steps: load → branch → implement → review → build → commit → pre-verify → submit → await-verdict → self-clean) |
| `mol-polecat-code-review` | Code review workflow for polecats |
| `mol-polecat-conflict-resolve` | Merge conflict resolution |
| `mol-polecat-lease` | Polecat session leasing |
| `mol-polecat-review-pr` | PR review workflow |

## Patrol Formulas

| Formula | Description |
|---------|-------------|
| `mol-deacon-patrol` | Deacon's patrol cycle (DYFJ propagation, plugins, cleanup) |
| `mol-witness-patrol` | Witness patrol (polecat health, refinery check, plugins) |
| `mol-refinery-patrol` | Refinery patrol (preflight, MQ processing, post-flight) |

## Dog Formulas

| Formula | Description |
|---------|-------------|
| `mol-dog-backup` | Dolt database backup |
| `mol-dog-compactor` | Data compaction (REBASE stage) |
| `mol-dog-doctor` | Health diagnostics |
| `mol-dog-jsonl` | JSONL file maintenance |
| `mol-dog-phantom-db` | Phantom database cleanup |
| `mol-dog-reaper` | Stale data reaping (DELETE stage) |
| `mol-dog-stale-db` | Stale database detection and cleanup |

## Infrastructure Formulas

| Formula | Description |
|---------|-------------|
| `mol-gastown-boot` | Gas Town startup/bootstrap |
| `mol-shutdown-dance` | Graceful shutdown sequence |
| `mol-town-shutdown` | Full town shutdown |
| `mol-session-gc` | Session garbage collection |
| `mol-sync-workspace` | Workspace synchronization |

## Planning Formulas

| Formula | Description |
|---------|-------------|
| `mol-idea-to-plan` | Idea → implementation plan workflow |
| `mol-plan-review` | Plan review workflow |
| `mol-prd-review` | PRD (Product Requirements Doc) review |

## Convoy Formulas

| Formula | Description |
|---------|-------------|
| `mol-convoy-cleanup` | Convoy cleanup and archival |
| `mol-convoy-feed` | Convoy activity feed generation |

## Maintenance Formulas

| Formula | Description |
|---------|-------------|
| `mol-boot-triage` | Boot's Deacon triage decision workflow |
| `mol-dep-propagate` | Dependency propagation |
| `mol-digest-generate` | Wisp digest/summary generation |
| `mol-orphan-scan` | Orphaned bead detection |

## Fun/Demo Formulas

| Formula | Description |
|---------|-------------|
| `towers-of-hanoi` | Towers of Hanoi (base formula) |
| `towers-of-hanoi-7` | 7-disc Hanoi (127 steps) |
| `towers-of-hanoi-9` | 9-disc Hanoi (511 steps) |
| `towers-of-hanoi-10` | 10-disc Hanoi (1,023 steps — "ran in a few minutes") |

The 20-disc Hanoi would be ~1 million steps and "take about 30 hours."
This trivially solves the MAKER problem (LLMs fail after a few hundred
steps).

## Formula Structure

All formulas follow the same TOML structure:

```toml
description = "What this formula does"
formula = "formula-name"
type = "workflow"          # or "patrol", etc.
version = 1

[[steps]]
id = "step-id"
title = "Step title with {{variables}}"
description = "Detailed instructions..."
acceptance = "What 'done' looks like"
needs = ["prior-step-id"]  # Dependencies

[vars.variable_name]
description = "What this variable is"
required = true             # or false
default = "default-value"   # optional
```

## Formula Commands

```bash
bd formula list              # List available formulas
bd formula show <name>       # Show formula details
bd cook <formula>            # Cook formula → protomolecule
bd mol pour <proto>          # Instantiate → persistent molecule
bd mol wisp <proto>          # Instantiate → ephemeral wisp
bd mol list                  # List active molecules
```
