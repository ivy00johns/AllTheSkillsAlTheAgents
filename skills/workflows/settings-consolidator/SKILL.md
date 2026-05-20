---
name: settings-consolidator
version: 1.2.0
description: >
  Scan all .claude/settings.local.json files across the user's home directory,
  deduplicate permissions, collapse supersets, and merge everything into the
  global ~/.claude/settings.local.json with a categorized report. Also bootstraps
  comprehensive permissions for autonomous/unattended sessions using a 350+ command
  baseline with shell operators, Claude tools, and safety deny list. Use this skill
  whenever the user mentions consolidating settings, merging permissions, scanning
  settings, deduping permissions, compiling settings, says they're tired of
  approving commands, wants to set up permissions for overnight builds, mentions
  "stop prompting me", "bootstrap permissions", "autonomous mode", "I want to go
  to sleep and let this run", "unattended session", or asks about reducing permission
  prompts. Also trigger when users want to upgrade colon-wildcards to space-wildcards
  or manage Claude Code permissions across projects.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: ["settings.local.json"]
  shared_read: ["~/.claude/", "**/.claude/"]
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
composes_with: ["sync-skills"]
spawned_by: []
---

# Settings Consolidator

Scan every `.claude/settings.local.json` across your home directory, deduplicate the permissions, collapse supersets, and merge the result into your global `~/.claude/settings.local.json`. This saves you from clicking "allow" on the same commands over and over as you move between projects. The output is a categorized report showing exactly what was merged, what was collapsed, and what was flagged as project-specific.

## Bootstrap Mode

When the user wants autonomous sessions — "stop prompting me", "I want to go to sleep and let this run", "bootstrap permissions", "set up for unattended builds", or "I keep getting permission prompts" — use this workflow instead of (or before) the consolidation workflow.

### Why Sessions Get Interrupted

Permission prompts in long-running sessions come from three gaps, in order of how often they bite:

1. **Missing shell operators.** Commands like `git log --oneline | head -5` or `npm test && npm run build` use pipes, chains, and redirects. Without `Bash(* | *)`, `Bash(* && *)`, `Bash(* > *)`, etc., every compound command prompts. This is the #1 cause of interruptions and the one most people miss entirely.

2. **Missing Claude tool permissions.** Spawning subagents (`Agent(*)`), editing files (`Edit(**)`), entering plan mode (`EnterPlanMode(*)`), using worktrees (`EnterWorktree(*)`), or managing tasks (`Task(**)`) all need explicit permissions. Without them, multi-agent and orchestrated workflows stall.

3. **Colon-wildcard gaps.** `Bash(git:*)` is narrower than `Bash(git *)`. Claude Code generates colon-wildcards when a user clicks "allow" on a specific invocation, but space-wildcards are strictly broader and catch command variations that colon-wildcards miss. Always prefer `Bash(cmd *)` over `Bash(cmd:*)`.

### Bootstrap Workflow

1. **Back up.** Copy `~/.claude/settings.local.json` to `~/.claude/settings.local.json.bak.YYYY-MM-DD-HHMMSS`.

2. **Load the baseline.** Read `references/autonomous-permissions.json` — a comprehensive template with ~350 pre-approved commands (all using space-wildcards), all shell operators, all Claude Code tool permissions, and a safety deny list.

3. **Merge.** Add baseline permissions to the existing global settings, deduplicating against what's already there. Don't remove existing permissions — the baseline is additive.

4. **Upgrade colon-wildcards.** Scan the merged result for `Bash(cmd:*)` entries. For each one, if a `Bash(cmd *)` (space-wildcard) entry exists in the baseline or the merged result, drop the colon-wildcard — the space-wildcard already covers it.

5. **Add MCP permissions.** Check `~/.claude/settings.json` for `enabledPlugins`. For each enabled plugin, add its tool permissions. Common patterns:
   - Playwright: all `mcp__plugin_playwright_playwright__browser_*` tools
   - Other MCP servers: `mcp__<server>__<tool>` format

6. **Report.** Show a summary: how many permissions added, how many colon-wildcards upgraded, the deny list, and any MCP tools added.

After bootstrapping, optionally run the consolidation workflow below to merge in any project-specific permissions on top.

## Permission Syntax and Categorization

Claude Code settings use three Bash permission syntaxes (space-wildcard, colon-wildcard, literal) with strict collapsing rules. The category scheme used in the report (File Ops, Git & GitHub, Package Managers, Network, etc.) and the rules for collapsing supersets, detecting literal one-offs, and flagging project-specific entries live in `references/permission-categories.md`.

## Consolidation Workflow

### Step 1: Scan

Run:

```bash
find ~ -name "settings.local.json" -path "*/.claude/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/.claude/plugins/*" \
  -not -path "*/Library/*" \
  -not -path "*/.Trash/*"
```

Exclude the global file (`~/.claude/settings.local.json`) from the results — it is the merge target, not a source. Report how many project files were found and list their paths.

If no project files are found, report "no project settings found" and stop. If only the global file exists, report "nothing to consolidate" and stop.

### Step 2: Read & Parse

Read each discovered file. Extract `permissions.allow[]` and `permissions.deny[]` arrays. Track which project each permission came from — you'll need this for flagging later.

If a file contains malformed JSON, skip it and report it as unreadable. Don't let one bad file block the whole run.

### Step 3: Deduplicate

Remove exact string duplicates across all files. Matching is case-sensitive because permissions are case-sensitive. Treat colon-wildcard and space-wildcard as distinct entries at this stage — collapsing happens next.

### Step 4: Collapse, Detect Literals, Flag Project-Specific

See `references/permission-categories.md` for the full rule sets:

- Superset collapsing (5 rules, applied in order)
- Literal one-off detection (heuristic for when to keep vs flag)
- Project-specific flagging (7 rules, including absolute paths, project scripts, `Bash(./*)`, WebFetch domains, accidental `#` comments)

### Step 5: Categorize & Sort

Group consolidated permissions into the categories listed in `references/permission-categories.md`. Sort entries alphabetically within each category.

### Step 6: Backup, Merge, Report

The merge procedure (backup naming, preserving top-level keys, handling deny/allow conflicts where deny wins) and the exact report format live in `references/safety-deny-list.md`. That file also covers edge cases (no project files, malformed JSON, repeated runs) and what this skill explicitly does NOT do.

## Reference Files

- `references/autonomous-permissions.json` — 350+ command baseline for bootstrap mode (space-wildcards, shell operators, Claude tools, safety deny list)
- `references/permission-categories.md` — three syntaxes, collapsing rules, category table, literal/project-specific detection
- `references/safety-deny-list.md` — backup/merge procedure, report format, deny/allow conflict handling, edge cases, scope boundaries
