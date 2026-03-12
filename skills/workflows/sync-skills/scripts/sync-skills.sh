#!/usr/bin/env bash
set -euo pipefail

# Sync skills between the TAIS mono-repo and global tool locations.
# Supports Cursor (~/.cursor/skills-cursor/) and Claude Code (~/.claude/skills/tais/).

MONO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
MONO_SKILLS="$MONO_ROOT/.agents/skills"

CURSOR_SKILLS="$HOME/.cursor/skills-cursor"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_TAIS="$CLAUDE_SKILLS/tais"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [skill-name ...]

Sync skills between this mono-repo and global locations for Cursor and Claude Code.

Directions (at least one required):
  --to-cursor       Copy from mono-repo to ~/.cursor/skills-cursor/
  --to-claude       Copy from mono-repo to ~/.claude/skills/tais/
  --from-cursor     Copy from ~/.cursor/skills-cursor/ to mono-repo
  --from-claude     Copy from ~/.claude/skills/tais/ to mono-repo
  --to-all          Shorthand for --to-cursor --to-claude
  --from-all        Shorthand for --from-cursor --from-claude

Options:
  --dry-run         Show what would be copied without doing it
  --list            Show skills in all locations and exit
  --all             Sync all skills (default if no skill names given)
  --force           Overwrite without prompting (default behavior; flag for clarity)
  -h, --help        Show this help

Examples:
  $(basename "$0") --to-all                              # Push all mono-repo skills everywhere
  $(basename "$0") --to-cursor cross-service-changes     # Push one skill to Cursor
  $(basename "$0") --from-claude orchestrator             # Pull one Claude skill into mono-repo
  $(basename "$0") --list                                 # See what's where
  $(basename "$0") --dry-run --to-all                     # Preview what would be copied
EOF
  exit 0
}

TO_CURSOR=""
TO_CLAUDE=""
FROM_CURSOR=""
FROM_CLAUDE=""
DRY_RUN=""
LIST_MODE=""
SKILLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --to-cursor)   TO_CURSOR="yes"; shift ;;
    --to-claude)   TO_CLAUDE="yes"; shift ;;
    --from-cursor) FROM_CURSOR="yes"; shift ;;
    --from-claude) FROM_CLAUDE="yes"; shift ;;
    --to-all)      TO_CURSOR="yes"; TO_CLAUDE="yes"; shift ;;
    --from-all)    FROM_CURSOR="yes"; FROM_CLAUDE="yes"; shift ;;
    --dry-run)     DRY_RUN="yes"; shift ;;
    --list)        LIST_MODE="yes"; shift ;;
    --all)         shift ;;  # handled below (default behavior)
    --force)       shift ;;  # always overwrites; flag exists for readability
    -h|--help)     usage ;;
    -*)            echo "Unknown option: $1"; usage ;;
    *)             SKILLS+=("$1"); shift ;;
  esac
done

# --- List mode ---

list_skills_in() {
  local dir="$1" label="$2"
  echo ""
  echo "=== $label ($dir) ==="
  if [[ ! -d "$dir" ]]; then
    echo "  (directory does not exist)"
    return
  fi
  local found=0
  for skill_dir in "$dir"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    # Skip non-skill directories (no SKILL.md)
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      local desc=""
      desc=$(grep -m1 '^description:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^description: *//')
      # Skip multiline YAML indicators (> or |) -- show name from SKILL.md instead
      if [[ "$desc" == ">" || "$desc" == "|" || -z "$desc" ]]; then
        desc=$(grep -m1 '^name:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^name: *//')
      fi
      desc="${desc:0:80}"
      printf "  %-30s %s\n" "$name" "$desc"
      found=$((found + 1))
    fi
  done
  # Also check one level deeper for categorized skills (Claude Code)
  for cat_dir in "$dir"/*/; do
    [[ -d "$cat_dir" ]] || continue
    for skill_dir in "$cat_dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      if [[ -f "$skill_dir/SKILL.md" ]]; then
        local cat_name name desc
        cat_name="$(basename "$cat_dir")"
        name="$(basename "$skill_dir")"
        desc=$(grep -m1 '^description:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^description: *//')
        if [[ "$desc" == ">" || "$desc" == "|" || -z "$desc" ]]; then
          desc=$(grep -m1 '^name:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^name: *//')
        fi
        desc="${desc:0:80}"
        printf "  %-30s %s\n" "$cat_name/$name" "$desc"
        found=$((found + 1))
      fi
    done
  done
  if [[ $found -eq 0 ]]; then
    echo "  (no skills found)"
  fi
}

if [[ "$LIST_MODE" == "yes" ]]; then
  list_skills_in "$MONO_SKILLS" "Mono-repo"
  list_skills_in "$CURSOR_SKILLS" "Cursor"
  list_skills_in "$CLAUDE_SKILLS" "Claude Code"
  exit 0
fi

# --- Validate direction ---

if [[ -z "$TO_CURSOR" && -z "$TO_CLAUDE" && -z "$FROM_CURSOR" && -z "$FROM_CLAUDE" ]]; then
  echo "Error: specify at least one direction (--to-cursor, --to-claude, --from-cursor, --from-claude, --to-all, --from-all)."
  echo "Run with -h for help."
  exit 1
fi

# --- Sync functions ---

copy_skill() {
  local src="$1" dst="$2" name="$3" label="$4"

  if [[ ! -d "$src" ]]; then
    echo "  [$name] Source not found: $src -- skipping"
    return
  fi

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  [$name] No SKILL.md in $src -- skipping (not a skill)"
    return
  fi

  if [[ "$DRY_RUN" == "yes" ]]; then
    echo "  [dry-run] Would copy: $src -> $dst"
    return
  fi

  mkdir -p "$dst"
  # Use rsync if available for clean directory sync, fall back to cp
  if command -v rsync &>/dev/null; then
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    cp -R "$src" "$dst"
  fi
  echo "  [$name] Synced -> $label"
}

sync_to() {
  local target_base="$1" label="$2" source_base="$3"

  echo ""
  echo "--- Syncing to $label ---"

  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    # Sync all skills from source
    for skill_dir in "$source_base"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      [[ "$name" == "sync-skills" ]] && continue  # don't copy ourselves
      [[ -f "$skill_dir/SKILL.md" ]] || continue
      copy_skill "$skill_dir" "$target_base/$name" "$name" "$label"
    done
  else
    for name in "${SKILLS[@]}"; do
      copy_skill "$source_base/$name" "$target_base/$name" "$name" "$label"
    done
  fi
}

sync_from_cursor() {
  echo ""
  echo "--- Pulling from Cursor ---"

  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    for skill_dir in "$CURSOR_SKILLS"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      [[ -f "$skill_dir/SKILL.md" ]] || continue
      copy_skill "$skill_dir" "$MONO_SKILLS/$name" "$name" "mono-repo"
    done
  else
    for name in "${SKILLS[@]}"; do
      copy_skill "$CURSOR_SKILLS/$name" "$MONO_SKILLS/$name" "$name" "mono-repo"
    done
  fi
}

# Resolve a Claude Code skill by name, searching tais/ then root then categories
find_claude_skill() {
  local name="$1"
  for candidate in "$CLAUDE_TAIS/$name" "$CLAUDE_SKILLS/$name"; do
    if [[ -d "$candidate" && -f "$candidate/SKILL.md" ]]; then
      echo "$candidate"
      return
    fi
  done
  # Search one level of category dirs (contracts/, roles/, meta/, etc.)
  for cat_dir in "$CLAUDE_SKILLS"/*/; do
    [[ -d "$cat_dir" ]] || continue
    if [[ -d "$cat_dir/$name" && -f "$cat_dir/$name/SKILL.md" ]]; then
      echo "$cat_dir/$name"
      return
    fi
  done
}

sync_from_claude() {
  echo ""
  echo "--- Pulling from Claude Code ---"

  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    # Scan tais/ skills, then root-level skills, then category skills
    for skill_dir in "$CLAUDE_TAIS"/*/  "$CLAUDE_SKILLS"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      if [[ -f "$skill_dir/SKILL.md" ]]; then
        copy_skill "$skill_dir" "$MONO_SKILLS/$name" "$name" "mono-repo"
      else
        # Check if this is a category directory with skills inside
        for sub_dir in "$skill_dir"/*/; do
          [[ -d "$sub_dir" ]] || continue
          local sub_name
          sub_name="$(basename "$sub_dir")"
          [[ -f "$sub_dir/SKILL.md" ]] || continue
          copy_skill "$sub_dir" "$MONO_SKILLS/$sub_name" "$sub_name" "mono-repo"
        done
      fi
    done
  else
    for name in "${SKILLS[@]}"; do
      local src
      src=$(find_claude_skill "$name")
      if [[ -n "$src" ]]; then
        copy_skill "$src" "$MONO_SKILLS/$name" "$name" "mono-repo"
      else
        echo "  [$name] Not found in Claude Code skills -- skipping"
      fi
    done
  fi
}

# --- Execute ---

[[ "$TO_CURSOR" == "yes" ]]   && sync_to "$CURSOR_SKILLS" "Cursor" "$MONO_SKILLS"
[[ "$TO_CLAUDE" == "yes" ]]   && sync_to "$CLAUDE_TAIS" "Claude Code (tais/)" "$MONO_SKILLS"
[[ "$FROM_CURSOR" == "yes" ]] && sync_from_cursor
[[ "$FROM_CLAUDE" == "yes" ]] && sync_from_claude

echo ""
echo "Done."
