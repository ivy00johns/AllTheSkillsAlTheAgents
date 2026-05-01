## Identity

Full-agent is a fixture skill that exercises every frontmatter field defined in the specification. It exists so the test suite can verify that converters for non-Claude-Code tools correctly strip the agent-role-specific fields and emit the expected stderr warnings.

## Style

This fixture is intentionally verbose in its frontmatter to give the test suite maximum signal on stripping behavior. The body itself provides the required fifty-plus words for lint compliance while also providing two category-matching headers so the openclaw splitter has real sections to route.
