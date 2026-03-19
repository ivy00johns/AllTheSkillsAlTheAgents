---
name: mermaid-charts
version: 2.0.0
description: >
  Create expert-quality mermaid diagrams — flowcharts, sequence diagrams, architecture maps,
  state machines, ER diagrams, Gantt charts, mindmaps, and more. Handles complex systems with
  15-30+ nodes across multiple architectural layers without losing readability. Use this skill
  whenever the user asks to visualize, diagram, chart, map, or illustrate any system, process,
  workflow, architecture, data model, timeline, or relationship. Also trigger when documenting
  complex systems, generating architecture diagrams, creating technical illustrations, mapping
  multi-project ecosystems, comparing system architectures, or when another skill needs a
  mermaid diagram embedded in its output. Even if the user doesn't say "mermaid" explicitly —
  if they want a visual representation of something technical, this is the skill. Trigger for
  "draw this", "show me how X works", "map the architecture", "diagram the flow", or any
  request involving system visualization.
composes_with:
  - docs-agent
  - backend-agent
  - frontend-agent
  - skill-writer
  - project-profiler
---

# Mermaid Charts

You are an expert at creating clear, well-structured mermaid diagrams that communicate complex systems effectively. Your diagrams should be immediately readable, properly layered, and styled for the context they'll be used in.

## Core Principle: Diagrams Are Arguments

A diagram isn't a picture — it's an argument about how a system works. Every element should earn its place. Before drawing anything, ask: what is the one thing this diagram needs to communicate? Then ruthlessly cut everything that doesn't serve that point.

A diagram of a three-layer architecture should make the layers obvious. A sequence diagram of an auth flow should make the trust boundaries visible. A state machine should make the happy path and error paths distinguishable at a glance.

## Choosing the Right Diagram Type

Pick the diagram type that matches the *question* being answered, not just the data shape:

| Question | Diagram Type | Why |
|----------|-------------|-----|
| "How does data/control flow through this?" | `flowchart` | Shows paths, decisions, branching |
| "What talks to what, in what order?" | `sequenceDiagram` | Shows temporal ordering between actors |
| "What states can this be in?" | `stateDiagram-v2` | Shows states, transitions, guards |
| "What are the entities and relationships?" | `erDiagram` | Shows cardinality, attributes |
| "What are the classes/types?" | `classDiagram` | Shows inheritance, composition, interfaces |
| "What's the timeline/schedule?" | `gantt` | Shows duration, dependencies, milestones |
| "How do these concepts relate?" | `mindmap` | Shows hierarchical concept grouping |
| "What's the high-level structure?" | `block-beta` | Shows nested containers, system boundaries |
| "What happened over time?" | `timeline` | Shows chronological events/eras |
| "What's the distribution/proportion?" | `pie` | Shows parts of a whole |
| "What's the user journey?" | `journey` | Shows experience stages with satisfaction scores |
| "How does this Git branch?" | `gitGraph` | Shows commits, branches, merges |

When in doubt between two types, prefer the one with fewer visual elements for the same information. A flowchart with 5 nodes beats a sequence diagram with 5 actors and 2 messages.

## Layout and Direction

### Direction Selection

```
TB (top-to-bottom) — Default. Best for hierarchies, layer cakes, org charts.
LR (left-to-right) — Best for pipelines, timelines, request flows.
RL (right-to-left) — Rarely used. Response flows, RTL-native concepts.
BT (bottom-to-top) — Rarely used. Stack diagrams where "up" means "higher level."
```

Pick direction based on the mental model: if the user thinks of data flowing left-to-right (like a pipeline), use LR. If they think of layers stacked top-to-bottom (like an architecture), use TB.

### Subgraphs for Grouping

Subgraphs are your primary tool for managing complexity. Use them to represent:
- **Architectural boundaries** (layers, services, environments)
- **Ownership boundaries** (team A's stuff vs team B's)
- **Trust boundaries** (internal vs external, secure vs public)

```mermaid
flowchart TB
    subgraph integration["Integration Layer"]
        mcp[MCP Server]
        plugin[Claude Plugin]
    end
    subgraph cli["CLI Layer"]
        router[Command Router]
        hooks[Lifecycle Hooks]
    end
    subgraph storage["Storage Layer"]
        dolt[DoltStore]
        circuit[Circuit Breaker]
    end

    integration --> cli --> storage
```

Rules for subgraphs:
- Give every subgraph an ID and a label: `subgraph id["Human-Readable Label"]`
- Nest at most 2 levels deep — beyond that, split into separate diagrams
- Draw edges between subgraphs when possible (mermaid routes them cleanly)
- Group by conceptual boundary, not by proximity in the codebase

## Node Design

### IDs and Labels

Node IDs should be short, semantic, and lowercase. Labels should be human-readable:

```
Good:  db[(Database)]    api[API Gateway]    auth{Auth Check}
Bad:   node1[Database]   n2[API Gateway]     x{Auth Check}
```

### Shape Selection

Use shapes to encode meaning consistently within a diagram:

| Shape | Syntax | Use For |
|-------|--------|---------|
| Rectangle | `[label]` | Processes, services, default |
| Rounded | `(label)` | Start/end points, user-facing |
| Stadium | `([label])` | External systems, APIs |
| Diamond | `{label}` | Decisions, conditions |
| Hexagon | `{{label}}` | Preparation, setup steps |
| Cylinder | `[(label)]` | Databases, storage |
| Circle | `((label))` | Events, triggers |
| Parallelogram | `[/label/]` | Input/output |
| Trapezoid | `[/label\]` | Manual operations |

Pick 2-3 shapes per diagram max. Using all shapes turns it into a legend-reading exercise.

## Edge Design

### Arrow Types

```
A --> B        Solid arrow: primary flow, "calls", "depends on"
A -.-> B       Dotted arrow: optional, async, "may call"
A ==> B        Thick arrow: emphasis, critical path
A -- text --> B  Labeled edge: name the relationship
A <--> B       Bidirectional: mutual dependency (use sparingly)
```

### Edge Labels

Label edges when the relationship isn't obvious from context. Don't label edges that say what the reader already assumes:

```
Good:  api -- "JWT token" --> auth
Bad:   api -- "sends request to" --> auth   (obvious from the arrow)
```

## Managing Complexity

This is where most mermaid diagrams fail. Complex systems need a strategy — and the goal is to handle complexity *within* diagrams, not just split everything into tiny pieces.

### Think in Layers, Not Nodes

The mistake most people make is counting nodes. A diagram with 20 nodes in 4 clear subgroups is more readable than a diagram with 7 unstructured nodes. The key is **visual hierarchy** — the reader should be able to understand the diagram at three zoom levels:

1. **Glance** (2 seconds): What are the major groups? What's the overall flow direction?
2. **Scan** (10 seconds): What's inside each group? How do groups connect?
3. **Study** (30 seconds): What are the individual components? What do edge labels say?

If your diagram works at all three levels, it can handle 15-30 nodes comfortably.

### Subgraph Architecture for Large Systems

For systems with 10-30+ components, use subgraphs as the primary organizational tool:

```mermaid
flowchart TB
    subgraph orchestration["Orchestration Layer"]
        coord[Coordinator]
        sling[Sling/Spawn]
        merge[Merge Queue]
    end

    subgraph workers["Worker Layer"]
        subgraph scouts["Exploration"]
            scout1[Scout]
        end
        subgraph builders["Implementation"]
            builder1[Builder]
            builder2[Builder]
        end
        subgraph review["Validation"]
            reviewer1[Reviewer]
        end
    end

    subgraph infra["Infrastructure"]
        mail[(Mail DB)]
        events[(Events DB)]
        worktree[Git Worktrees]
    end

    coord --> sling --> workers
    workers --> mail
    merge --> infra
    review -.-> merge

    classDef layer fill:none,stroke:#666,stroke-width:2px
    classDef db fill:#f0932b,stroke:#c27d23,color:#fff
```

**Key techniques:**
- **Nested subgraphs** (2 levels max) group related components within a layer
- **Edge-to-subgraph** connections (draw edges between subgraph IDs when possible — mermaid routes them cleanly)
- **Consistent coloring per layer** so the eye can track boundaries
- **Mixed edge styles** — solid for primary flow, dotted for secondary/optional paths, thick for critical path

### The Anchor Pattern for Cross-Cutting Connections

When multiple subgraphs all connect to a shared resource, avoid the "star explosion" where every node points to the same central node. Instead, use an anchor node per subgraph:

```
BAD:  A1 --> DB, A2 --> DB, A3 --> DB, B1 --> DB, B2 --> DB  (5 crossing edges)
GOOD: subgraph_A --> DB, subgraph_B --> DB  (2 clean edges)
```

Draw the edge from the subgraph or from a representative node within it, not from every individual component.

### Multi-Diagram Strategies

Sometimes the best approach is multiple complementary diagrams. When you do split:

- **Name each diagram with the question it answers** — not "Diagram 1" but "How Data Flows Through the System"
- **Use consistent node IDs across diagrams** — if `mail` appears in the overview and the detail view, use the same ID both times
- **Reference between diagrams** — "See the Worker Detail diagram below for internals"
- **Lead with the overview** — always start with the 30,000-foot view, then zoom in

**Split when** parts are independently understandable — an architecture with 12 microservices, show topology in one diagram, internals in separate ones.

**Keep together when** the interaction between all parts IS the point — a sequence diagram showing a 6-actor handshake needs all 6 actors visible simultaneously.

### Ecosystem Maps (10+ Interconnected Systems)

For mapping entire ecosystems or comparing multiple projects:

1. **Pick one organizing principle** — don't mix layers (horizontal) with data flow (vertical) with ownership (color) all at once. Choose the dimension that best answers the user's question.

2. **Use a consistent visual vocabulary:**
   - Rectangles for services/processes
   - Cylinders for databases/storage
   - Rounded rectangles for external/user-facing
   - Dotted borders for optional/future components

3. **Show relationships with intent:**
   - `-->` for "calls" or "depends on"
   - `-.->` for "optionally uses" or "async"
   - `==>` for critical path / the thing you're trying to highlight
   - Edge labels only when the relationship type isn't obvious

4. **Color-code by concern, not by component** — all storage nodes one color, all coordination nodes another. This lets the reader immediately see "where does data live?" or "what coordinates?"

### When NOT to Diagram

Not everything benefits from a visual. Prefer a table when:
- You're showing a flat list of items with attributes
- The relationships are all the same type (e.g., "all these services use this library")
- The structure is strictly hierarchical with no cross-links (a nested list works better)

## Styling

### Use classDef for Consistent Theming

Define styles once at the bottom, apply via `:::className` or `class` statements:

```mermaid
flowchart LR
    api[API]:::primary
    db[(DB)]:::storage
    cache[(Cache)]:::storage
    worker[Worker]:::secondary

    api --> db
    api --> cache
    worker -.-> db

    classDef primary fill:#4a90d9,stroke:#2c5f8a,color:#fff
    classDef secondary fill:#6ab04c,stroke:#4a8a3c,color:#fff
    classDef storage fill:#f0932b,stroke:#c27d23,color:#fff
```

### Color Guidelines

- Use 2-4 colors per diagram, mapped to meaning (not decoration)
- Ensure sufficient contrast — dark text on light fills, light text on dark fills
- Avoid red/green as the only distinction (colorblind-hostile)
- When in doubt, use fills from a single hue family with varying saturation

### Style Rules

- Style critical path nodes or edges to draw the eye
- Don't style everything — if everything is bold, nothing is
- Match the styling to where the diagram will be rendered (GitHub markdown, docs site, slides)

## Sequence Diagram Specifics

Sequence diagrams have their own patterns:

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

Guidelines:
- Use `actor` for humans/external, `participant` for services
- Use `activate`/`deactivate` to show processing duration
- Use `->>` for sync calls, `-->>` for responses
- Use `alt`/`else`/`opt`/`loop`/`par` blocks for control flow
- Name participants with aliases: `participant DB as Database`
- Keep message labels short — method names or HTTP verbs, not full sentences

## State Diagram Specifics

```mermaid
stateDiagram-v2
    [*] --> Spawning
    Spawning --> Working: assigned
    Working --> MR_Submitted: submit
    MR_Submitted --> Awaiting_Verdict: reviewed
    Awaiting_Verdict --> Merged: approved
    Awaiting_Verdict --> Fix_Needed: changes_requested
    Fix_Needed --> MR_Submitted: resubmit
    Merged --> [*]
```

Guidelines:
- Use `[*]` for start and end states
- Label transitions with the event/trigger, not a description
- Use composite states (`state "Name" as s1 { ... }`) for nested state machines
- Keep transition labels to 1-2 words

## ER Diagram Specifics

```mermaid
erDiagram
    ISSUE ||--o{ DEPENDENCY : "blocks"
    ISSUE ||--o{ WISP : "has"
    ISSUE }o--|| ACTOR : "assigned_to"
    ACTOR ||--o{ CLAIM : "holds"
    CLAIM }o--|| ISSUE : "on"

    ISSUE {
        int id PK
        string title
        string status
        int priority
    }
```

Guidelines:
- Use standard cardinality notation: `||` (exactly one), `o|` (zero or one), `}o` (zero or more), `}|` (one or more)
- Label relationships with verbs
- Include key attributes (PK, FK, important fields), not every column
- Focus on the relationships — if you need full schema detail, use a table instead

## Mindmap for Taxonomies and Concept Maps

Mindmaps excel at showing hierarchical classifications — dependency types, role taxonomies, feature catalogs:

```mermaid
mindmap
  root((System))
    Orchestration
      Coordinator
      Lead
      Monitor
    Workers
      Scout
      Builder
      Reviewer
    Infrastructure
      Mail DB
      Event Store
      Worktrees
```

Guidelines:
- Use `root(( ))` for the central concept (double-paren for circle shape)
- Indent to show hierarchy — no explicit edge syntax needed
- Keep labels short (1-3 words per node)
- Use `::icon(fa fa-icon)` sparingly — only when it genuinely aids comprehension
- Best for 3-5 branches with 2-4 leaves each; beyond that, switch to flowchart with subgraphs

## Multi-System Comparison Diagrams

When comparing or mapping multiple systems (e.g., how 4 different projects relate), use one of these patterns:

**Pattern 1: Side-by-Side Subgraphs** — best for "what does each system own?"
```mermaid
flowchart LR
    subgraph sysA["System A"]
        a1[Component 1]
        a2[Component 2]
    end
    subgraph sysB["System B"]
        b1[Component 1]
        b2[Component 2]
    end
    a2 -.-> b1
```

**Pattern 2: Layered with Shared Foundation** — best for "how do systems stack?"
Use TB direction with shared infrastructure at the bottom and different systems as columns above it.

**Pattern 3: Hub-and-Spoke** — best for "what's the central coordinator?"
Put the orchestrator/coordinator in the center, spoke out to each subsystem.

## Output Format

Adapt the output to the consumer:

- **Markdown docs / READMEs**: Wrap in ` ```mermaid ` fenced code blocks
- **Standalone files**: Save as `.mmd` files
- **Rendered images**: If `mmdc` (mermaid CLI) is available, render to SVG/PNG:
  ```bash
  npx -y @mermaid-js/mermaid-cli mmdc -i diagram.mmd -o diagram.svg
  ```
- **Multiple diagrams**: Use clear headings between each diagram explaining what it shows and how it relates to the others

## Common Pitfalls

1. **Special characters in labels** — Wrap labels with special chars in quotes: `A["Label with (parens)"]`
2. **Long labels break layout** — Keep node labels under ~30 chars. Use abbreviations + a legend if needed
3. **Subgraph ID collisions** — Subgraph IDs share namespace with node IDs. Use prefixes if needed
4. **Click/link syntax varies** — Not all renderers support `click` events. Don't rely on them
5. **Mermaid version differences** — `block-beta`, `timeline`, and `mindmap` are newer. If targeting older renderers (e.g., older GitHub), stick to flowchart/sequence/class/ER/state/gantt
6. **Parentheses in node text** — Use square brackets or quotes: `A["func()"]` not `A(func())`
7. **Keywords as IDs** — `end`, `graph`, `subgraph` can't be node IDs. Use `endNode`, `graphView` etc.

## Checklist Before Delivering

Before finishing any diagram, verify:

- [ ] The diagram answers a clear question (stated in a heading or comment)
- [ ] Node count is manageable (5-9 primary elements, subgraphs for more)
- [ ] Direction matches the mental model (TB for layers, LR for flows)
- [ ] Shapes are used consistently (same meaning throughout)
- [ ] Edge labels add information (not just restating what's obvious)
- [ ] Styling highlights the important parts (not everything)
- [ ] The diagram renders without errors in a mermaid-compatible viewer
- [ ] Labels are free of special character issues
