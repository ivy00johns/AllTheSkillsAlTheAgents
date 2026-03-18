# 04 — The MEOW Stack (Molecular Expression of Work)

The MEOW stack is the conceptual foundation of Gas Town. Steve describes it as
"more of a discovery than an invention" and believes it will outlive Gas Town
itself. It is a layered system for decomposing, templating, and executing
knowledge work through AI agents.

## The Stack

```
Formulas (TOML source)
    │ bd cook
    ▼
Protomolecules (frozen templates)
    │ bd mol pour / bd mol wisp
    ▼
Molecules (active instances)
    │
    ├── Mol (persistent, git-backed)  ── "Liquid"
    │
    └── Wisp (ephemeral, not in git)  ── "Vapor"
         │
         ├── Root-only (default: steps inline, no sub-beads)
         └── Poured (steps materialized as sub-wisps)
```

At the bottom: **Beads** — the atomic work units. Everything is built from beads.

## Layer by Layer

### 1. Beads (Atomic Work Units)

A bead is a structured issue stored in Dolt (git-backed SQL):

- **ID** — prefix + 5-char alphanumeric (`gt-abc12`)
- **Status** — open, in_progress, blocked, closed
- **Assignee** — agent identity
- **Priority** — P0 (critical) through P4 (backlog)
- **Type** — task, bug, feature, epic, question, docs
- **Labels, notes, design fields** — structured metadata
- **Dependencies** — directed graph edges between beads

**Pinned beads** float like sticky notes and never get closed:
- Role Beads — templates for each role
- Agent Beads — persistent agent identities
- Hook Beads — per-agent work queues

**CLI:** `bd create`, `bd show`, `bd update`, `bd close`, `bd ready`

### 2. Epics (Hierarchical Work)

Beads with children. Children can themselves be epics, creating trees.

- Children are **parallel by default**
- Explicit dependencies force sequencing
- "Upside-down" plans: root is the last thing, leaves are first
- AIs navigate this fine; humans might find it unintuitive

### 3. Molecules (Chained Workflows)

Molecules are **sequenced chains of beads** forming workflows. Unlike epics
(which are trees), molecules can have arbitrary graph shapes including:

- Linear chains (step 1 → step 2 → step 3)
- Fan-out (step 1 → steps 2a, 2b, 2c in parallel)
- Fan-in (wait for all → step 3)
- Loops (FIX_NEEDED → fix → resubmit → await verdict → loop)
- Gates (wait for external event before proceeding)

**Key property:** Molecules are **durable**. If an agent crashes mid-molecule:

1. The agent is persistent (a Bead in Git)
2. The hook is persistent (also a Bead in Git)
3. The molecule is persistent (chain of Beads, also in Git)

A new session starts, finds the molecule on the hook, locates the current
step, and continues.

### 4. Protomolecules (Templates)

Named after The Expanse reference (Claude insisted). Protomolecules are
**classes or templates** — made of actual Beads with instructions and
dependencies pre-configured:

```
Proto: "release"
├── Step: bump-version
├── Step: run-tests (needs: bump-version)
├── Step: build (needs: run-tests)
├── Step: create-tag (needs: build)
└── Step: publish (needs: create-tag)
```

**Instantiation:** Copy all protomolecule beads and perform variable
substitutions to create a live workflow.

### 5. Formulas (TOML Source)

The highest-level abstraction. TOML files that define workflows with:

- **Steps** — ordered, with `needs` dependencies
- **Variables** — substituted at cook time
- **Acceptance criteria** — per-step completion requirements
- **Descriptions** — detailed instructions for the agent

**Example** (simplified `shiny.formula.toml`):

```toml
description = "Engineer in a Box"
formula = "shiny"
version = 1

[[steps]]
id = "design"
title = "Design {{feature}}"
description = "Think carefully about architecture..."

[[steps]]
id = "implement"
needs = ["design"]
title = "Implement {{feature}}"

[[steps]]
id = "review"
needs = ["implement"]
title = "Review implementation"

[[steps]]
id = "test"
needs = ["review"]
title = "Test {{feature}}"

[[steps]]
id = "submit"
needs = ["test"]
title = "Submit for merge"

[vars.feature]
required = true
```

**Cooking:** `bd cook <formula>` transforms a formula into a protomolecule.
`bd mol pour <proto>` instantiates it. `bd mol wisp <proto>` creates an
ephemeral instance.

### 6. Wisps (Ephemeral Beads)

The "vapor phase" of work. Wisps are beads that:

- Exist in the database and get hash IDs
- Act like regular beads
- Are NOT written to JSONL
- Are NOT persisted to Git
- Are "burned" (destroyed) after their run
- Optionally squashed into a single-line summary

**Why wisps matter:** Patrol agents create a new wisp molecule for every
patrol cycle. Without wisps, the git history would be overwhelmed with
orchestration noise. Wisps provide transactional execution without
polluting the permanent record.

**Two modes:**
- **Root-only** (default, `pour = false`): Only the root wisp exists. Formula
  steps are shown inline when the agent runs `gt prime`. Prevents wisp
  accumulation (~6,000+ rows/day → ~400/day).
- **Poured** (`pour = true`): Steps materialized as sub-wisps with checkpoint
  recovery. Use for expensive, low-frequency workflows like releases.

**Heuristic:** "If you would curse losing progress after a crash, set
`pour = true`."

## How Agents See Molecules

Agents don't interact with molecules directly via `bd mol current`. Instead:

1. `gt prime` renders the formula checklist inline
2. Agent works through steps in order
3. Agent runs `gt done` (polecats) or `gt patrol report` (patrol agents)

Example rendering:

```
**Formula Checklist** (10 steps from mol-polecat-work):

### Step 1: Load context and verify assignment
Initialize your session and understand your assignment...

### Step 2: Set up working branch
Ensure you're on a clean feature branch...
```

## The "Guzzoline" Metaphor

The big sea of work molecules — all the pending work in the system — is
informally called "guzzoline." Gas Town both produces and consumes guzzoline.
The hardest problem is keeping it fed: agents churn through implementation
plans so quickly that you need a LOT of design and planning to keep the
engine supplied.

## Molecule Composition

Formulas can be composed:

- **Rule of Five** — wraps any workflow so each step gets reviewed 4 times
  (implementation counts as review #1). Generates LARGE workflows.
- **Shiny variants** — `shiny` (base), `shiny-secure` (+ security audit),
  `shiny-enterprise` (maximum ceremony)

This composability makes MEOW Turing-complete. Each step is executed by a
superintelligent AI, making the system remarkably robust despite its
nondeterministic nature.
