# ADR 0001 - Core Principles

## Status

Accepted

## Decision

The platform will follow these principles:

1. Evidence is first-class.
2. Policies and contracts are compiled objects, not ad hoc prompt text.
3. Runtime execution is model-neutral.
4. Work state is durable and queryable.
5. Human approvals are explicit objects in the system.
6. Git is an integration surface, not the universal database.
7. The platform must be measurable at the orchestration level.

## Consequences

- Postgres is the initial control-plane database.
- Object storage is used for screenshots, logs, traces, and reports.
- An event bus is part of the architecture from the start.
- The repo is split into control-plane, operator, runtime, quality, and shared contract surfaces.
