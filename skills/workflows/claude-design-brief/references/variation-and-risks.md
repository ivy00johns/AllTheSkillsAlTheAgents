# Variation Rubric and Risk Decomposition

The two highest-leverage discipline pieces in any Claude Design prompt: making directions actually distinct, and decomposing the risk section into concrete sub-risks.

## Making N Variations Actually Distinct

The biggest failure mode after question-loops: three "directions" that are the same layout in three palettes. To pass the bar, directions must vary on **at least three orthogonal axes**, not just color:

| Axis | Variation examples |
|---|---|
| **Layout system** | Single-column editorial · split 60/40 · asymmetric broadsheet · grid-bento · stacked cards |
| **Typographic register** | Display serif gravity · monospace dossier · oversized italic broadsheet · neo-grotesk minimalism · slab editorial |
| **Image treatment** | Full-bleed cinematic stills · half-bleed with metadata panel · asymmetric photographic crops with bleed-off · iconographic illustrations · pure typographic (no photo) |
| **Color discipline** | Cream + navy editorial · blackout + signal accent · bone + olive photojournalist · monochrome with one chromatic accent |
| **Density** | Generous whitespace · file-document density · marketing-like sparse · operator-tool dense |

Pick three or four axes; commit each direction to a different position on each axis. The Sovereign Sampson reference example uses: layout (editorial column / dossier split / broadsheet asymmetric) × register (serif / mono / italic display) × treatment (full-bleed / half-bleed-metadata / asymmetric-bleed-off) × color (cream-navy / blackout-signal / bone-olive). Three directions, four axes, twelve genuinely distinct moves.

If the directions feel like "the same thing in three palettes," go back to this rubric.

For per-direction worked examples, see `references/direction-examples/safe.md`, `bold.md`, and `experimental.md`.

## Decomposing the Risks / Sensitive Identity Section

Risk framing is the hardest section to fill in well. Decompose into the sub-risks that apply to the project, then state the framing rule for each:

| Sub-risk | When it applies | Framing rule shape |
|---|---|---|
| **Identity / partisanship** | Project surfaces a partisan or polarizing identity (political, religious, generational) | Acknowledge once in plain prose as a credibility lever; never in color or iconography |
| **Memorial / sensitive content** | Site honors deceased, missing, or harmed people | Black-and-white treatment, names only with explicit consent, generous whitespace |
| **Contested credentials / claims** | Self-reported claims that are defensible but unverified | Frame in subject's own voice, not as third-person fact; reconcile inconsistent numbers to single source of truth |
| **Audience conflict** | Multiple stakeholder groups with conflicting taste (e.g., GOP staffers + Substack readers) | State which audience the visual register optimizes for; flag others as secondary |
| **Geographic / cultural framing** | Diaspora communities, conflict zones, contested territories | Use locally-recognized place names; consult subject before publishing geographic specifics |
| **Privacy / opsec** | Subject is in or near active operations | Default to caution: blur faces, avoid current-location precision, redact unit details unless cleared |

Most projects need 2–4 of these. Pick what applies and write a one-paragraph framing rule per sub-risk. Don't write a generic "be respectful" — name the specific lever.
