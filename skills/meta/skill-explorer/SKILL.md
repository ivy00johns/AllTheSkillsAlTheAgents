---
name: skill-explorer
version: 1.0.1
description: |
  Help the user discover, recall, understand, and pick the right skill from the available toolkit.
  Use this skill whenever the user is trying to find a skill ("I forgot the name of the one that does X",
  "what was that skill called", "I had a skill for this"), asking what skills exist ("what skills do I
  have", "show me the catalog", "list all my skills", "what can you do here"), asking what a specific
  skill does ("what does X do", "explain the X skill", "tell me about Y"), asking how skills relate
  ("how do these connect", "what works with X", "what does orchestrator spawn"), OR asking for routing
  help ("which skill for this task", "what should I use to Y", "I want to do Z — which skill"). Also
  trigger when the user starts a session by reaching for orchestrator on something that isn't a
  multi-agent build, or asks any meta-question about the skill ecosystem itself. This is the entry
  point for "I don't know what to use" — it names the right skill and explains why; it does NOT
  invoke the skill on the user's behalf.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
composes_with: ["skill-review", "skill-writer"]
spawned_by: []
---

# Skill Explorer

The user has accumulated a large toolkit across the skill ecosystem plus plugin skills loaded into every session. Names blur together, descriptions overlap, and reaching for the wrong entry point (typically `orchestrator`) wastes a turn before getting redirected. This skill is the deliberate entry point for "what do I have / which one is right for this".

It answers four kinds of question:


| Mode        | Triggered by                                                         | Output                                                                                       |
| ----------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Recall**  | "what was that skill called", "I forgot the name of the one that..." | The skill name, in code, plus one sentence on what it does                                   |
| **Catalog** | "what skills do I have", "list all my skills", "show me the toolkit" | Grouped list, one line per skill                                                             |
| **Explain** | "what does X do", "tell me about X", "when should I use X"           | Purpose, when it triggers, what it produces, related skills                                  |
| **Route**   | "which skill for Y", "I want to do Z", "what should I use to..."     | One recommended skill (in code) + why; alternates only if the request is genuinely ambiguous |


## Core principle: name, don't invoke

The user said: *"first, names the skill."* When this skill recommends a tool, **stop after naming it** — do not silently invoke the recommended skill on the user's behalf. The user wants to see the recommendation, decide, and then trigger it themselves (either by typing the trigger phrase or via `/skill-name`). Auto-invoking would turn this into a meta-orchestrator and hide the routing decision.

The exception: if the user's intent is unambiguous AND they explicitly say "go ahead" or "use it" in the same message ("which skill writes UI briefs and use it for the dashboard rebuild"), pass through. Otherwise, name and stop.

## Data sources, in order

1. **Session-loaded descriptions** (free) — every skill available in the current session has its name + description already in your context. For most recall, catalog, and routing questions, this is enough. Don't read files just to confirm what you already see.
2. **SKILL.md frontmatter** — read when the user wants deeper detail (composes_with, spawned_by, owns), or when descriptions alone don't disambiguate. Use `head -30` or read with `limit: 30` — frontmatter is small.
3. **SKILL.md body** — read only for "explain in depth" questions or when the user is debugging why a skill triggered/didn't trigger.

For the Skill Madness repo specifically, skills live in:

```
skills/orchestrator/SKILL.md
skills/{contracts,git,meta,roles,workflows}/<skill-name>/SKILL.md
```

Plugin skills come from `~/.claude/plugins/` and are visible in your session context but not in the repo tree.

## Output format

Keep responses tight. The user is in a flow and needs a name fast.

### Recall ("I forgot the name of the one that...")

> You're thinking of `ui-brief` — generates opinionated, design-led briefs for new or rebuilt UIs.
> Trigger it with phrases like "write me a UI brief" or "design brief for X".

If you can't pin down a single skill, list 2–3 candidates with one line each.

### Catalog ("what skills do I have")

Group by category. One line per skill: `` `name` `` — what it does in <12 words.

```
## Orchestration
- `orchestrator` — coordinator for multi-agent contract-first builds

## Roles (implementation agents)
- `backend-agent` — APIs, business logic, data layer
- `frontend-agent` — UI, client state, presentation
- ...
```

If the user asks for "everything" including plugin skills, separate repo skills from plugin skills clearly so they know what's shipped from this repo vs added by plugins.

### Explain ("what does X do")

```
**`<name>`** (v<version>) — <one-line summary>

**Triggers on:** <2–3 sample trigger phrases from the description>
**Produces:** <output format / artifact>
**Composes with:** `<other>`, `<other>`
**Spawned by:** `<orchestrator>` (if applicable)

<one paragraph of detail>
```

Pull `version`, `composes_with`, `spawned_by` from frontmatter. Skip fields that are empty.

### Route ("which skill for...")

```
Use `<skill-name>` — <one sentence on why it fits>.
Trigger it with: "<sample phrase>" or `/<skill-name>`.
```

Add an alternate only if the request genuinely could go either way:

```
If you actually mean <reframe>, use `<other-skill>` instead.
```

### Compose ("how do these connect")

When the user asks how skills relate, render a small mermaid diagram or text tree from `composes_with` / `spawned_by`. Keep it to the skills they asked about plus one degree out — don't dump the whole graph.

## Routing rules of thumb

These are common confusions. Lean toward the right answer rather than reflecting the user's wording.

- **"I want to build X with multiple agents" / "swarm build" / "team build"** → `orchestrator`. This is its actual job.
- **"I just want to write/fix one thing"** → name the role skill directly (`backend-agent`, `frontend-agent`, etc.), not orchestrator. Orchestrator is for *coordinating* a team, not for any task that touches code.
- **"Design / rebuild / redesign a UI"** → `ui-brief` first to produce the brief, then `frontend-design` or `frontend-agent` to build from it.
- **"Make a plan from this research/PRD"** → `plan-builder`, then optionally `orchestrator` to execute the plan.
- **"Audit / review my skills"** → `skill-review` (`--scope=all` for bulk, `--scope=<name>` for deep dive).
- **"Create a new skill"** → `skill-writer`.
- **"Sync skills globally" / "link them"** → `sync-skills`.
- **"Commit / branch / PR"** → `git-commit`, `git-pr`, etc.
- **Plugin skills** (`superpowers:*`, `claude-mem:*`, `claude-obsidian:*`, `feature-dev:*`, etc.) — name them with their full namespace so the user can invoke them.

When orchestrator would be wrong, **say so explicitly**: "This isn't a multi-agent build, so `orchestrator` would bounce you. Use `<actual-skill>` instead."

## When NOT to invoke this skill

- The user already named a specific skill they want to run (`"use ui-brief for the dashboard"`) — just run it.
- The user is mid-task and asks a domain question that the active skill should handle.
- The user wants to *create* a new skill — that's `skill-writer`'s job. (You can mention `skill-writer` as a routing answer, but don't take it over.)
- The user wants to *audit* skills — that's `skill-review`. Same deal.

## Anti-patterns


| Anti-pattern                                       | Why it fails                                                                                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Auto-invoking the recommended skill                | The user said "names the skill" — auto-invoking hides the decision and creates a meta-orchestrator                                   |
| Reading every SKILL.md to answer "what do I have"  | Descriptions are already in your session context; reading 38 files burns tokens for nothing                                          |
| Recommending `orchestrator` for single-skill tasks | Orchestrator is for multi-agent coordination, not generic routing                                                                    |
| Listing 5 candidates when one fits                 | Picking is the job. If one skill clearly fits, name only that one                                                                    |
| Long preambles before the answer                   | The user wants the name. Lead with `` `skill-name` `` and explain after                                                              |
| Inventing skill names                              | If you don't see a skill that fits, say "no skill covers this — closest is X" or "this might warrant a new skill via `skill-writer`" |


## References

- `references/routing-table.md` — fuller table of common requests → recommended skill, used when the four rules of thumb above don't cover the case

