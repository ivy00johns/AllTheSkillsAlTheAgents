# Anti-Patterns and Composition Notes

Failure modes to avoid in any Claude Design prompt, and how this skill composes with the other design / UI skills.

## Anti-Patterns

| Anti-Pattern | Prevention |
|---|---|
| Echoing "decide for me" back as a question | Decide. State the decision. Explain in one clause. The canvas executes on commitments, not questions. |
| Adjective-only tone ("modern", "clean", "professional") | Replace with two reference apps appropriate to the domain plus one named style. "NYT Magazine × Politico Magazine × wartime correspondent register" beats "professional and clean". |
| Silence on a decision area because "the user didn't mention it" | Check the coverage guide. An uncommitted decision is what makes Claude Design ask. Even "no newsletter CTA on this product" is a better answer than silence. |
| Structuring the prompt as a numbered 13-slot form | Write the brief to fit the project. The 13 categories are a coverage checklist, not an output format. A filled-in form looks the same for every project; a good brief looks like this specific project. |
| Three palettes of the same layout | Run the variation rubric (see `variation-and-risks.md`). Vary on three+ orthogonal axes. |
| Naming a licensed font without a fallback | Every named family pairs with a Google Fonts equivalent in the same line: `Söhne (fallback: Inter)`. |
| Forgetting the chat-vs-canvas summary instruction | Default in the template. Without it the recap gets buried on the canvas or skipped. |
| Cross-direction nav | State explicitly: "Direction A's nav routes only between Direction A's artboards." |
| Generic "be respectful" risk framing | Decompose into the 2–4 applicable sub-risks per `variation-and-risks.md`. |
| Listing reference apps without saying *what to take from each* | "Linear" is not a reference. "Linear's keyboard-first density and the muted-zinc background" is a reference. |
| Rebuilding all of `ui-brief` inside the Claude Design prompt | If `UI-CHALLENGE.md` exists, switch to with-brief mode and quote 5–8 sentences. Do not duplicate 300 lines. |
| Omitting the artboard math | Include the literal formula: "Build a single HTML artifact containing 3 directions × 4 pages = 12 artboards plus 1 title card = 13 frames total." |

## Composition With Other Skills

- **`ui-brief` first** when the project's design opinion has not been written down. Then run this skill to translate the brief into a Claude Design prompt. Reuses ~80% of the research.
- **`brainstorming` first** when the user is unsure on scope or variations (the two non-default questions). Don't guess on those; brainstorm them out.
- **`ui-ux-pro-max` parallel** for picking concrete palette / font / spacing / chart values during Step 2. The 13-category prompt should commit to specific values; ui-ux-pro-max supplies them. Run during the per-direction commitment step, before writing the prompt.
- **`frontend-design` does not pair** with this skill — that's the production-build path. After Claude Design produces mockups the user likes, the production build picks up `frontend-design` (or `frontend-agent`) using `ui-brief`'s output.

## Output File Convention

- **Self-contained.** No "see [other doc] for X" — if it must reference `UI-CHALLENGE.md`, summarize the 5–8 most relevant rules inline.
- **Project-specific.** No template placeholders unfilled. Every `[bracket]` resolves to a real value.
- **Decision-dense.** Every one of the 13 categories has a committed answer.
- **Paste-target friendly.** Code blocks for any literal content the canvas should render verbatim. No table syntax that breaks when copy-pasted.
- **Canvas-aware.** Every constraint from `canvas-constraints.md` appears as a default decision in the prompt.
