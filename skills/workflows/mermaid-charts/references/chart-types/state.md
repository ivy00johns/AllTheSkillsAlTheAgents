# State Diagram

Answers "What states can this be in?" — shows states, transitions, guards.

## Pattern

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

## Guidelines

- Use `[*]` for start and end states
- Label transitions with the event/trigger, not a description
- Use composite states (`state "Name" as s1 { ... }`) for nested state machines
- Keep transition labels to 1-2 words
