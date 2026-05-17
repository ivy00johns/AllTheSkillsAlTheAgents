---
name: zoom-out
version: 1.0.0
description: "Step back from the current code and give a higher-level perspective: which modules are involved, how do they connect, what is this change touching that I'm not seeing? Uses the project's CONTEXT.md / domain glossary when available. Explicit invocation only — does not auto-fire. Use when feeling stuck in detail, when a change feels bigger than expected, or before making a structural decision."
disable-model-invocation: true
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Grep", "Glob"]
composes_with: ["maintain-context"]
spawned_by: []
---

# zoom-out

Go up a layer. Map the modules involved in this change. Use the domain glossary (`CONTEXT.md`) if one exists.

Output a numbered list of modules, one line per module describing its role, with arrows (`→`) showing the connections between them.

Do not propose changes. The user asked for orientation, not a fix.
