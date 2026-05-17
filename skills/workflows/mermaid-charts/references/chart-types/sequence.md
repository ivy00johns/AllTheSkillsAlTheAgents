# Sequence Diagram

Answers "What talks to what, in what order?" — shows temporal ordering between actors.

## Pattern

```mermaid
sequenceDiagram
    actor User
    participant API as API Gateway
    participant Auth as Auth Service
    participant DB as Database

    User->>API: POST /login
    activate API
    API->>Auth: validate(credentials)
    activate Auth
    Auth->>DB: SELECT user WHERE...
    DB-->>Auth: user record
    Auth-->>API: JWT token
    deactivate Auth
    API-->>User: 200 OK + token
    deactivate API
```

## Guidelines

- Use `actor` for humans/external, `participant` for services
- Use `activate`/`deactivate` to show processing duration
- Use `->>` for sync calls, `-->>` for responses
- Use `alt`/`else`/`opt`/`loop`/`par` blocks for control flow
- Name participants with aliases: `participant DB as Database`
- Keep message labels short — method names or HTTP verbs, not full sentences
