# Skill Design Patterns

Five emergent patterns Anthropic cataloged from skills observed in the wild (Chapter 5 of "The Complete Guide to Building Skills for Claude"). Most well-shaped skills fall into one of these; some compose two. Use this catalog as a sanity check when designing a new skill — if your skill doesn't resemble any of these, ask whether the shape is right.

Each pattern below documents: **Use when**, an example structure, **Key techniques**, and a pointer to an in-repo example.

## Pattern 1: Sequential Workflow Orchestration

**Use when:** the task is a multi-step process that must happen in a specific order, and skipping or reordering steps produces wrong output.

**Example structure:**

```markdown
## Workflow

### Step 1: Validate inputs
### Step 2: Transform
### Step 3: Persist
### Step 4: Notify
```

**Key techniques:**

- Number the steps explicitly — models reorder unnumbered bullets
- Make each step's exit condition observable ("file exists at X", "command exits 0")
- State the failure mode for each step inline, not at the bottom
- Keep the happy path linear; push branching to a `## Branching` subsection or a reference file

**In-repo example:** `skills/workflows/sync-skills` (scan → classify → confirm → symlink → verify) and `skills/git/git-pr` (status → diff → branch → push → create PR).

## Pattern 2: Multi-MCP / Multi-Service Coordination

**Use when:** the workflow spans several external services (or, in this repo, several role agents), each owning a phase, with handoffs between them.

**Example structure:**

```markdown
## Phases

### Phase 1: Design Export (Figma MCP)
### Phase 2: Asset Storage (S3 MCP)
### Phase 3: Task Creation (Linear MCP)
### Phase 4: Notification (Slack MCP)
```

**Key techniques:**

- Name the service or agent that owns each phase
- Define the artifact handed off between phases (file path, JSON shape, URL)
- Document the rollback or skip-ahead behavior when a phase's service is unavailable
- Don't bury the cross-service dependency graph — surface it near the top

**In-repo example:** `skills/orchestrator` applies this pattern to agent roles instead of MCPs — its 14-phase playbook hands artifacts (contracts, qa-report.json, handoff docs) between backend, frontend, qe, etc.

## Pattern 3: Iterative Refinement

**Use when:** output quality measurably improves with iteration, and a single pass produces something noticeably worse than two or three passes.

**Example structure:**

```markdown
## Workflow

### Initial Draft
### Quality Check
### Refinement Loop (repeat until criteria met)
### Finalization
```

**Key techniques:**

- Define the quality bar concretely (a checklist, a score threshold, or "no remaining `TODO` markers")
- Cap the loop ("repeat up to 3 times, then escalate")
- Make the refinement criteria observable — "fixes flagged issues" is too vague; "addresses each item in the qa-report.json blockers array" is concrete
- Output a diff or change log each iteration so the user can audit

**In-repo example:** `skills/meta/skill-update` (review → identify gaps → patch → re-review) and `skills/workflows/diagnose-loop` (hypothesis → test → refine → repeat).

## Pattern 4: Context-Aware Tool Selection

**Use when:** the same outcome can be achieved by different tools, and the right tool depends on runtime context (host, plan, what's installed, what's available).

**Example structure:**

```markdown
## Decision Tree

1. Detect available runtime
2. Select tool path:
   - If [condition A] → use [Tool A]
   - Elif [condition B] → use [Tool B]
   - Else → fall back to [Tool C]
3. Execute the selected path
4. Tell the user which path was taken and why
```

**Key techniques:**

- Make the detection step explicit and cheap (one command, not a battery)
- Order branches from most-preferred to fallback
- Always tell the user which branch ran — silent fallbacks make debugging miserable
- Document each branch's tradeoffs (speed vs. fidelity vs. dependencies)

**In-repo example:** `skills/orchestrator` runtime detection — Agent Teams (best) → subagents (good) → sequential (works everywhere). The skill picks based on the host's capabilities and tells the user which mode it chose.

## Pattern 5: Domain-Specific Intelligence

**Use when:** the skill adds specialized knowledge beyond tool access — compliance rules, security checklists, framework idioms, regulatory constraints — that a generic agent wouldn't know to apply.

**Example structure:**

```markdown
## Workflow

### Step 1: Compliance / domain check
### Step 2: Conditional processing based on domain rules
### Step 3: Audit trail / evidence collection
### Step 4: Reporting
```

**Key techniques:**

- Bundle the domain knowledge in `references/` (rule lists, checklists, templates by stack)
- Make the check step refuse to skip — "do not proceed until each item in the checklist is verified"
- Produce an audit artifact (JSON, markdown report) so the work is reviewable, not just executed
- Cite the source of each rule so the model can explain its reasoning

**In-repo example:** `skills/contracts/contract-author` (selects an OpenAPI / AsyncAPI / Pydantic / TypeScript / JSON Schema template based on the project stack and applies stack-specific conventions) and `skills/roles/security-agent` (applies OWASP-style checklists and produces an audit trail).

## Composing Patterns

Real skills often combine two patterns. A few common combos:

| Combo | Where it shows up |
|---|---|
| Sequential + Domain-specific | Most agent roles — a fixed workflow that also enforces domain rules at each step |
| Iterative + Domain-specific | Skill audits, security reviews, code review |
| Context-aware + Sequential | Orchestrator (pick a runtime, then run the 14-phase sequence in that runtime) |
| Multi-service + Iterative | UX review (Playwright → screenshot → identify issues → fix → re-run) |

If you find your skill needs more than two patterns, it's probably two skills. Split it.
