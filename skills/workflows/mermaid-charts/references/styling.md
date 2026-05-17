# Styling

Mermaid styling discipline — keep it purposeful, never decorative.

## Use classDef for Consistent Theming

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

## Color Guidelines

- Use 2-4 colors per diagram, mapped to meaning (not decoration)
- Ensure sufficient contrast — dark text on light fills, light text on dark fills
- Avoid red/green as the only distinction (colorblind-hostile)
- When in doubt, use fills from a single hue family with varying saturation

## Style Rules

- Style critical path nodes or edges to draw the eye
- Don't style everything — if everything is bold, nothing is
- Match the styling to where the diagram will be rendered (GitHub markdown, docs site, slides)

## Color-Code by Concern, Not by Component

All storage nodes one color, all coordination nodes another. This lets the reader immediately see "where does data live?" or "what coordinates?"
