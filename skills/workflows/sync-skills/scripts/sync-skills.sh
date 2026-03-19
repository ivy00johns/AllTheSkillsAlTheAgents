#!/usr/bin/env bash
set -euo pipefail

# Sync skills between this repo and global locations for Claude Code and Cursor.
# Default mode is symlink; use --copy for file copies.

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
REPO_SKILLS="$REPO_ROOT/skills"

CLAUDE_SKILLS="$HOME/.claude/skills"
CURSOR_SKILLS="$HOME/.cursor/skills-cursor"

# Skill categories in the repo (auto-discovered)
discover_categories() {
  local cats=()
  for dir in "$REPO_SKILLS"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name="$(basename "$dir")"
    cats+=("$name")
  done
  echo "${cats[@]+"${cats[@]}"}"
}

# Discover individual skills within all categories
# Returns lines of "category/skill-name" where skill-name is a subdirectory with SKILL.md
# For categories that ARE skills themselves (SKILL.md at category root), returns "category/."
discover_skills() {
  for cat_dir in "$REPO_SKILLS"/*/; do
    [[ -d "$cat_dir" ]] || continue
    local cat
    cat="$(basename "$cat_dir")"

    # Check for skill subdirectories (e.g., meta/skill-audit/SKILL.md)
    local has_subdirs=""
    for skill_dir in "$cat_dir"/*/; do
      [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
      local skill
      skill="$(basename "$skill_dir")"
      echo "$cat/$skill"
      has_subdirs="yes"
    done

    # If no skill subdirs but category itself has SKILL.md, treat category as the skill
    if [[ -z "$has_subdirs" && -f "$cat_dir/SKILL.md" ]]; then
      echo "$cat/."
    fi
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [category-or-skill-name ...]

Sync skills between this repo and global locations using symlinks (default) or copies.

Modes:
  --link            Symlink repo categories to global locations (default for --to-*)
  --copy            Copy files instead of symlinking
  --unlink          Remove symlinks pointing to this repo

Directions (at least one required, unless --status):
  --to-cursor       Target ~/.cursor/skills-cursor/
  --to-claude       Target ~/.claude/skills/
  --to-all          Target both
  --from-cursor     Pull from Cursor into repo
  --from-claude     Pull from Claude Code into repo
  --from-all        Pull from both

Options:
  --status          Show link/copy/missing status for all locations
  --clean           Remove broken symlinks from global locations
  --dry-run         Preview without making changes
  -h, --help        Show this help

Examples:
  $(basename "$0") --link --to-all                    # Symlink all categories everywhere
  $(basename "$0") --status                           # What's linked, copied, missing?
  $(basename "$0") --clean                            # Remove broken symlinks
  $(basename "$0") --copy --to-claude meta            # Copy just meta/ to Claude Code
  $(basename "$0") --unlink --to-all                  # Remove all symlinks
  $(basename "$0") --from-cursor shell                # Pull a Cursor skill into repo
  $(basename "$0") --dry-run --link --to-all          # Preview linking
EOF
  exit 0
}

# --- Parse args ---

MODE=""  # link, copy, unlink
TO_CURSOR="" TO_CLAUDE=""
FROM_CURSOR="" FROM_CLAUDE=""
DRY_RUN="" STATUS_MODE="" CLEAN_MODE=""
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link)        MODE="link"; shift ;;
    --copy)        MODE="copy"; shift ;;
    --unlink)      MODE="unlink"; shift ;;
    --to-cursor)   TO_CURSOR="yes"; shift ;;
    --to-claude)   TO_CLAUDE="yes"; shift ;;
    --to-all)      TO_CURSOR="yes"; TO_CLAUDE="yes"; shift ;;
    --from-cursor) FROM_CURSOR="yes"; shift ;;
    --from-claude) FROM_CLAUDE="yes"; shift ;;
    --from-all)    FROM_CURSOR="yes"; FROM_CLAUDE="yes"; shift ;;
    --status)      STATUS_MODE="yes"; shift ;;
    --clean)       CLEAN_MODE="yes"; shift ;;
    --dry-run)     DRY_RUN="yes"; shift ;;
    -h|--help)     usage ;;
    -*)            echo "Unknown option: $1" >&2; usage ;;
    *)             TARGETS+=("$1"); shift ;;
  esac
done

# Default mode for --to-* is link
if [[ -z "$MODE" && ( -n "$TO_CURSOR" || -n "$TO_CLAUDE" ) ]]; then
  MODE="link"
fi

# --- Status mode ---

# Status for Claude Code (flattened — individual skills)
check_status_claude() {
  local global_dir="$1"
  echo ""
  echo "=== Claude Code ($global_dir) — flattened ==="

  if [[ ! -d "$global_dir" ]]; then
    echo "  (directory does not exist)"
    return
  fi

  # Build list of expected skill names
  local skills
  skills=($(discover_skills))
  local skill_names=()
  local broken=0

  for entry in "${skills[@]}"; do
    local cat="${entry%%/*}"
    local skill="${entry##*/}"
    local name target expected_src display_cat
    if [[ "$skill" == "." ]]; then
      name="$cat"; target="$global_dir/$cat"; expected_src="$REPO_SKILLS/$cat"; display_cat="$cat"
    else
      name="$skill"; target="$global_dir/$skill"; expected_src="$REPO_SKILLS/$cat/$skill"; display_cat="$cat/$skill"
    fi
    skill_names+=("$name")

    if [[ -L "$target" ]]; then
      local link_target
      link_target="$(readlink "$target")"
      if [[ ! -e "$target" ]]; then
        printf "  %-30s ✗ BROKEN → %s\n" "$name" "$link_target"
        broken=$((broken + 1))
      elif [[ "$link_target" == "$expected_src" || "$link_target" == "${expected_src}/" ]]; then
        printf "  %-30s ✓ linked → %s\n" "$name" "$display_cat"
      else
        printf "  %-30s ⚠ linked → %s (unexpected)\n" "$name" "$link_target"
      fi
    elif [[ -d "$target" ]]; then
      printf "  %-30s ● copied (independent)\n" "$name"
    else
      printf "  %-30s ○ not present\n" "$name"
    fi
  done

  # Check for old category-level symlinks that should be cleaned up
  local categories
  categories=($(discover_categories))
  for cat in "${categories[@]}"; do
    # Skip if this category is also a skill name (e.g., orchestrator)
    local is_skill=""
    for s in "${skill_names[@]}"; do
      [[ "$cat" == "$s" ]] && is_skill="yes" && break
    done
    [[ "$is_skill" == "yes" ]] && continue

    local target="$global_dir/$cat"
    if [[ -L "$target" || -d "$target" ]]; then
      printf "  %-30s ⚠ old category-level entry (should remove)\n" "$cat/"
    fi
  done

  # Check non-repo items
  for item in "$global_dir"/*/; do
    [[ -d "$item" || -L "${item%/}" ]] || continue
    local name
    name="$(basename "$item")"
    local is_repo=""
    for s in "${skill_names[@]}"; do
      [[ "$name" == "$s" ]] && is_repo="yes" && break
    done
    for cat in "${categories[@]}"; do
      [[ "$name" == "$cat" ]] && is_repo="yes" && break
    done
    if [[ -z "$is_repo" ]]; then
      printf "  %-30s · non-repo skill\n" "$name/"
    fi
  done

  [[ $broken -gt 0 ]] && echo "  ($broken broken symlink(s) — run --clean to remove)"
}

# Status for Cursor (category-level)
check_status_cursor() {
  local global_dir="$1"
  echo ""
  echo "=== Cursor ($global_dir) — category-level ==="

  if [[ ! -d "$global_dir" ]]; then
    echo "  (directory does not exist)"
    return
  fi

  local categories
  categories=($(discover_categories))
  local broken=0

  for cat in "${categories[@]}"; do
    local target="$global_dir/$cat"
    if [[ -L "$target" ]]; then
      local link_target
      link_target="$(readlink "$target")"
      if [[ ! -e "$target" ]]; then
        printf "  %-20s ✗ BROKEN → %s\n" "$cat/" "$link_target"
        broken=$((broken + 1))
      elif [[ "$link_target" == "$REPO_SKILLS/$cat" || "$link_target" == "${REPO_SKILLS}/${cat}/" ]]; then
        printf "  %-20s ✓ linked → %s\n" "$cat/" "$link_target"
      else
        printf "  %-20s ⚠ linked → %s (different repo!)\n" "$cat/" "$link_target"
      fi
    elif [[ -d "$target" ]]; then
      printf "  %-20s ● copied (independent)\n" "$cat/"
    else
      printf "  %-20s ○ not present\n" "$cat/"
    fi
  done

  # Check non-repo items
  for item in "$global_dir"/*/; do
    [[ -d "$item" ]] || continue
    local name
    name="$(basename "$item")"
    local is_repo_cat=""
    for cat in "${categories[@]}"; do
      [[ "$name" == "$cat" ]] && is_repo_cat="yes" && break
    done
    if [[ -z "$is_repo_cat" ]]; then
      printf "  %-20s · non-repo skill\n" "$name/"
    fi
  done

  [[ $broken -gt 0 ]] && echo "  ($broken broken symlink(s) — run --clean to remove)"
}

if [[ "$STATUS_MODE" == "yes" ]]; then
  echo "Repo skills: $REPO_SKILLS"
  echo "Categories: $(discover_categories)"
  check_status_claude "$CLAUDE_SKILLS"
  check_status_cursor "$CURSOR_SKILLS"
  exit 0
fi

# --- Clean mode ---

clean_broken() {
  local global_dir="$1" label="$2"
  echo ""
  echo "--- Cleaning broken symlinks in $label ($global_dir) ---"

  if [[ ! -d "$global_dir" ]]; then
    echo "  (directory does not exist)"
    return
  fi

  local cleaned=0
  for target in "$global_dir"/*; do
    [[ -L "$target" ]] || continue
    if [[ ! -e "$target" ]]; then
      local link_target
      link_target="$(readlink "$target")"
      if [[ "$DRY_RUN" == "yes" ]]; then
        echo "  [dry-run] Would remove broken link: $(basename "$target") → $link_target"
      else
        rm "$target"
        echo "  Removed broken link: $(basename "$target") → $link_target"
      fi
      cleaned=$((cleaned + 1))
    fi
  done

  [[ $cleaned -eq 0 ]] && echo "  No broken symlinks found"
}

if [[ "$CLEAN_MODE" == "yes" ]]; then
  clean_broken "$CLAUDE_SKILLS" "Claude Code"
  clean_broken "$CURSOR_SKILLS" "Cursor"
  echo ""
  echo "Done."
  exit 0
fi

# --- Validate args ---

if [[ -z "$TO_CURSOR" && -z "$TO_CLAUDE" && -z "$FROM_CURSOR" && -z "$FROM_CLAUDE" ]]; then
  echo "Error: specify a direction (--to-claude, --to-cursor, --to-all, --from-claude, --from-cursor, --from-all) or --status / --clean." >&2
  echo "Run with -h for help." >&2
  exit 1
fi

if [[ -n "$FROM_CURSOR" || -n "$FROM_CLAUDE" ]] && [[ "$MODE" == "link" || "$MODE" == "unlink" ]]; then
  echo "Error: --from-* only supports --copy mode (pulling into repo)." >&2
  exit 1
fi

# --- Resolve targets ---
# Targets can be category names (meta, roles) or individual skill names within categories.
# If no targets given, operate on all categories.

resolve_repo_categories() {
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    discover_categories
  else
    # Check if targets are categories or individual skills
    for t in "${TARGETS[@]}"; do
      if [[ -d "$REPO_SKILLS/$t" ]]; then
        echo "$t"
      else
        # Search for skill name within categories
        for cat_dir in "$REPO_SKILLS"/*/; do
          [[ -d "$cat_dir" ]] || continue
          if [[ -d "$cat_dir/$t" ]]; then
            echo "$(basename "$cat_dir")"
            break
          fi
        done
      fi
    done | sort -u
  fi
}

# --- Link functions ---

# Link a single symlink: src → dst
_do_link() {
  local name="$1" src="$2" dst="$3" label="$4"

  if [[ ! -d "$src" ]]; then
    echo "  [$name] Not found in repo — skipping"
    return
  fi

  # Already correctly linked
  if [[ -L "$dst" ]]; then
    local existing
    existing="$(readlink "$dst")"
    if [[ "$existing" == "$src" || "$existing" == "${src}/" ]]; then
      echo "  [$name] Already linked ✓"
      return
    else
      if [[ "$DRY_RUN" == "yes" ]]; then
        echo "  [dry-run] Would relink: $dst (currently → $existing)"
        return
      fi
      echo "  [$name] Relinking (was → $existing)"
      rm "$dst"
    fi
  elif [[ -d "$dst" ]]; then
    if [[ "$DRY_RUN" == "yes" ]]; then
      echo "  [dry-run] Would replace copy with link: $dst → $src"
      return
    fi
    echo "  [$name] Replacing existing copy with symlink"
    rm -rf "$dst"
  else
    if [[ "$DRY_RUN" == "yes" ]]; then
      echo "  [dry-run] Would link: $dst → $src"
      return
    fi
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  [$name] Linked → $label"
}

link_category() {
  local cat="$1" global_dir="$2" label="$3"
  _do_link "$cat" "$REPO_SKILLS/$cat" "$global_dir/$cat" "$label"
}

# Link individual skills directly (flattened — no category subdirs)
link_skills_flat() {
  local global_dir="$1" label="$2"
  local skills
  skills=($(discover_skills))

  for entry in "${skills[@]}"; do
    local cat="${entry%%/*}"
    local skill="${entry##*/}"
    local src dst name
    if [[ "$skill" == "." ]]; then
      # Category IS the skill (e.g., orchestrator/SKILL.md)
      src="$REPO_SKILLS/$cat"
      dst="$global_dir/$cat"
      name="$cat"
    else
      src="$REPO_SKILLS/$cat/$skill"
      dst="$global_dir/$skill"
      name="$skill"
    fi
    _do_link "$name" "$src" "$dst" "$label"
  done
}

# --- Copy functions ---

_do_copy() {
  local name="$1" src="$2" dst="$3" label="$4"

  if [[ ! -d "$src" ]]; then
    echo "  [$name] Not found in repo — skipping"
    return
  fi

  if [[ "$DRY_RUN" == "yes" ]]; then
    echo "  [dry-run] Would copy: $src → $dst"
    return
  fi

  # Remove existing symlink if present (replacing link with copy)
  if [[ -L "$dst" ]]; then
    echo "  [$name] Replacing symlink with copy"
    rm "$dst"
  fi

  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    cp -R "$src" "$dst"
  fi
  echo "  [$name] Copied → $label"
}

copy_category() {
  local cat="$1" global_dir="$2" label="$3"
  _do_copy "$cat" "$REPO_SKILLS/$cat" "$global_dir/$cat" "$label"
}

copy_skills_flat() {
  local global_dir="$1" label="$2"
  local skills
  skills=($(discover_skills))

  for entry in "${skills[@]}"; do
    local cat="${entry%%/*}"
    local skill="${entry##*/}"
    local src dst name
    if [[ "$skill" == "." ]]; then
      src="$REPO_SKILLS/$cat"; dst="$global_dir/$cat"; name="$cat"
    else
      src="$REPO_SKILLS/$cat/$skill"; dst="$global_dir/$skill"; name="$skill"
    fi
    _do_copy "$name" "$src" "$dst" "$label"
  done
}

# --- Unlink functions ---

_do_unlink() {
  local name="$1" expected_target="$2" dst="$3" label="$4"

  if [[ -L "$dst" ]]; then
    local link_target
    link_target="$(readlink "$dst")"
    if [[ "$link_target" == "$expected_target" ]]; then
      if [[ "$DRY_RUN" == "yes" ]]; then
        echo "  [dry-run] Would unlink: $dst"
        return
      fi
      rm "$dst"
      echo "  [$name] Unlinked from $label"
    else
      echo "  [$name] Symlink points elsewhere ($link_target) — skipping"
    fi
  elif [[ -d "$dst" ]]; then
    echo "  [$name] Not a symlink (is a copy) — skipping"
  else
    echo "  [$name] Not present — nothing to unlink"
  fi
}

unlink_category() {
  local cat="$1" global_dir="$2" label="$3"
  _do_unlink "$cat" "$REPO_SKILLS/$cat" "$global_dir/$cat" "$label"
}

unlink_skills_flat() {
  local global_dir="$1" label="$2"
  local skills
  skills=($(discover_skills))

  for entry in "${skills[@]}"; do
    local cat="${entry%%/*}"
    local skill="${entry##*/}"
    local src dst name
    if [[ "$skill" == "." ]]; then
      src="$REPO_SKILLS/$cat"; dst="$global_dir/$cat"; name="$cat"
    else
      src="$REPO_SKILLS/$cat/$skill"; dst="$global_dir/$skill"; name="$skill"
    fi
    _do_unlink "$name" "$src" "$dst" "$label"
  done
}

# --- Pull functions ---

pull_skill() {
  local src="$1" dst="$2" name="$3"

  if [[ ! -d "$src" ]]; then
    echo "  [$name] Not found — skipping"
    return
  fi

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  [$name] No SKILL.md — skipping (not a skill)"
    return
  fi

  if [[ "$DRY_RUN" == "yes" ]]; then
    echo "  [dry-run] Would pull: $src → $dst"
    return
  fi

  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    cp -R "$src" "$dst"
  fi
  echo "  [$name] Pulled into repo"
}

pull_from() {
  local global_dir="$1" label="$2"

  echo ""
  echo "--- Pulling from $label ---"

  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    # Pull all skills found (skip symlinks pointing back to repo)
    for item in "$global_dir"/*/; do
      [[ -d "$item" ]] || continue
      local name
      name="$(basename "$item")"

      # If it's a symlink to our repo, skip
      if [[ -L "$item" ]]; then
        local lt
        lt="$(readlink "$item")"
        if [[ "$lt" == "$REPO_SKILLS/"* ]]; then
          echo "  [$name] Symlink to this repo — skipping"
          continue
        fi
      fi

      # If it contains SKILL.md directly, it's a skill
      if [[ -f "$item/SKILL.md" ]]; then
        pull_skill "$item" "$REPO_SKILLS/$name" "$name"
      else
        # Category directory — pull individual skills within
        for skill_dir in "$item"/*/; do
          [[ -d "$skill_dir" ]] || continue
          local skill_name
          skill_name="$(basename "$skill_dir")"
          [[ -f "$skill_dir/SKILL.md" ]] || continue
          pull_skill "$skill_dir" "$REPO_SKILLS/$name/$skill_name" "$name/$skill_name"
        done
      fi
    done
  else
    for name in "${TARGETS[@]}"; do
      # Search for the skill in global dir
      if [[ -d "$global_dir/$name" ]]; then
        pull_skill "$global_dir/$name" "$REPO_SKILLS/$name" "$name"
      else
        # Search within category dirs
        local found=""
        for cat_dir in "$global_dir"/*/; do
          [[ -d "$cat_dir" ]] || continue
          if [[ -d "$cat_dir/$name" && -f "$cat_dir/$name/SKILL.md" ]]; then
            local cat
            cat="$(basename "$cat_dir")"
            pull_skill "$cat_dir/$name" "$REPO_SKILLS/$cat/$name" "$cat/$name"
            found="yes"
            break
          fi
        done
        [[ -z "$found" ]] && echo "  [$name] Not found in $label — skipping"
      fi
    done
  fi
}

# --- Execute ---

# Claude Code: flatten skills (no category subdirs) so each skill is at ~/.claude/skills/<skill>/SKILL.md
sync_to_claude() {
  local mode_label
  mode_label="$(echo "$MODE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  echo ""
  echo "--- ${mode_label}ing to Claude Code (flattened) ---"

  case "$MODE" in
    link)   link_skills_flat "$CLAUDE_SKILLS" "Claude Code" ;;
    copy)   copy_skills_flat "$CLAUDE_SKILLS" "Claude Code" ;;
    unlink) unlink_skills_flat "$CLAUDE_SKILLS" "Claude Code" ;;
  esac
}

# Cursor: keep category-level structure
sync_to_cursor() {
  local categories
  categories=($(resolve_repo_categories))

  local mode_label
  mode_label="$(echo "$MODE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  echo ""
  echo "--- ${mode_label}ing to Cursor ---"

  for cat in "${categories[@]}"; do
    case "$MODE" in
      link)   link_category "$cat" "$CURSOR_SKILLS" "Cursor" ;;
      copy)   copy_category "$cat" "$CURSOR_SKILLS" "Cursor" ;;
      unlink) unlink_category "$cat" "$CURSOR_SKILLS" "Cursor" ;;
    esac
  done
}

[[ "$TO_CLAUDE" == "yes" ]]   && sync_to_claude
[[ "$TO_CURSOR" == "yes" ]]   && sync_to_cursor
[[ "$FROM_CURSOR" == "yes" ]] && pull_from "$CURSOR_SKILLS" "Cursor"
[[ "$FROM_CLAUDE" == "yes" ]] && pull_from "$CLAUDE_SKILLS" "Claude Code"

echo ""
echo "Done."
