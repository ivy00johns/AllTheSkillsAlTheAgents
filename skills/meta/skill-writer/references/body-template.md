# SKILL.md Body Template

Anthropic's recommended body structure for a SKILL.md, with commentary on when to deviate.

## When to Use This Template

This is the default body structure for **any new skill**. Use it unchanged unless you have a specific reason to deviate (see "When to Deviate" below). The structure prioritizes the same things Claude does when loading a skill: critical instructions first, then patterns to imitate, then known failure modes.

## The Template

```markdown
# Skill Title

One-paragraph statement of what the skill does and the typical situation it's invoked in.

## Instructions

High-signal guidance the model needs every time. Lead with the must-do bullets, then the workflow.

### Step 1: First Major Step

Describe the first action concretely. Use imperative voice ("Read the file", "Run the command", "Write the result"). Include the exact tool or command name where it helps.

### Step 2: Second Major Step

Describe the next action. Each step should be self-contained enough that the model can execute it without re-reading earlier steps.

### Step 3: Third Major Step

Continue until the happy-path workflow is covered. Keep steps under 5 — split into a reference file if you need more.

## Examples

Examples teach by pattern matching. Show at least one realistic invocation end-to-end.

### Example 1: [Short scenario name]

**User says:** "[Trigger phrase the user would actually type]"

**Actions:**

1. [First concrete action the skill takes]
2. [Second action]
3. [Third action]

**Result:** [What the user sees / what gets produced]

### Example 2: [A different scenario]

**User says:** "[A different trigger phrase]"

**Actions:**

1. [Actions for this variant]

**Result:** [Output for this variant]

## Troubleshooting

Document known failure modes so the model self-corrects instead of pinging the user.

### Error: [Common error message or symptom]

**Cause:** [Why this happens]

**Solution:** [Concrete fix the model can apply]

### Error: [Another common failure]

**Cause:** [Why]

**Solution:** [Fix]
```

## Why This Structure

- **Critical instructions surface to the top.** The model reads top-down; the `## Instructions` H2 sits right under the title where it has the most weight.
- **Examples teach pattern matching.** Models reliably imitate concrete `User says → Actions → Result` triples. A skill with three good examples often outperforms a skill with three paragraphs of prose.
- **Troubleshooting prevents support tickets.** Naming a symptom + cause + fix lets the model recover from a known failure without escalating to the user.

## When to Deviate

| Skill type | Deviation | Why |
|---|---|---|
| Agent role skills (`skills/roles/*`) | Use Role / Inputs / Process / Coordination / Validation instead | Roles are spawned by the orchestrator and need explicit I/O and coordination contracts, not user examples |
| Meta skills (`skills/meta/*`) | Examples section is often omitted | The "user" is usually another skill author, not an end user; the meta-doc itself is the example |
| Orchestrator (`skills/orchestrator/`) | Replace Steps with named Phases (Phase 1 → Phase 14) and link each phase to a reference file | A 14-phase workflow doesn't fit in 5 numbered steps |
| Workflow skills with branching logic | Add a `## Decision Tree` H2 above `## Instructions` | When the first action depends on context, surface the routing decision before the steps |

If you deviate, keep the spirit intact: critical instructions near the top, concrete examples where they help, named failure modes at the bottom.
