# Experimental Direction Examples

The "swing-for-the-fence" direction — the one the user probably won't ship but needs to see, because it stretches the canvas. Use this slot when one of N directions exists to surface a vocabulary the other two would never touch.

## When the Experimental Direction Lives Here

An "experimental" direction means: it commits to a pattern that's unusual enough that the user has to actively reject it; it can't be approved by default. Specifically:

- **Layout:** stacked cards with brutal section breaks, broadsheet asymmetric with bleed-off, or pure-typographic (no photos at all)
- **Typographic register:** oversized italic broadsheet, decorative display face paired against a stripped mono, or all-caps editorial
- **Image treatment:** iconographic illustrations, or photographic crops bleeding off the frame
- **Color discipline:** bone + olive photojournalist, monochrome with one chromatic accent, or a non-obvious hue pairing
- **Density:** sparse marketing register, or the inverse — operator-tool overload

The experimental direction's job is to show the user a pattern they haven't seen yet from this project. If they reject it, that's useful data. If they pick it up, you've found the moat.

## Worked Sample — Sovereign Sampson "Bone & Olive"

```text
Direction C: Bone & Olive
Palette: bone (#EFE8DC) + deep olive (#3D4A2B) + faded brick accent (#9C4B3A)
Display: Tiempos Headline (fallback: Source Serif 4 700 italic)
Body: Tiempos Text (fallback: Source Serif 4 400)
Mono: GT America Mono (fallback: JetBrains Mono 400) — used only in field notes margin
Layout: asymmetric broadsheet — photos crop off the frame at unpredictable angles; text columns reflow around the bleed
Hero: photographic crop bleeding off the right edge with caption pinned to bottom-left
Density: photojournalist — heavy but not packed; whitespace used as emphasis, not decoration
Live elements: none on canvas; production version would have a "field notes" rotating excerpt — mark "static still" in caption
CTAs: no sticky donate; soft text-link "support" in the colophon at the bottom of each artboard
Photos: real photojournalism photos, placeholder frames with caption captions
Tone reference apps: Magnum Photos + the National Geographic editorial-essay register
```

## What Makes the Experimental Direction Distinct

The variation rubric requires direction-to-direction differences on at least three orthogonal axes. The experimental direction's "axis positions":

- **Layout axis:** asymmetric broadsheet with bleed-off (the position neither safe nor bold uses)
- **Register axis:** italic display + serif body (a register the other two avoid)
- **Treatment axis:** photographic crops bleeding off (not half-bleed, not full-bleed-with-overlay)
- **Color axis:** bone + olive (a palette the other two would never choose)

The point of the experimental slot is to put every axis on a position the user actively has to opt out of. That forces a conscious decision — and that conscious rejection often surfaces the *real* design opinion the user holds. See `references/direction-examples/safe.md` and `references/direction-examples/bold.md` for the other two poles.
