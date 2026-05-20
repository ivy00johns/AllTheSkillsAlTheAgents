# Description Writing Patterns

Claude tends to "undertrigger" skills — not invoking them when they'd be useful. Combat this with "pushy" descriptions that enumerate trigger contexts.

## The Problem

A description like "Helps with backend development" won't trigger because it's too vague. Claude defaults to handling the task itself.

## The Solution

Write descriptions that:

1. **Start with an action verb** — what the skill DOES
2. **Name specific trigger contexts** — when to use it
3. **Include keyword variants** — different ways users phrase the need
4. **State exclusions** (if ambiguous) — what it's NOT for

## Description Anatomy

Anthropic's official spec recommends three slots:

```text
[What it does] + [When to use it] + [Key capabilities or keyword variants]
```

- **What it does** — start with an action verb in 3rd person. "Generate", "Audit", "Manage", "Verify".
- **When to use it** — the trigger contexts. Phrase users would actually say. Multiple variants if the work has multiple natural entry points.
- **Key capabilities or keyword variants** — domain keywords, file types, exclusions. The "pushy" surface that beats under-triggering.

Length budget:

- **Target:** ≤200 characters — keeps descriptions scannable and forces tight triggers
- **Hard ceiling:** 1024 characters (Anthropic spec maximum)
- Use a multiline YAML block (`description: |`) when you need more than one paragraph

Forbidden characters:

- **No XML angle brackets** (`<`, `>`) — frontmatter loads into Claude's system prompt and is security-stripped

## Template Patterns

### Agent Role Skills

```text
[Verb] [what it builds] for multi-agent builds. Use this skill when
spawning a [role] agent, [specific task 1], [specific task 2], or
[specific task 3]. Trigger for any [domain] task within an orchestrated build.
```

### Workflow Skills

```text
[Verb] [what process it manages] for [context]. Use this skill when
[trigger 1], [trigger 2], or [trigger 3]. Trigger when someone says
"[phrase 1]", "[phrase 2]", or [condition].
```

### Meta Skills

```text
[Verb] [what it produces] for the skill ecosystem. Use this skill when
[trigger 1], [trigger 2], or [trigger 3]. Also use when [non-obvious trigger].
```

## Good vs Bad Examples

| Bad (won't trigger) | Good (will trigger) |
|---------------------|---------------------|
| "Helps with frontend" | "Build user interfaces, client-side state, and presentation layers for multi-agent builds. Trigger for React, Vue, Svelte UI work." |
| "Security stuff" | "Audit code for security vulnerabilities, enforce OWASP best practices, and validate auth implementations." |
| "Manages context" | "Manage context windows, compaction strategy, and session handoffs. Trigger when approaching context limits." |
| "Does testing" | "Verify implementations match contracts, integrations connect, and edge cases are handled. Trigger after implementation agents report done." |

## Quality Checklist

- [ ] Starts with an action verb (Build, Generate, Verify, Audit, Manage, Run)
- [ ] Under 200 characters (target); under 1024 (hard ceiling)
- [ ] Contains at least 3 specific trigger contexts
- [ ] Includes keyword variants users might say
- [ ] States exclusions if commonly confused with another skill
- [ ] Written in 3rd person
- [ ] Contains no `<` or `>` (forbidden by spec)
- [ ] Would pass the "would Claude invoke this?" test
