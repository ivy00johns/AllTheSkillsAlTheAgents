# Claude Design Canvas Constraints

The non-obvious limits of the Claude Design canvas runtime. Encode all of these as defaults in every prompt the skill produces.

1. **Licensed fonts don't load.** The canvas runtime can render Google Fonts and system fonts, not GT Sectra / Söhne / Tiempos / commercial families. **Always pair every named family with a Google Fonts fallback** in the typography section: `display: GT Sectra (fallback: Source Serif 4)`. Don't make the canvas guess.

2. **External image URLs don't fetch.** Real photos can't be linked in via URL. Every image slot must be either a captioned placeholder frame or an inline data URI. Default to placeholder frames.

3. **No animation runtime.** Hero rotators, motion, parallax, autoplay video — none of it runs on a canvas artboard. Indicate animation in caption text only ("hero rotates between 3 stills" written in mono caption), render a single still per direction.

4. **No real backend.** Forms, search, and CTAs render their visual state but submit nowhere. Hover and active states should still render correctly via inline styles.

5. **Inter-direction nav is scoped.** Direction A's nav must route only between Direction A's artboards. Cross-direction navigation belongs on the title card only, never inside an artboard. State this explicitly in the prompt's interactivity decision.

6. **Title card + artboard math.** Ship `N directions × M pages = X artboards` plus a title card = X+1 frames. Enumerate this in the "What To Ship" section so Claude Design lays out the canvas grid correctly.

7. **The chat-vs-canvas split.** After the canvas builds, Claude Design should output a brief in the chat (not on the canvas) summarizing what each direction leans into, open questions, and what was scoped out. Without this instruction the recap either gets buried on the canvas or skipped entirely. Include the instruction by default.
