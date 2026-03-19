# Future Platform Workspace

This workspace is the implementation surface for the clean-sheet platform
described in `plans/the-future/`.

## Goals

- build our own agentic software factory
- keep the control model explicit
- make evidence, policy, and routing first-class
- avoid inheriting accidental constraints from the audited repos

## Layout

```text
apps/
  control-plane/
  operator-console/
services/
  runtime-orchestrator/
  browser-automation/
  review-engine/
  router/
packages/
  contracts/
  sdk/
infra/
docs/
scripts/
```

## Local commands

```bash
make check-prereqs
make infra-up
make infra-down
make validate-schemas
```

## Local infrastructure

The local stack currently provisions:

- Postgres
- NATS
- MinIO
- ClickHouse

These are enough to start the control plane, evidence store, event bus, and
analytics surfaces without committing to hosted infrastructure yet.
