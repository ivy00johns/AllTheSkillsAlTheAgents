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

## Template Patterns

### Agent Role Skills

```
[Verb] [what it builds] for multi-agent builds. Use this skill when
spawning a [role] agent, [specific task 1], [specific task 2], or
[specific task 3]. Trigger for any [domain] task within an orchestrated build.
```

### Workflow Skills

```
[Verb] [what process it manages] for [context]. Use this skill when
[trigger 1], [trigger 2], or [trigger 3]. Trigger when someone says
"[phrase 1]", "[phrase 2]", or [condition].
```

### Meta Skills

```
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
- [ ] Under 200 characters (target)
- [ ] Contains at least 3 specific trigger contexts
- [ ] Includes keyword variants users might say
- [ ] States exclusions if commonly confused with another skill
- [ ] Written in 3rd person
- [ ] Would pass the "would Claude invoke this?" test
