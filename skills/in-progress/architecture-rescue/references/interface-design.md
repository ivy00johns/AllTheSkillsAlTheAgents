# Interface Design — Design It Twice

Once `architecture-rescue` has produced numbered candidates and `grill-me` has resolved the open questions for the chosen one, you finally get to design the interface. Do not commit to the first sketch.

## The technique

Before writing any code, sketch **two genuinely different interfaces** for the same module. Compare them. Pick one — or merge the best parts of both. The point is not democratic procedure; the point is that the *second* sketch usually reveals something the *first* could not.

Senior engineers do this instinctively. Less experienced engineers stop after the first design that "seems fine" — and ship the local optimum.

This pattern is John Ousterhout's "Design It Twice". It is one of the highest-leverage habits in software design and one of the cheapest to apply.

## Rules

1. **The two sketches must be genuinely different.** Same idea with renamed methods doesn't count. Look for orthogonal axes — pull vs push, sync vs async, batched vs streamed, callback vs return value, immutable vs mutating, stateful vs stateless, declarative vs imperative.
2. **No code yet.** Type signatures, prose, or a whiteboard sketch — that's the level of fidelity. Implementations are too expensive to throw away; signatures are cheap.
3. **Write down the tradeoffs.** For each sketch: what gets easier, what gets harder, what kind of bug becomes more likely, what kind of change becomes painful.
4. **Pick or merge — explicitly.** Don't leave it ambiguous which sketch won and why. If you merged, name what you took from each.

## Output shape

```text
### Sketch A: <name>

```ts
// signatures or pseudocode
```

- Wins: <what this sketch does well>
- Loses: <what it gives up>
- Pain on change: <which kind of future change hurts most>

### Sketch B: <name>

```ts
// signatures or pseudocode
```

- Wins: ...
- Loses: ...
- Pain on change: ...

### Decision

Picked: A / B / merged (taking X from A, Y from B).
Why: <one or two sentences>
```

## Common axes to explore

When the second sketch feels like just a paint job of the first, deliberately flip one of these:

| Axis | Direction A | Direction B |
|---|---|---|
| Direction of control | Caller pulls | Module pushes (callback / event) |
| Time | Sync | Async / promise / stream |
| Granularity | One item per call | Batch per call |
| State | Stateless function | Stateful object / handle |
| Mutation | Returns new value | Mutates argument |
| Errors | Throws | Returns Result / Either |
| Naming axis | By the *what* (resource) | By the *verb* (action) |
| Layer | Domain-shaped | Storage-shaped |

Pick whichever flip exposes the most interesting tradeoff for the candidate at hand.

## When to use just one sketch

When the interface is trivial — a one-method module wrapping a single SDK call, a pure data type — Design It Twice is overkill. Use it whenever the module is doing **policy** (deciding *how*), **workflow** (ordering steps), or **coordination** (mediating between two parties). Those are where the wrong shape costs the most.

## Anti-patterns

| Anti-pattern | Why it's bad |
|---|---|
| Both sketches are minor variations | You haven't actually designed twice; you've designed once with two coats of paint |
| Skipping straight to code | Signatures are throwaway; implementations are not — use the cheap stage |
| Picking without writing tradeoffs | Future readers (including you) will not remember why |
| "We can change it later" | Interfaces calcify the moment they have callers; the cost of changing later is the whole point of designing twice now |
