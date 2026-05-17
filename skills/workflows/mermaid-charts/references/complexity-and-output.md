# Managing Complexity and Output

How to keep dense diagrams readable, and how to render them for different consumers.

## Think in Layers, Not Nodes

The mistake most people make is counting nodes. A diagram with 20 nodes in 4 clear subgroups is more readable than a diagram with 7 unstructured nodes. The key is **visual hierarchy** — the reader should understand the diagram at three zoom levels:

1. **Glance** (2 seconds): What are the major groups? What's the overall flow direction?
2. **Scan** (10 seconds): What's inside each group? How do groups connect?
3. **Study** (30 seconds): What are the individual components? What do edge labels say?

If your diagram works at all three levels, it can handle 15-30 nodes comfortably.

## Multi-Diagram Strategies

Sometimes the best approach is multiple complementary diagrams. When you do split:

- **Name each diagram with the question it answers** — not "Diagram 1" but "How Data Flows Through the System"
- **Use consistent node IDs across diagrams** — if `mail` appears in the overview and the detail view, use the same ID both times
- **Reference between diagrams** — "See the Worker Detail diagram below for internals"
- **Lead with the overview** — always start with the 30,000-foot view, then zoom in

**Split when** parts are independently understandable — an architecture with 12 microservices, show topology in one diagram, internals in separate ones.

**Keep together when** the interaction between all parts IS the point — a sequence diagram showing a 6-actor handshake needs all 6 actors visible simultaneously.

## Ecosystem Maps (10+ Interconnected Systems)

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

4. **Color-code by concern, not by component** — all storage nodes one color, all coordination nodes another.

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
