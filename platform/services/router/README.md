# Router

This service will own:

- worker selection
- runtime choice
- scorecards
- cost and quality tradeoffs
- retry and reroute decisions

## Suggested implementation

- language: Go
- first milestone: route a task using static capabilities, then persist route rationale
