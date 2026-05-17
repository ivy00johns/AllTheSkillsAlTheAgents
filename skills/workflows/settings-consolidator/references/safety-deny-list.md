# Safety, Deny/Allow Conflicts, and Edge Cases

Operational rules for merging permissions safely: how to handle conflicting allow/deny decisions across project files, how to back up, and what edge cases to expect.

## Backup & Merge Procedure

1. **Timestamped backup.** Copy `~/.claude/settings.local.json` to `~/.claude/settings.local.json.bak.YYYY-MM-DD-HHMMSS`. Timestamping prevents overwriting previous backups on repeated runs.

2. **Read the existing global file.** If it doesn't exist yet, start with an empty JSON object.

3. **Preserve all top-level keys** that are not `"permissions"`. Don't hardcode field names — read the JSON, update only `permissions.allow` and `permissions.deny`, and leave everything else untouched.

4. **Merge `allow[]`.** Add all consolidated non-flagged permissions to the existing allow list, deduplicating against what's already there.

5. **Merge `deny[]`.** Add all consolidated deny rules, deduplicating against existing.

6. **Deny/allow conflicts.** If a permission appears in both allow and deny across different source files, include it in the deny list and exclude it from the allow list. Report the conflict. This is the safer interpretation of conflicting sources — when two projects disagree about whether something should be allowed, denying is the conservative choice.

7. **Write the updated file** with clean JSON formatting.

## Report Format

Display a categorized summary showing exactly what happened:

```text
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
