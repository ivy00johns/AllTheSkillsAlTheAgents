# Control Plane

This app will own:

- project and mission lifecycle
- approvals
- policy execution
- API surface for the operator console
- coordination with the work graph, router, and orchestrator

## Suggested implementation

- language: Go
- responsibilities: API, auth, mission commands, approval workflow
- first milestone: `POST /missions`, `GET /missions/:id`, `POST /approvals/:id/decide`
