# Advanced Mermaid Patterns

Reference for complex diagram scenarios. Read this when the main SKILL.md guidance isn't sufficient for the task at hand.

## Table of Contents

1. [Multi-Diagram Document Structure](#multi-diagram-document-structure)
2. [Complex Flowcharts](#complex-flowcharts)
3. [Architecture Diagrams](#architecture-diagrams)
4. [Sequence Diagram Advanced Patterns](#sequence-diagram-advanced-patterns)
5. [Block-Beta for System Maps](#block-beta-for-system-maps)
6. [Theming and Branding](#theming-and-branding)
7. [Rendering Pipeline](#rendering-pipeline)

---

## Multi-Diagram Document Structure

When a system needs multiple diagrams, structure them as a narrative:

```markdown
# System Name — Architecture

## Overview
[High-level diagram showing major components and their relationships]

## Data Flow
[How data moves through the system — request/response paths]

## Component Detail: [Name]
[Zoomed-in view of one component's internals]

## State Lifecycle
[State machine for the primary entity]
```

Each diagram should be self-contained but reference the others by name. Use consistent node IDs across diagrams when the same component appears in multiple views — this helps the reader build a mental map.

---

## Complex Flowcharts

### Decision Trees

For multi-level decisions, use nested subgraphs to group related branches:

```mermaid
flowchart TB
    start([Request]) --> check{Auth?}

    subgraph authenticated["Authenticated Path"]
        check -->|yes| role{Role?}
        role -->|admin| admin[Admin Panel]
        role -->|user| user[User Dashboard]
    end

    subgraph unauthenticated["Unauthenticated Path"]
        check -->|no| login[Login Page]
        login --> oauth{OAuth?}
        oauth -->|yes| provider[OAuth Provider]
        oauth -->|no| local[Local Auth]
    end

    provider --> callback[Callback] --> check
    local --> check
```

### Parallel Paths

Show parallel execution with a fork/join pattern:

```mermaid
flowchart LR
    start([Start]) --> fork{{"Fork"}}
    fork --> a[Task A]
    fork --> b[Task B]
    fork --> c[Task C]
    a --> join{{"Join"}}
    b --> join
    c --> join
    join --> done([Done])
```

### Error Handling Flows

Use dotted lines and red styling for error paths:

```mermaid
flowchart TB
    req[Request] --> validate{Valid?}
    validate -->|yes| process[Process]
    validate -.->|no| err400[400 Bad Request]:::error
    process --> save[Save to DB]
    save --> respond[200 OK]
    save -.->|failure| err500[500 Server Error]:::error

    classDef error fill:#e74c3c,stroke:#c0392b,color:#fff
```

---

## Architecture Diagrams

### Three-Tier Architecture

```mermaid
flowchart TB
    subgraph presentation["Presentation Tier"]
        web[Web App]
        mobile[Mobile App]
        cli[CLI]
    end

    subgraph logic["Business Logic Tier"]
        api[API Gateway]
        auth[Auth Service]
        core[Core Service]
        worker[Background Worker]
    end

    subgraph data["Data Tier"]
        db[(Primary DB)]
        cache[(Redis Cache)]
        queue[(Message Queue)]
        blob[(Object Store)]
    end

    web & mobile & cli --> api
    api --> auth
    api --> core
    core --> db & cache
    core --> queue
    worker --> queue
    worker --> db
    worker --> blob

    classDef tier fill:none,stroke:#666,stroke-dasharray:5 5
```

### Microservice Communication

For microservice architectures, focus on the communication patterns:

```mermaid
flowchart LR
    subgraph sync["Synchronous (REST/gRPC)"]
        direction LR
        gateway[API Gateway] --> users[Users]
        gateway --> orders[Orders]
        orders --> inventory[Inventory]
    end

    subgraph async["Asynchronous (Events)"]
        direction LR
        orders2[Orders] -.->|OrderPlaced| bus((Event Bus))
        bus -.-> notify[Notifications]
        bus -.-> analytics[Analytics]
        bus -.-> warehouse[Warehouse]
    end
```

---

## Sequence Diagram Advanced Patterns

### Parallel and Alternative Flows

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant S as Service
    participant D as DB
    participant Ca as Cache

    C->>A: GET /resource/123

    par Cache Check
        A->>Ca: get("resource:123")
        Ca-->>A: miss
    and Auth Check
        A->>A: validateToken()
    end

    A->>S: fetchResource(123)

    alt Found in DB
        S->>D: SELECT * WHERE id=123
        D-->>S: row
        S-->>A: resource
        A->>Ca: set("resource:123", resource)
    else Not Found
        S-->>A: null
        A-->>C: 404 Not Found
    end

    A-->>C: 200 OK + resource
```

### Critical and Break Blocks

```mermaid
sequenceDiagram
    participant U as User
    participant A as API
    participant P as Payment

    U->>A: POST /checkout

    critical Payment Processing
        A->>P: charge(amount)
        P-->>A: confirmation
    option Payment Declined
        P-->>A: declined
        A-->>U: 402 Payment Required
    option Timeout
        A-->>U: 504 Gateway Timeout
    end

    A-->>U: 200 Order Confirmed
```

### Numbered Steps with Notes

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant G as Gateway
    participant S as Service

    C->>G: Request
    Note over G: Validate, rate-limit
    G->>S: Forward
    Note over S: Process business logic
    S-->>G: Response
    Note over G: Add headers, log
    G-->>C: Response
```

---

## Block-Beta for System Maps

Block-beta diagrams are excellent for showing containment and boundary relationships:

```mermaid
block-beta
    columns 3

    space:3

    block:cloud["Cloud Environment"]:3
        block:vpc["VPC"]:3
            block:public["Public Subnet"]:1
                lb["Load Balancer"]
            end
            block:private["Private Subnet"]:2
                app["App Servers"]
                db["Database"]
            end
        end
    end

    users["Users"] --> lb
```

---

## Theming and Branding

### Custom Theme via Init Directive

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#4a90d9',
    'primaryBorderColor': '#2c5f8a',
    'primaryTextColor': '#fff',
    'lineColor': '#5a6c7d',
    'secondaryColor': '#f0f4f8',
    'tertiaryColor': '#e8f5e9'
  }
}}%%
flowchart LR
    A[Service A] --> B[Service B]
```

### Dark Mode Friendly Colors

For diagrams that need to work on both light and dark backgrounds:

```
Primary:   fill:#4a90d9, stroke:#2c5f8a, color:#fff
Secondary: fill:#6ab04c, stroke:#4a8a3c, color:#fff
Warning:   fill:#f0932b, stroke:#c27d23, color:#fff
Error:     fill:#e74c3c, stroke:#c0392b, color:#fff
Neutral:   fill:#95a5a6, stroke:#7f8c8d, color:#fff
```

These have enough contrast to work on white, light gray, and dark backgrounds.

---

## Rendering Pipeline

### Using mermaid-cli (mmdc)

```bash
# Install
npm install -g @mermaid-js/mermaid-cli

# SVG (best for web)
mmdc -i diagram.mmd -o diagram.svg

# PNG (best for docs/slides)
mmdc -i diagram.mmd -o diagram.png -w 1200

# PDF
mmdc -i diagram.mmd -o diagram.pdf

# With custom theme
mmdc -i diagram.mmd -o diagram.svg -t dark

# With custom config
mmdc -i diagram.mmd -o diagram.svg -c mermaid.config.json
```

### Config File for Consistent Rendering

```json
{
  "theme": "default",
  "flowchart": {
    "curve": "basis",
    "padding": 20
  },
  "sequence": {
    "diagramMarginX": 20,
    "diagramMarginY": 10,
    "actorMargin": 50,
    "noteMargin": 10
  }
}
```

### Batch Rendering

```bash
# Render all .mmd files in a directory
for f in docs/diagrams/*.mmd; do
  mmdc -i "$f" -o "${f%.mmd}.svg"
done
```
