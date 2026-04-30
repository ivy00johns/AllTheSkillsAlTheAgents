---
name: settings-consolidator
version: 1.1.0
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
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob"]
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

## Permission Syntax Reference

Claude Code settings files use three Bash permission syntaxes. Understanding them is essential for correct collapsing.

**Space-wildcard:** `Bash(git *)` — matches `git` followed by a space and anything after it. This is the broadest form. It covers all subcommands and arguments.

**Colon-wildcard:** `Bash(git config:*)` — matches the exact command `git config` with any arguments. Claude Code generates this format when a user clicks "allow" on a specific command invocation.

**Literal (no wildcard):** `Bash(claude doctor)` — matches only that exact string. These are one-off approvals saved verbatim.

**Collapsing rule:** `Bash(X *)` (space-wildcard) safely subsumes `Bash(X Y*)`, `Bash(X Y:*)`, and `Bash(X:*)` (bare colon-wildcard). The space-wildcard is always strictly broader because it matches the command followed by a space and anything — which covers every possible subcommand and argument form. Do NOT collapse across unrelated base commands (`Bash(git *)` does not subsume `Bash(gh *)`).

**Non-Bash permissions** use glob patterns: `Read(**)` subsumes `Read(src/**)`.

## Workflow

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

Read each discovered file. Extract `permissions.allow[]` and `permissions.deny[]` arrays. Track which project each permission came from — you'll need this for flagging in Step 7.

If a file contains malformed JSON, skip it and report it as unreadable. Don't let one bad file block the whole run.

### Step 3: Deduplicate

Remove exact string duplicates across all files. Matching is case-sensitive because permissions are case-sensitive. Treat colon-wildcard and space-wildcard as distinct entries at this stage — collapsing happens next.

### Step 4: Superset Collapsing

Apply these rules in order:

1. **Space-wildcard absorbs more specific space-wildcards.** If `Bash(git *)` exists, drop `Bash(git status*)`, `Bash(git log*)`, etc. This includes flag-prefixed forms: `Bash(sqlite3 *)` absorbs `Bash(sqlite3 -*)` because `sqlite3 -` is just a more specific prefix of `sqlite3 `.

2. **Space-wildcard absorbs colon-wildcards for the same command.** If `Bash(git *)` exists, drop `Bash(git config:*)`, `Bash(git check-ignore:*)`. This also applies to bare colon-wildcards with no subcommand — `Bash(sqlite3 *)` absorbs `Bash(sqlite3:*)`, and `Bash(source *)` absorbs `Bash(source:*)`. The space-wildcard is always strictly broader regardless of whether the token is a command with subcommands or a shell builtin.

3. **Non-Bash glob collapsing.** `Read(**)` absorbs `Read(src/**)`, `Edit(**)` absorbs `Edit(components/**)`, etc.

4. **Do NOT collapse colon-wildcards into each other** unless one is clearly a prefix of the other. `Bash(git config:*)` and `Bash(git status:*)` are independent.

5. **Colon-to-space upgrade.** For any `Bash(cmd:*)` entry where no `Bash(cmd *)` exists yet, recommend upgrading to the space-wildcard form. Space-wildcards are strictly broader — `Bash(git *)` covers everything `Bash(git:*)` covers plus edge cases that colon-wildcards miss. This is especially important for autonomous sessions where a single missed command variant can interrupt an overnight build.

### Step 5: Detect Literal One-Offs

Entries with no `*` wildcard suffix and no `:*` suffix are literal one-off commands. Also flag entries that start with `#` — these are bash comments that got accidentally saved as permissions.

**Heuristic for literals:** Commonly useful standalone commands like `Bash(claude doctor)` or `Bash(claude --version)` are safe to merge. Entries that look accidental or project-specific — absolute paths, comments with `#`, project directory names — should be flagged for review rather than silently merged.

### Step 6: Categorize & Sort

Group the consolidated permissions into categories for the report. Each category with representative examples:

| Category | Examples |
|----------|---------|
| File Ops (Claude Tools) | Read(\*\*), Edit(\*\*), MultiEdit(\*\*), Write(\*\*), Glob(\*\*) |
| File Ops (Shell) | Bash(cp \*), Bash(mkdir \*), Bash(touch \*), Bash(ln \*) |
| Git & GitHub | Bash(git \*), Bash(gh \*) |
| Package Managers | Bash(npm \*), Bash(pip \*), Bash(cargo \*), Bash(bun \*), Bash(bunx \*), Bash(deno \*), Bash(uv \*), Bash(uvx \*), Bash(nvm \*), Bash(pyenv \*), Bash(rbenv \*), Bash(rvm \*) |
| Languages & Runtimes | Bash(python3 \*), Bash(node \*), Bash(ruby \*), Bash(go \*) |
| Build & Test | Bash(make \*), Bash(jest \*), Bash(pytest \*), Bash(vite \*) |
| Linters & Formatters | Bash(prettier \*), Bash(eslint \*), Bash(ruff \*) |
| Network | Bash(curl \*), Bash(wget \*), Bash(http \*), Bash(ssh \*) |
| Containers & Cloud | Bash(docker \*), Bash(kubectl \*), Bash(aws \*), Bash(vercel \*) |
| Databases | Bash(psql \*), Bash(sqlite3 \*), Bash(redis-cli \*) |
| System Utils | Bash(chmod \*), Bash(ps \*), Bash(df \*), Bash(systemctl \*) |
| Shell & Pipes | Bash(\* \| \*), Bash(\* && \*), Bash(bash \*), Bash(source \*), Bash(xargs \*), Bash(tee \*) |
| Editors & CLI Tools | Bash(code \*), Bash(cursor \*), Bash(claude \*), Bash(jq \*) |
| Crypto & Security | Bash(openssl \*), Bash(ssh-keygen \*), Bash(gpg \*) |
| Archive & Compression | Bash(tar \*), Bash(zip \*), Bash(gzip \*) |
| Terminal Multiplexers | Bash(tmux \*), Bash(screen \*) |
| macOS-Specific | Bash(defaults \*), Bash(networksetup \*), Bash(open \*), Bash(pbcopy\*) |
| Uncategorized | Anything that doesn't fit above |
| Project-Specific (flagged) | Bash(./ep \*), WebFetch to specific domains |

Sort entries alphabetically within each category.

### Step 7: Flag Project-Specific

Identify permissions that should NOT be merged into global settings. Apply these 7 rules:

1. **Absolute paths to specific projects.** Entries like `Bash(source /Users/you/myproject/.venv/bin/activate)` are meaningless outside that project.

2. **Named project scripts.** Relative paths referencing a specific file (e.g., `Bash(./ep help)`, `Bash(./run_tests.sh)`). Generic wildcards like `Bash(./scripts/*)` or `Bash(./bin/*)` are fine to merge because they work in any project with that directory structure.

3. **`Bash(./*)`  (dot-slash star).** This matches any executable in the current directory, which is effectively arbitrary code execution. Flag it for user confirmation rather than silently merging.

4. **Literal relative paths without wildcards.** Entries like `Bash(source .venv/bin/activate)` — even though `.venv/bin/activate` is conventional, a literal entry with no wildcard only makes sense in the project where it was approved.

5. **WebFetch/WebSearch to specific domains.** These are typically project-specific API endpoints or documentation sites.

6. **Bash comments accidentally saved.** Entries starting with `#` — these aren't real permissions.

7. **Hardcoded multi-line debug commands.** Entries containing multiple commands joined by spaces without shell operators.

**Rule for relative paths:** wildcards ending in `*` are generic and safe to merge (e.g., `./scripts/*`, `./bin/*`). Specific file references are project-specific and get flagged. The exception is `Bash(./*) ` — too broad, flag it.

### Step 8: Backup & Merge

1. **Timestamped backup.** Copy `~/.claude/settings.local.json` to `~/.claude/settings.local.json.bak.YYYY-MM-DD-HHMMSS`. Timestamping prevents overwriting previous backups on repeated runs.

2. **Read the existing global file.** If it doesn't exist yet, start with an empty JSON object.

3. **Preserve all top-level keys** that are not `"permissions"`. Don't hardcode field names — read the JSON, update only `permissions.allow` and `permissions.deny`, and leave everything else untouched.

4. **Merge allow[].** Add all consolidated non-flagged permissions to the existing allow list, deduplicating against what's already there.

5. **Merge deny[].** Add all consolidated deny rules, deduplicating against existing.

6. **Deny/allow conflicts.** If a permission appears in both allow and deny across different source files, include it in the deny list and exclude it from the allow list. Report the conflict. This is the safer interpretation of conflicting sources — when two projects disagree about whether something should be allowed, denying is the conservative choice.

7. **Write the updated file** with clean JSON formatting.

### Step 9: Report

Display a categorized summary showing exactly what happened:

```
Settings consolidated from N project files into ~/.claude/settings.local.json
Backup saved to ~/.claude/settings.local.json.bak.<timestamp>

MERGED (X unique patterns):
  File Ops - Claude Tools (N): Read(**), Edit(**), ...
  Git & GitHub (N): Bash(git *), Bash(gh *), ...
  Package Managers (N): ...
  ...

SUPERSET COLLAPSED (Y patterns absorbed):
  Bash(git *) absorbed: git status*, git config:*, ...
  Bash(npm *) absorbed: npm install:*, npm update:*, ...
  ...

LITERAL COMMANDS (kept or flagged):
  Kept: Bash(claude doctor), Bash(claude --version)
  Flagged: Bash(done), Bash(# Check thumbnail status ...)

FLAGGED (not merged — project-specific):
  Bash(./ep help:*) — from ProjectName
  Bash(source /Users/you/myproject/.venv/bin/activate:*) — from myproject
  ...

DENY/ALLOW CONFLICTS (deny wins):
  [listed if any]

DENY LIST (N rules):
  Bash(rm -rf /)
  ...
```

Truncate flagged literal entries to 80 characters in the display with a `...` suffix. The full entry is preserved in the merged output.

## Edge Cases

- **No project settings files found:** Report "no project settings found" and stop.
- **Only the global file exists:** Report "nothing to consolidate" and stop.
- **Deny/allow conflicts:** Deny wins — include in deny, exclude from allow, report the conflict.
- **Malformed JSON:** Skip the file, report it as unreadable. Don't block the whole run.
- **Plugin cache files:** Already excluded by the find command (`-not -path "*/.claude/plugins/*"`).
- **Global file in scan results:** Excluded — it's the merge target, not a source.
- **Repeated runs:** Timestamped backups prevent data loss. New permissions are deduped against existing global entries.
- **Empty allow/deny arrays:** Valid — the file simply contributes nothing.

## What This Skill Does NOT Do

- Does not modify project-level settings files — only writes to the global file.
- Does not remove existing global permissions. The only exception is deny/allow conflicts, where deny wins.
- Does not require any external tools or scripts — uses only Claude Code's built-in Read, Write, and Bash tools.
- Does not touch `settings.json` (non-local) — that file is for plugins and environment variables.
