# 05 -- Formula Engine Reference

This document is a comprehensive reference for the Beads formula engine: the
system that transforms declarative workflow templates into issue hierarchies.
The engine implements a chemistry metaphor for lifecycle management, a
multi-stage transformation pipeline, and a rich type system for expressing
complex workflows.

Source: `internal/formula/` (types, parsing, transformations) and `cmd/bd/cook.go`
(cooking pipeline, subgraph creation).

---

## 1. The Chemistry Metaphor

Beads organizes workflow lifecycle around three material phases. Each phase
represents a different level of persistence and synchronization.

| Phase  | Name  | Synced via Git | ID Prefix    | Materialization                          |
|--------|-------|----------------|--------------|------------------------------------------|
| Solid  | Proto | Yes            | `mol-`       | Template, `IsTemplate=true`              |
| Liquid | Mol   | Yes            | project prefix | Full epic + all child step issues       |
| Vapor  | Wisp  | No             | wisp prefix  | Root epic only (unless `pour=true`)      |

### Phase Transitions

```
Formula file (.formula.toml / .formula.json)
    |
    v
[bd cook --persist] --> Proto (solid, stored in DB, IsTemplate=true)
    |
    v
[bd mol pour]       --> Mol (liquid, persistent, full child materialization)
    |
    v
[bd mol wisp]       --> Wisp (vapor, ephemeral, local-only)
    |
    |--[bd mol squash]--> Promotes wisp to persistent (liquid)
    |--[bd mol burn]---> Discards without record
```

Key observations:

- **Proto** is a reusable template. Created by `bd cook --persist`. Each step
  becomes a child issue with `IsTemplate=true`. The proto can be poured
  multiple times.

- **Mol** is a fully materialized molecule. Created by `bd mol pour`. Every
  step in the formula becomes a real issue with its own ID, dependency
  tracking, and lifecycle.

- **Wisp** is an ephemeral molecule. Created by `bd mol wisp`. By default
  only the root epic is stored in the wisps table (not synced via git).
  If the formula sets `pour=true`, child steps are also materialized for
  checkpoint recovery.

- The formula's `Phase` field recommends whether to use pour ("liquid") or
  wisp ("vapor"). If a formula has `phase = "vapor"`, `bd pour` will warn
  and suggest using `bd mol wisp` instead. Patrol and release workflows
  should typically use vapor since they are operational.

---

## 2. Formula Types

Defined in `internal/formula/types.go` as the `FormulaType` enum.

### TypeWorkflow (`"workflow"`)

Standard step sequence that becomes an issue hierarchy. This is the default
type when none is specified. Contains a `steps` array where each step becomes
a child issue under the root epic.

### TypeExpansion (`"expansion"`)

Reusable macro with target placeholders. Instead of `steps`, an expansion
formula defines a `template` array. Template steps use these placeholders:

| Placeholder            | Substituted With                     |
|------------------------|--------------------------------------|
| `{target}`             | Target step ID                       |
| `{target.id}`          | Target step ID (explicit)            |
| `{target.title}`       | Target step title                    |
| `{target.description}` | Target step description              |

Expansion formulas are applied via:
- `step.expand` (inline on a step)
- `compose.expand` (targeted by step ID)
- `compose.map` (targeted by glob pattern)
- Standalone instantiation via `MaterializeExpansion` (creates a synthetic
  target from the formula name/description)

### TypeAspect (`"aspect"`)

Cross-cutting concern with advice rules (before/after/around). Applied to
other formulas via `compose.aspects`. An aspect formula defines `advice`
rules and optionally `pointcuts` for matching target steps.

---

## 3. Formula Struct Fields

The root `Formula` struct (`internal/formula/types.go`):

| Field       | Type                   | JSON Key        | Description                                                           |
|-------------|------------------------|-----------------|-----------------------------------------------------------------------|
| Formula     | `string`               | `"formula"`     | Unique identifier/name. Convention: `mol-<name>`, `exp-<name>`        |
| Description | `string`               | `"description"` | Human-readable explanation                                            |
| Version     | `int`                  | `"version"`     | Schema version, must be >= 1                                          |
| Type        | `FormulaType`          | `"type"`        | `workflow`, `expansion`, or `aspect`                                  |
| Extends     | `[]string`             | `"extends"`     | Parent formula names for inheritance                                  |
| Vars        | `map[string]*VarDef`   | `"vars"`        | Template variable definitions                                         |
| Steps       | `[]*Step`              | `"steps"`       | Work items (workflow type)                                            |
| Template    | `[]*Step`              | `"template"`    | Expansion template steps (expansion type only)                        |
| Compose     | `*ComposeRules`        | `"compose"`     | Composition/bonding rules                                             |
| Advice      | `[]*AdviceRule`        | `"advice"`      | Step transformations (before/after/around)                            |
| Pointcuts   | `[]*Pointcut`          | `"pointcuts"`   | Target patterns for aspect formulas                                   |
| Phase       | `string`               | `"phase"`       | Recommended instantiation: `"liquid"` or `"vapor"`                    |
| Pour        | `bool`                 | `"pour"`        | If true, child steps materialized even in wisp mode                   |
| Source      | `string`               | `"source"`      | File path (set by parser, not serialized to user-facing JSON)         |

Validation rules enforced by `Formula.Validate()`:
- `Formula` (name) is required
- `Version` must be >= 1
- `Type` must be a valid `FormulaType` if set
- Variables cannot have both `required: true` and a `default`
- Step IDs must be unique (including across children)
- Step `depends_on` and `needs` must reference known step IDs
- Bond point `after_step`/`before_step` are mutually exclusive
- `on_complete.for_each` must start with `"output."`

---

## 4. VarDef (Variable Definitions)

Defined in `internal/formula/types.go`:

| Field       | Type       | Description                                                          |
|-------------|------------|----------------------------------------------------------------------|
| Description | `string`   | What this variable is for                                            |
| Default     | `*string`  | Value if not provided. `nil` = no default. `&""` = explicit empty    |
| Required    | `bool`     | Must be provided (mutually exclusive with Default)                   |
| Enum        | `[]string` | Whitelist of allowed values                                          |
| Pattern     | `string`   | Regex the value must match                                           |
| Type        | `string`   | Expected type: `"string"` (default), `"int"`, `"bool"`              |

### Variable Substitution Syntax

In step titles, descriptions, and other text fields: `{{varname}}`

The regex pattern is: `\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}`

### TOML Shorthand

`VarDef` implements `UnmarshalTOML` for ergonomic TOML definitions:

```toml
[vars]
wisp_type = "patrol"           # Simple string -> Default = "patrol"

[vars.component]               # Full table definition
description = "Component name"
required = true
```

### Variable Processing

- `ExtractVariables(formula)` -- finds all `{{variable}}` references
- `ValidateVars(formula, values)` -- checks required, enum, pattern constraints
- `ApplyDefaults(formula, values)` -- fills in defaults for missing values
- `Substitute(s, vars)` -- replaces `{{variable}}` placeholders in strings

---

## 5. Step

The `Step` struct defines a single work item within a formula:

| Field          | Type                | JSON Key         | Description                                                    |
|----------------|---------------------|------------------|----------------------------------------------------------------|
| ID             | `string`            | `"id"`           | Unique within formula, used for dependency references           |
| Title          | `string`            | `"title"`        | Issue title, supports `{{var}}` substitution                    |
| Description    | `string`            | `"description"`  | Issue description, supports substitution                        |
| Notes          | `string`            | `"notes"`        | Additional notes, supports substitution                         |
| Type           | `string`            | `"type"`         | Issue type: task, bug, feature, epic, chore                     |
| Priority       | `*int`              | `"priority"`     | 0-4 (nil = inherit default of 2)                               |
| Labels         | `[]string`          | `"labels"`       | Applied to created issue                                        |
| DependsOn      | `[]string`          | `"depends_on"`   | Step IDs this step blocks on                                    |
| Needs          | `[]string`          | `"needs"`        | Alias for DependsOn (merged during cooking)                     |
| WaitsFor       | `string`            | `"waits_for"`    | Fanout gate: `"all-children"`, `"any-children"`, `"children-of(step-id)"` |
| Assignee       | `string`            | `"assignee"`     | Default assignee, supports substitution                         |
| Expand         | `string`            | `"expand"`       | Reference to expansion formula for inline expansion             |
| ExpandVars     | `map[string]string` | `"expand_vars"`  | Variable overrides for inline expansion                         |
| Condition      | `string`            | `"condition"`    | Compile-time condition for step inclusion                       |
| Children       | `[]*Step`           | `"children"`     | Nested steps (creates epic hierarchy)                           |
| Gate           | `*Gate`             | `"gate"`         | Async wait condition (creates separate gate issue)              |
| Loop           | `*LoopSpec`         | `"loop"`         | Iteration specification                                         |
| OnComplete     | `*OnCompleteSpec`   | `"on_complete"`  | Runtime expansion over step output                              |
| SourceFormula  | `string`            | (internal)       | Formula name where step was defined (not serialized)            |
| SourceLocation | `string`            | (internal)       | Path within source: `"steps[0]"`, `"advice[0].after"`          |

---

## 6. Gate (Inline)

Defined inline on a step. When a step has a `Gate`, `bd cook` creates a
separate gate issue as a sibling. The gate blocks the step via a
`DepBlocks` dependency.

| Field   | Type     | Description                                                           |
|---------|----------|-----------------------------------------------------------------------|
| Type    | `string` | Condition type: `gh:run`, `gh:pr`, `timer`, `human`, `mail`          |
| ID      | `string` | Condition identifier (workflow name, PR number, etc.)                 |
| Timeout | `string` | Duration before escalation (e.g., `"1h"`, `"24h"`)                   |

Gate issue ID format: `{parentID}.gate-{step.ID}`

Gate issue fields populated:
- `IssueType = "gate"`
- `AwaitType = gate.Type`
- `AwaitID = gate.ID`
- `Timeout` parsed from gate.Timeout
- `IsTemplate = true` (during cooking)

Dependencies created:
1. Gate is a child of the parent (`DepParentChild`)
2. Step depends on gate (`DepBlocks`) -- gate blocks the step

---

## 7. LoopSpec

Exactly one of `Count`, `Until`, or `Range` must be specified.

| Field | Type       | Description                                                              |
|-------|------------|--------------------------------------------------------------------------|
| Count | `int`      | Fixed iteration count (body expanded N times)                            |
| Until | `string`   | Condition ending the loop (requires `Max`). Parsed by `ParseCondition`   |
| Max   | `int`      | Safety limit for conditional loops (required when `Until` is set)        |
| Range | `string`   | Computed range: `"start..end"` with arithmetic expressions               |
| Var   | `string`   | Variable name exposed to body steps (set to current iteration value)     |
| Body  | `[]*Step`  | Steps to repeat                                                          |

### Range Parser (`internal/formula/range.go`)

The range expression parser supports:
- Simple integers: `"1..10"`
- Expressions: `"1..2^{disks}"` (evaluated at cook time)
- Variables: `"{start}..{count}"` (substituted from Vars)
- Operators: `+`, `-`, `*`, `/`, `^` (power, right-associative)
- Parentheses for grouping
- Unary minus

The parser uses recursive descent with precedence levels:
`+ -` (lowest) < `* /` < `^` (highest binary, right-associative)

### Loop Expansion Behavior

- **Fixed-count**: Body expanded N times with iteration-indexed IDs
  (`{loopID}.iter{N}.{bodyStepID}`). Iterations chained sequentially.
- **Range**: Body expanded for each value. Loop variable (`Var`) set to
  current value. IDs indexed by iteration number (not range value).
- **Conditional (Until)**: Body expanded once. First step gets a
  `loop:{"until":"...","max":N}` label for runtime re-execution.

Internal dependency rewriting: References to step IDs within the loop body
are prefixed with the iteration context. External dependencies are preserved
as-is. After recursive expansion of nested loops, iterations are chained
using `chainExpandedIterations`, which finds iteration boundaries by ID
prefix matching.

---

## 8. OnCompleteSpec

Runtime expansion over step output (the for-each construct):

| Field      | Type                | Description                                              |
|------------|---------------------|----------------------------------------------------------|
| ForEach    | `string`            | Path to iterable: `"output.<field>"` or nested           |
| Bond       | `string`            | Formula to instantiate per item                           |
| Vars       | `map[string]string` | Bindings: `{item}`, `{item.field}`, `{index}`            |
| Parallel   | `bool`              | Run all bonded molecules concurrently                     |
| Sequential | `bool`              | Run one at a time (mutually exclusive with Parallel)      |

Validation: `ForEach` and `Bond` must be both present or both absent.
`ForEach` must start with `"output."`. `Parallel` and `Sequential` are
mutually exclusive.

---

## 9. ComposeRules

The `ComposeRules` struct defines how formulas are bonded together:

| Field      | Type             | Description                                                  |
|------------|------------------|--------------------------------------------------------------|
| BondPoints | `[]*BondPoint`   | Named attachment sites (AfterStep/BeforeStep, Parallel)      |
| Hooks      | `[]*Hook`        | Auto-attach on trigger (label, type, priority range)         |
| Expand     | `[]*ExpandRule`  | Replace named step with expansion template                   |
| Map        | `[]*MapRule`     | Replace all matching steps (glob) with expansion template    |
| Branch     | `[]*BranchRule`  | Fork-join parallel execution (From -> [Steps] -> Join)       |
| Gate       | `[]*GateRule`    | Condition labels for runtime evaluation (Before + Condition) |
| Aspects    | `[]string`       | Aspect formula names to apply                                |

### BondPoint

- `ID` (required): unique identifier
- `AfterStep` / `BeforeStep` (mutually exclusive): anchor step ID
- `Parallel`: if true, attached steps run in parallel with anchor

### Hook

- `Trigger`: activation condition (`"label:security"`, `"type:bug"`, `"priority:0-1"`)
- `Attach`: formula name to attach
- `At`: bond point ID (default: end)
- `Vars`: variable overrides

### BranchRule (Fork-Join)

- `From`: step ID preceding parallel paths
- `Steps`: step IDs running in parallel (all depend on From)
- `Join`: step ID following all paths (depends on all Steps)

### GateRule

- `Before`: step ID that the gate applies to
- `Condition`: expression evaluated at runtime (validated by `ParseCondition`)

---

## 10. AdviceRule (AOP)

Defined in `internal/formula/advice.go`. Advice rules insert steps before,
after, or around matching target steps.

| Field  | Type            | Description                                     |
|--------|-----------------|-------------------------------------------------|
| Target | `string`        | Glob pattern matching step IDs                  |
| Before | `*AdviceStep`   | Step inserted before target                     |
| After  | `*AdviceStep`   | Step inserted after target                      |
| Around | `*AroundAdvice` | Before[] and After[] steps wrapping target      |

### AdviceStep

- `ID`: step identifier, supports `{step.id}` substitution
- `Title`: supports `{step.id}` and `{step.title}` substitution
- `Description`: step description
- `Type`: issue type
- `Args`: additional context (map)
- `Output`: expected outputs (map)

### AroundAdvice

- `Before`: list of `*AdviceStep` inserted before target
- `After`: list of `*AdviceStep` inserted after target

### Glob Matching (`MatchGlob`)

Uses `filepath.Match` as baseline, with additional pattern support:

| Pattern        | Matches                                    | Example              |
|----------------|--------------------------------------------|----------------------|
| `"exact"`      | Exact step ID                              | `"design"`           |
| `"*.suffix"`   | Any step ending with `.suffix`             | `"*.implement"`      |
| `"prefix.*"`   | Any step starting with `prefix.`           | `"shiny.*"`          |
| `"*"`          | All steps                                  | `"*"`                |

### Self-Matching Prevention

`ApplyAdvice` collects original step IDs into a guard set before applying
rules. Steps inserted by advice are NOT matched by subsequent rules in the
same pass, preventing infinite recursion. The `applyAdviceWithGuard`
function skips any step whose ID is not in the `originalIDs` set.

### Dependency Chaining

When advice inserts steps:
1. Before steps are chained together sequentially
2. The original step gains a `Needs` dependency on the last before step
3. The first after step depends on the original step
4. Subsequent after steps chain to the previous after step

---

## 11. Transformation Pipeline

The pipeline is applied in a fixed order. Source:
`loadAndResolveFormula()` in `cmd/bd/cook.go` and
`resolveAndCookFormulaWithVars()` for ephemeral cooking.

### Stage 1: Parse and Resolve Inheritance

`parser.Resolve(formula)` -- `internal/formula/parser.go`

1. Check for circular extends (cycle detection via `resolvingSet`)
2. For each parent in `Extends`, load and resolve recursively
3. Merge vars: parent first, child overrides
4. Merge steps: same ID replaces in-place (preserving position), new IDs appended
5. Merge compose rules: bond points override by ID, hooks/expand/map append
6. Validate the merged result

### Stage 2: ApplyControlFlow

`formula.ApplyControlFlow(steps, compose)` -- `internal/formula/controlflow.go`

Applied in sub-order:
1. **ApplyLoops**: Expand loop bodies (fixed-count, range, or conditional)
2. **applyBranchesWithMap**: Wire fork-join dependency patterns
3. **applyGatesWithMap**: Add gate condition labels

All three share a single `buildStepMap` for the post-loop-expansion steps.

### Stage 3: ApplyAdvice (inline)

`formula.ApplyAdvice(steps, advice)` -- `internal/formula/advice.go`

Applied only if `len(resolved.Advice) > 0`. Inserts before/after/around
steps matching target globs. Self-matching prevention via guard set.

### Stage 4: ApplyInlineExpansions

`formula.ApplyInlineExpansions(steps, parser)` -- `internal/formula/expand.go`

Processes steps with `step.Expand` set. Each such step is replaced by the
referenced expansion formula's template. Recursive with depth limit of
`DefaultMaxExpansionDepth = 5`. Target dependencies are propagated to root
steps of the expansion.

### Stage 5: ApplyExpansions (compose.expand/map)

`formula.ApplyExpansions(steps, compose, parser)` -- `internal/formula/expand.go`

Processes `compose.Expand` rules first (specific targets), then
`compose.Map` rules (glob matching). Same expansion mechanics as inline,
with dependency propagation and post-expansion dependency rewiring
(`UpdateDependenciesForExpansion`).

### Stage 6: Apply compose.aspects

For each aspect name in `compose.Aspects`:
1. Load the aspect formula by name
2. Verify it is `TypeAspect`
3. Apply its advice rules via `ApplyAdvice`

### Stage 7: FilterStepsByCondition

`formula.FilterStepsByCondition(steps, vars)` -- `internal/formula/stepcondition.go`

Only applied if condition vars are provided (wisp/pour path). Steps whose
`Condition` evaluates to false are removed along with their children.

### Stage 8: MaterializeExpansion (expansion-type only)

`formula.MaterializeExpansion(f, targetID, vars)` -- `internal/formula/expand.go`

For standalone expansion formulas (no Compose wrapper), creates a synthetic
target step from the formula's own name/description and expands `Template`
into `Steps`. No-op if the formula already has Steps or is not an expansion
type.

---

## 12. Parsing (`internal/formula/parser.go`)

### Parser

The `Parser` struct manages formula loading and resolution. It is NOT
thread-safe (cache and resolving maps have no internal synchronization).

### Search Paths (in priority order)

1. `.beads/formulas/` -- project-level formulas (relative to cwd)
2. `~/.beads/formulas/` -- user-level formulas
3. `$GT_ROOT/.beads/formulas/` -- town-level formulas (orchestrator)

### File Resolution

For a formula name `foo`, the parser searches each path for:
1. `foo.formula.toml` (TOML preferred)
2. `foo.formula.json` (JSON fallback)

### Inheritance Resolution

`Resolve(formula)`:
- Tracks formulas currently being resolved in `resolvingSet` (cycle detection)
- Maintains `resolvingChain` for clear error messages on cycles
- For each parent: load, resolve recursively, merge vars/steps/compose
- Child definitions override parent definitions with same ID

### Caching

Formulas are cached by both absolute path and name. The cache is populated
on first load and reused for subsequent references.

---

## 13. Condition Evaluation

Two distinct condition systems operate at different times.

### Compile-Time Conditions (`internal/formula/stepcondition.go`)

Used by `Step.Condition` field. Evaluated at cook/pour time to include or
exclude steps based on formula variables.

| Format            | Meaning                                          |
|-------------------|--------------------------------------------------|
| `"{{var}}"`       | Include if var is truthy                         |
| `"!{{var}}"`      | Include if var is NOT truthy (negated)           |
| `"{{var}} == val"` | Include if var equals val                       |
| `"{{var}} != val"` | Include if var does not equal val               |

Truthy definition: non-empty AND not `"false"`, `"0"`, `"no"`, `"off"`
(case-insensitive).

### Runtime Conditions (`internal/formula/condition.go`)

Used by gate conditions, loop `until` clauses, and compose gate rules.
Evaluated against live step state.

**Condition Types:**

| Type        | Pattern                                           | Example                                      |
|-------------|---------------------------------------------------|----------------------------------------------|
| Field       | `step.field op value`                             | `review.status == 'complete'`                |
| Aggregate   | `children(step).func(condition)`                  | `children(x).all(status == 'complete')`      |
| External    | `file.exists('path')` or `env.VAR op value`      | `file.exists('go.mod')`, `env.CI == 'true'`  |

**Comparison Operators:**

`==`, `!=`, `>`, `>=`, `<`, `<=`

Comparison strategy: numeric first (both sides parsed as float64), lexicographic
string fallback.

**Aggregate Functions:**

| Function | Behavior                                                                    |
|----------|-----------------------------------------------------------------------------|
| `all`    | True if every item matches. **Empty set returns false** (prevents premature gate passing) |
| `any`    | True if at least one item matches                                           |
| `count`  | Counts matching items, compared with operator against an integer value      |

**Aggregate Scope:**

- `children(step)` -- direct children
- `descendants(step)` -- all recursive descendants
- `steps` -- all steps in context

---

## 14. Cooking (`cmd/bd/cook.go`)

The cook command transforms a resolved formula into a `TemplateSubgraph`.

### TemplateSubgraph

```go
type TemplateSubgraph struct {
    Root         *types.Issue
    Issues       []*types.Issue
    Dependencies []*types.Dependency
    IssueMap     map[string]*types.Issue
    VarDefs      map[string]formula.VarDef
    Phase        string
    Pour         bool
}
```

### Root Issue Creation

- ID: `protoID` (formula name, optionally prefixed)
- Title: `"{{title}}"` if `title` var is defined, else formula name
- Description: `"{{desc}}"` if `desc` var is defined, else formula description
- Type: `TypeEpic`
- `IsTemplate = true`

### Step Processing (`processStepToIssue`)

For each step:
- Issue ID: `{parentID}.{step.ID}`
- Type: from step.Type (default task); overridden to epic if step has children
- Priority: from step.Priority (default 2)
- Labels: from step.Labels + gate label if `waits_for` is set
- `IsTemplate = true`

### Gate Issue Creation (`createGateIssue`)

If a step has a `Gate` field:
- Gate issue created as sibling (same parent)
- ID: `{parentID}.gate-{step.ID}`
- Linked via `DepBlocks`: step depends on gate
- Linked via `DepParentChild`: gate is child of parent

### Dependency Collection (`collectDependencies`)

Three dependency sources per step:
1. `depends_on` -> `DepBlocks` dependencies
2. `needs` -> `DepBlocks` dependencies (same as depends_on)
3. `waits_for` -> `DepWaitsFor` dependency with `WaitsForMeta{Gate: type}`
   - Spawner inferred from first `needs` entry if not specified

### Two Cooking Modes

| Mode         | Flag                       | Behavior                                        |
|--------------|----------------------------|-------------------------------------------------|
| Compile-time | Default (no `--var`)       | `{{variables}}` kept as placeholders             |
| Runtime      | `--mode=runtime` or `--var` | Variables substituted, all must have values      |

---

## 15. Compaction (`internal/compact/`)

### Architecture

```
Compactor
  +-- store (compactableStore interface)
  +-- summarizer (haikuClient)
  +-- config (Config)
```

### Config

| Field        | Type     | Default | Description                            |
|--------------|----------|---------|----------------------------------------|
| APIKey       | `string` | --      | Anthropic API key                      |
| Concurrency  | `int`    | 5       | Max parallel compaction goroutines     |
| DryRun       | `bool`   | false   | Preview without applying               |
| AuditEnabled | `bool`   | false   | Log LLM calls to audit system          |
| Actor        | `string` | --      | Actor name for audit entries           |

### Tier System

| Tier | Eligibility                                | Reduction | MaxTokens |
|------|--------------------------------------------|-----------|-----------|
| 1    | 30+ days closed                            | ~70%      | 1024      |
| 2    | 90+ days closed AND already Tier 1         | (future)  | (future)  |

### Summarization Prompt

The exact Tier 1 prompt template (`internal/compact/haiku.go`):

```
You are summarizing a closed software issue for long-term storage.
Your goal is to COMPRESS the content - the output MUST be significantly
shorter than the input while preserving key technical decisions and outcomes.

**Title:** {{.Title}}
**Description:** {{.Description}}
[Design, Acceptance Criteria, Notes if present]

IMPORTANT: Your summary must be shorter than the original.
Be concise and eliminate redundancy.

Provide a summary in this exact format:

**Summary:** [2-3 concise sentences covering what was done and why]
**Key Decisions:** [Brief bullet points of only the most important technical choices]
**Resolution:** [One sentence on final outcome and lasting impact]
```

### Retry Strategy

- Max retries: 3
- Backoff: exponential from 1 second (`1s * 2^(attempt-1)`)
- Retryable errors: HTTP 429 (rate limit), HTTP 5xx (server error), network timeouts
- Non-retryable: HTTP 4xx (except 429), context cancellation/deadline

### Batch Processing

`CompactTier1Batch` uses a semaphore-bounded goroutine pool:
- Channel-based semaphore with capacity = `config.Concurrency` (default 5)
- Each goroutine acquires semaphore before calling `CompactTier1`
- Results collected in pre-allocated slice indexed by position

### Compaction Safety

Before applying a summary, the compactor checks:
1. Eligibility (store-level check with tier and reasons)
2. Size comparison: if `len(summary) >= originalSize`, compaction is
   skipped and a warning comment is added

### After Successful Compaction

1. Issue fields updated: `description = summary`, `design = ""`,
   `notes = ""`, `acceptance_criteria = ""`
2. Compaction metadata recorded with git commit hash
3. Comment added: `"Tier 1 compaction: X -> Y bytes (saved Z)"`

### CLI Modes

| Mode       | Flag        | Behavior                                    |
|------------|-------------|---------------------------------------------|
| Analyze    | `--analyze` | JSON export of compaction candidates         |
| Apply      | `--apply`   | Accept summary from file/stdin               |
| Auto       | `--auto`    | AI-powered summarization                     |
| Dolt GC    | `--dolt`    | Run `dolt gc` for storage reclamation        |

### Telemetry

The haiku client records OpenTelemetry metrics:
- `bd.ai.input_tokens` (counter)
- `bd.ai.output_tokens` (counter)
- `bd.ai.request.duration` (histogram, milliseconds)

---

## 16. Key Source Files

| File                                   | Purpose                                          |
|----------------------------------------|--------------------------------------------------|
| `internal/formula/types.go`            | All type definitions (Formula, Step, Gate, etc.) |
| `internal/formula/parser.go`           | Parsing, inheritance, variable substitution       |
| `internal/formula/advice.go`           | Advice (AOP) operators                            |
| `internal/formula/controlflow.go`      | Loop, branch, gate control flow                   |
| `internal/formula/expand.go`           | Expansion operators (expand, map, inline)         |
| `internal/formula/condition.go`        | Runtime condition evaluation                      |
| `internal/formula/stepcondition.go`    | Compile-time step condition filtering             |
| `internal/formula/range.go`            | Range expression parser (arithmetic)              |
| `cmd/bd/cook.go`                       | Cook command, subgraph creation, pipeline         |
| `internal/compact/compactor.go`        | Compaction orchestration and batching             |
| `internal/compact/haiku.go`            | Anthropic API client, prompt template, retry      |
| `internal/compact/git.go`              | Git commit hash for compaction metadata           |
