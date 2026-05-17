# Architecture Language

The canonical vocabulary for `architecture-rescue` and any document it produces. Use these terms exactly. Each entry has an `_Avoid_:` list — synonyms forbidden in this project's writing because they smuggle in the wrong mental model.

This pattern is modeled on mattpocock's `LANGUAGE.md`: pick one word per concept, write it down, refuse the rest.

---

## Module

A unit of code that hides a decision behind a name. The decision can be a representation choice (how a thing is stored), a policy (when to retry), a vendor binding (which storage), or a workflow (the order of steps in checkout). A *module* is the smallest piece of the system that has both a name and a reason to exist.

A directory is not automatically a module. A class is not automatically a module. A module is whatever group of code shares **one decision** that callers shouldn't have to know about.

_Avoid_: component, service (unless it really is a long-running service), package (unless the build system uses the term), layer, util, helper.

---

## Interface

The surface a caller sees. Function signatures, exported types, the wire shape, the column names in a public view. Everything that isn't implementation.

A good interface answers "what" without leaking "how". A bad one leaks a vendor name, a database column, a retry count, or a timezone assumption.

_Avoid_: API (overloaded; reserve for HTTP/REST surfaces), contract (reserve for our `contracts/` directory and integration boundaries between agents), signature (too narrow), public method (too narrow).

---

## Implementation

Everything behind the interface. The actual code that does the work. The chosen storage, the loop structure, the third-party SDK calls, the in-memory caches.

Implementations should be replaceable. If they aren't, the interface is leaking.

_Avoid_: internals, body, guts, plumbing.

---

## Depth

The ratio of implementation to interface. A *deep* module has a small interface and a large implementation behind it — much is hidden, little is asked of the caller. A *shallow* module exposes nearly its entire implementation through its interface, often as a one-to-one method-per-internal-function mapping.

Shallow modules add ceremony without hiding decisions. They're the most common smell this skill finds. The deletion test usually exposes them: delete a shallow module and callers lose nothing.

This term comes from John Ousterhout (*A Philosophy of Software Design*). Use it deliberately — it's the central concept of this skill.

_Avoid_: thickness, density, weight, fat/thin (too judgmental, smuggles in dieting metaphors).

---

## Seam

A place in the code where you can substitute behavior. A seam exists if you can replace the real implementation with a fake (for testing), with a different vendor (for portability), or with an isolated stub (for staging) — without changing the callers.

Seams are not necessarily interfaces. A seam can be implicit (a function parameter that happens to accept any callable) or explicit (a named interface with two implementations). The two-adapter rule promotes implicit seams to explicit ones once they have evidence.

The opposite of a seam is a *welded join*: callers reach directly into one specific implementation and there is no way to swap it.

_Avoid_: boundary (ambiguous), abstraction point (too academic), injection point (too DI-flavored), hook (overloaded with React/lifecycle meanings).

---

## Adapter

A thin shim that translates between two interfaces. An adapter exists when you have one interface you control and one you don't — the SDK from a vendor, the wire format of a legacy system, a foreign domain model — and you wrap the foreign side in the shape your code wants.

Adapters are inventory for the two-adapter rule. Count them.

_Avoid_: wrapper (too generic), client (reserve for HTTP/gRPC clients), facade (different intent — facades unify; adapters translate), shim (informal; OK in conversation, not in docs).

---

## Leverage

The property that changing one place causes many callers to benefit (or, conversely, that adding one new caller is cheap). High-leverage code is worth investing in. Low-leverage code that's expensive to maintain is a refactoring target.

Use the word *leverage* when explaining why a candidate is worth doing. "Three callers" is data; "high leverage" is the claim.

_Avoid_: impact (too vague), reach, blast radius (negative-coded — reserve for incidents).

---

## Locality

The property that related decisions live next to each other in the code, so that a person reading one part doesn't have to chase across the tree to understand it. High locality reduces cognitive load. Low locality is what makes ball-of-mud codebases exhausting.

Locality and leverage often pull in opposite directions — *more locality* can mean *less reuse*, and vice versa. Naming the tradeoff explicitly is part of the skill's value.

_Avoid_: cohesion (still fine in academic writing, but jargon-heavy), proximity, togetherness.

---

## Notes for writers

- Pick the canonical term once per document; do not vary for stylistic flow.
- If a term you want isn't here, propose adding it before using a synonym.
- When introducing a term to a new collaborator, link them to this file rather than redefining.
