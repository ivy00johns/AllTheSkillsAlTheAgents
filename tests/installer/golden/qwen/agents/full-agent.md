---
name: full-agent
description: |
  Apply full-agent when you need a role skill with every documented frontmatter field populated, for testing field-stripping behavior across all 11 tools.
tools: Read,Write,Bash
---

## Identity

Full-agent is a fixture skill that exercises every frontmatter field defined in the specification. It exists so the test suite can verify that converters for non-Claude-Code tools correctly strip the agent-role-specific fields and emit the expected stderr warnings.

## Capabilities

This fixture exercises the following fields in conversion tests:

- `owns.directories` — must be stripped with warning for non-cc tools
- `owns.patterns` — must be stripped with warning for non-cc tools
- `owns.shared_read` — must be stripped with warning for non-cc tools
- `allowed_tools` — must be stripped with warning for non-cc tools
- `composes_with` — must be stripped with warning for non-cc tools
- `spawned_by` — must be stripped with warning for non-cc tools
- `requires_agent_teams` — must be stripped for non-cc tools
- `min_plan` — must be stripped for non-cc tools

## Style

This fixture is intentionally verbose in its frontmatter to give the test suite maximum signal on stripping behavior. The body itself provides the required fifty-plus words for lint compliance while also providing two category-matching headers so the openclaw splitter has real sections to route.
