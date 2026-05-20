---
name: grill-me
version: 1.0.0
description: "Get relentlessly interviewed about a plan, design, or change until every branch of the decision tree is resolved. The agent walks the design tree depth-first, asks ONE question at a time, attaches its recommended answer to each question, and prefers exploring the codebase over asking when an answer can be found in code. Use this skill before any non-trivial change, when scope feels fuzzy, or when stress-testing a plan before committing. Trigger on: 'grill me', 'interview me', 'challenge my plan', 'ask me questions', 'I'm not sure what I want', 'help me think this through', 'is this the right approach', 'walk me through it', 'stress test this plan'."
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: []
allowed-tools: ["Read", "Grep", "Glob"]
composes_with: ["architecture-rescue", "maintain-context", "plan-builder"]
spawned_by: []
---

# grill-me

Walk the design tree depth-first. Resolve the current branch before backing out. Three rules:

1. **One question at a time.** Wait for the user's response before asking the next. Don't batch.
2. **Recommend, then ask.** Every question takes the form: "I think *<X>* because *<reason>*. Do you agree, or do you want *<alternative>*?" The recommendation is the default — the user accepts with "yes" or steers with an alternative.
3. **Ask code, not user, when possible.** Before asking, check: can `Read`, `Grep`, or `Glob` answer this? If yes, do that and proceed. Only ask the user when the answer is genuinely in their head.

**Exit condition:** every decision in the tree has a chosen answer plus your analysis attached. Output a final `Decisions` section the user can paste into a plan or brief — one bullet per decision, with the chosen answer and a one-line rationale.

**Compose with:** `architecture-rescue` when grilling about an unfamiliar codebase; `maintain-context` to capture decisions as ADRs or glossary entries; `plan-builder` to turn the `Decisions` output into an executable plan.
