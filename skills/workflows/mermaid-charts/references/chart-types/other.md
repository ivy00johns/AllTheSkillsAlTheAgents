# Other Chart Types

The less-common but still useful chart types — pick when the question matches.

## Class Diagram

Answers "What are the classes/types?" — shows inheritance, composition, interfaces.

## Gantt

Answers "What's the timeline/schedule?" — shows duration, dependencies, milestones.

## Block-Beta

Answers "What's the high-level structure?" — shows nested containers, system boundaries.

## Timeline

Answers "What happened over time?" — shows chronological events/eras.

## Pie

Answers "What's the distribution/proportion?" — shows parts of a whole.

## Journey

Answers "What's the user journey?" — shows experience stages with satisfaction scores.

## gitGraph

Answers "How does this Git branch?" — shows commits, branches, merges.

## When NOT to Diagram

Not everything benefits from a visual. Prefer a table when:

- You're showing a flat list of items with attributes
- The relationships are all the same type (e.g., "all these services use this library")
- The structure is strictly hierarchical with no cross-links (a nested list works better)

## Mermaid Version Differences

`block-beta`, `timeline`, and `mindmap` are newer. If targeting older renderers (e.g., older GitHub), stick to flowchart/sequence/class/ER/state/gantt.
