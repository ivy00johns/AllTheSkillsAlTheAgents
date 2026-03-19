# Runtime Orchestrator

This service will own:

- worker lifecycle
- sandbox provisioning
- git worktree setup
- retries, reroutes, and handoffs
- merge-ready completion callbacks

## Suggested implementation

- language: Go
- first milestone: dispatch one worker against one mission task and persist run state
