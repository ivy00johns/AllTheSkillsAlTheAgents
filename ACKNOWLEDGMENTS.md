# Acknowledgments

Skill-Madness stands on the work of many. This file is a **living document**
that credits the upstream projects whose patterns, techniques, and code we
adapt — and it is **incomplete**. The orchestrator, contract-first
architecture, role-agents, and QA-gate all owe debts to prior projects that
are not yet catalogued here. Those credits will be back-filled.

What's currently documented below:

- **Recent additions (May 2026)** — patterns and skill content being adopted
from `mattpocock/skills` and `multica-ai/andrej-karpathy-skills` (which
itself distills observations from Andrej Karpathy). These attributions
cover the specific new skills and in-place edits introduced in the current
update cycle, not Skill-Madness's overall design.
- **Multi-tool installer pipeline** — the `scripts/convert.sh` /
`scripts/install.sh` machinery that lets one canonical `SKILL.md` install
into eleven AI coding tools. Adapted from `msitarzewski/agency-agents`.

If you find your work informed something in this repo and isn't credited here,
please open an issue — back-filling is active work.

---

# Recent additions (May 2026)

These attributions cover skills being added or patterns being adopted in the
current update cycle. They do not represent Skill-Madness's full lineage —
prior influences exist and will be credited as they're catalogued.

## mattpocock/skills — "Skills For Real Engineers"

- **Repository:** [https://github.com/mattpocock/skills](https://github.com/mattpocock/skills)
- **Author:** Matt Pocock ([@mattpocock](https://github.com/mattpocock))
- **License:** MIT
- **Copyright:** Copyright (c) 2026 Matt Pocock

We're adopting several patterns from Matt Pocock's "Skills For Real Engineers"
into the current update cycle. His discipline around progressive disclosure,
the way his skills consume each other's outputs as a coordinated pipeline,
and his editorial voice are useful references we're learning from.

The following Skill-Madness skills (introduced in the current update) are
derivative works of, or adopt patterns from, specific skills in
`mattpocock/skills`:


| Skill-Madness skill              | Adapted from                                    | What we took                                                                                                                                                                                                                                                                                                                                                                             |
| -------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workflows/diagnose-loop`        | `engineering/diagnose`                          | The six-phase structure with **Phase 1 — Build a feedback loop — IS the skill** as the structural insight. The ten ranked ways to construct a loop (failing test → curl → CLI diff → headless browser → trace replay → throwaway harness → fuzz → bisect → differential → HITL bash). The `[DEBUG-xxxx]` tagged-logs cleanup pattern. The falsifiable-hypothesis-with-prediction format. |
| `workflows/grill-me`             | `productivity/grill-me`                         | The three constraints that make grilling different from generic Q&A: one question at a time, recommend-then-ask, ask-code-not-user-when-possible. Depth-first design-tree walk.                                                                                                                                                                                                          |
| `workflows/maintain-context`     | `engineering/grill-with-docs`                   | The three-condition ADR gate (hard-to-reverse + surprising + real-tradeoff). The "CONTEXT.md is a glossary, NOT a spec" discipline. Inline-update-not-batch pattern. The `_Avoid_:` alias-list convention.                                                                                                                                                                               |
| `workflows/architecture-rescue`  | `engineering/improve-codebase-architecture`     | The deletion test (*"imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep."*). The two-adapter rule. The seven-term architectural glossary (Module / Interface / Depth / Seam / Adapter / Leverage / Locality) with forbidden synonyms. The deepening-opportunity lens.                         |
| `workflows/caveman`              | `productivity/caveman`                          | **Direct fork** with attribution. Same persistence rule, same drop/keep lists, same auto-clarity exception for destructive ops. Examples reused.                                                                                                                                                                                                                                         |
| `workflows/zoom-out`             | `engineering/zoom-out`                          | The seven-line zoom-out instruction and `disable-model-invocation: true` convention for explicit-only skills.                                                                                                                                                                                                                                                                            |
| `workflows/work-item-brief`      | `engineering/triage` (the Agent Brief contract) | The durability rules for agent-ready briefs: no file paths, no line numbers, mandatory `Key interfaces:` section, mandatory testable acceptance criteria, mandatory `Out of scope` list. The concept-level out-of-scope file pattern.                                                                                                                                                    |
| `in-progress/setup-project-skills` | `engineering/setup-matt-pocock-skills`        | The per-project bootstrap pattern: ask three questions one at a time with explainers, write `docs/agents/*.md` config files that other skills read, fail loudly with *"run /setup-project-skills first"* when config is missing.                                                                                                                                                        |


In addition to the per-skill adaptations above, the current update cycle is
adopting the following **structural and editorial patterns** from
`mattpocock/skills`, applied via Phase 4 of the update plan:

- **The 100-line rule** for SKILL.md, from `productivity/write-a-skill` —
*"Split into separate files when SKILL.md exceeds 100 lines."* Being applied
to ten long user-owned skills (`mermaid-charts`, `orchestrator`,
`playwright`, `repo-deep-dive`, etc).
- **Description style** — every description ends with `Use when [specific triggers]` followed by a quoted-phrase trigger block. Being applied to
skills with weak triggers.
- `**<what-to-do>` / `<supporting-info>` XML pattern** for separating the
imperative from the reference inside one SKILL.md. Visible in mattpocock's
`grill-with-docs`, `writing-fragments`, `writing-shape`, `writing-beats`.
Being introduced in `plan-builder`, `orchestrator`, `contract-author`.
- **Forbidden-form anti-pattern naming** — `"DO NOT…"` / `"Never…"` /
`"Forbidden:"`. Forbidden forms stick better than recommended forms.
- **"No file paths or line numbers in any durable artifact"** — discipline
stated 6+ times across mattpocock's collection. Being adopted as a
load-bearing rule in `work-item-brief`, `maintain-context`, and any skill
producing briefs / plans / ADRs.
- **The `setup-X-skills` bootstrap pattern** — convention-over-re-prompting:
one skill writes the per-repo configuration substrate that other skills
read; missing config produces a "run setup first" message instead of
re-asking. Being introduced as `setup-project-skills`.
- **Bucket-as-publication-gate** — `.claude-plugin/plugin.json` allowlists  
which skills ship; `archive/` and `in-progress/` exist on disk but aren't  
published. Being introduced alongside the new plugin manifest and updated  
sync-skills.

### MIT License (mattpocock/skills)

```
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## multica-ai/andrej-karpathy-skills

- **Repository:** [https://github.com/multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)
- **Author:** [@forrestchang](https://github.com/forrestchang) / Jiayuan ([@jiayuan_jy](https://x.com/jiayuan_jy))
- **Organization:** [Multica](https://github.com/multica-ai)
- **License:** MIT (declared in README and SKILL.md frontmatter)
- **Original observations:** Andrej Karpathy ([@karpathy](https://x.com/karpathy)) — see [the X/Twitter post](https://x.com/karpathy/status/2015883857489522876) that the repo derives from.

The karpathy-skills repository distills Andrej Karpathy's public observations
about LLM coding failure modes into four behavioral principles: *Think Before
Coding*, *Simplicity First*, *Surgical Changes*, and *Goal-Driven Execution*.
Its editorial moves — distillation, tradeoff-up-front framing, and the
imperative-to-verifiable-goal transformation — are patterns the current update
cycle is adopting into Skill-Madness.

Patterns being adopted in the current update cycle:

- **Opening tradeoff caveat** — every skill that has costs opens with a
blockquote naming when *not* to fire it. The karpathy-skills SKILL.md opens
with *"Tradeoff: These guidelines bias toward caution over speed. For
trivial tasks, use judgment."* Being introduced into `plan-builder`,
`contract-author`, `orchestrator`, `repo-deep-dive`, `ui-brief`, and
`qe-agent` via Phase 4 of the update plan.
- **Imperative → verifiable-goal transformation table** — the pattern of
reframing instructions as testable success criteria
(`"Add validation"` → `"Write tests for invalid inputs, then make them pass"`).
Being introduced as a meta-pattern in `plan-builder` and `work-item-brief`.
- **Bilingual distribution awareness** — the karpathy-skills repo ships
English + Simplified Chinese READMEs. If Skill-Madness ever publishes more
broadly, this is a useful reference.

Per the karpathy-skills README, attribution flows from Andrej Karpathy as the
originator of the observations. We thank both Karpathy for the original
analysis and the Multica team for the work of distillation and packaging.

### MIT License (declared)

The karpathy-skills repository declares MIT in its README and in the
`SKILL.md` frontmatter `license: MIT` field. No standalone `LICENSE` file is
present in the upstream repo at the time of writing. Our use is consistent
with attribution-and-share requirements; the originator's name and source URL
are preserved here and in the relevant Skill-Madness skills (`workflows/caveman`
is the most direct adoption; other adoptions are pattern-level rather than
verbatim).

---

# Multi-tool installer pipeline

## msitarzewski/agency-agents

- **Repository:** [https://github.com/msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
- **License:** MIT
- **Copyright:** Copyright (c) 2025 AgentLand Contributors

This project's multi-tool installer (`scripts/convert.sh`, `scripts/install.sh`,
and helpers under `scripts/lib/`) was informed by, and in places adapts code
from, agency-agents. The 11-tool installer pattern (Claude Code, Copilot,
Antigravity, Gemini CLI, OpenCode, OpenClaw, Cursor, Aider, Windsurf, Qwen,
Kimi) and the canonical-source → per-tool-converter → installer pipeline
architecture originated there. The following pieces in this repository were
adapted directly and remain close to the originals:

- The six `detect_<tool>()` one-liners in `scripts/install.sh` that probe for
each tool's CLI or config directory.
- The terminal-redraw helper used in the interactive selection UI of
`scripts/install.sh`.
- The `get_body()` awk script for stripping YAML frontmatter, in
`scripts/lib/frontmatter.sh`.
- The `slugify()` pipeline (lowercase → non-alphanumeric to hyphen → collapse →
trim) in `scripts/lib/slug.sh`.
- The split of an agent body into "soul" (persona/rules) and "agents"
(capabilities) sections in `convert_openclaw()`, including the keyword set
used to classify section headers.

Other parts of the installer — the Python YAML implementation of `get_field()`,
the `inline_references` mechanism, the `lib/{platform,term,frontmatter}.sh`
helpers, the lint script, and most per-tool converter bodies — are independent
implementations.

### MIT License (agency-agents)

```
MIT License

Copyright (c) 2025 AgentLand Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

