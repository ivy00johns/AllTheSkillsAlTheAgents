#!/usr/bin/env bash
#
# install.sh — Install AllTheSkillsAllTheAgents into local agentic tools.
#
# Reads converted artifacts from integrations/ and copies them to the
# appropriate config directories for each tool. Run scripts/convert.sh first.
#
# Usage:
#   scripts/install.sh [OPTIONS] [TOOL ...]
#
# Options:
#   --tool NAME          Install for a single tool (repeatable)
#   --all                Install for all 11 tools
#   --detected           Install only for detected tools (default in non-interactive)
#   --interactive        Force the TUI (default if stdin is a TTY)
#   --no-interactive     Skip the TUI (default if stdin is not a TTY)
#   --parallel           Run installations concurrently
#   --jobs N             Worker count for --parallel (default: nproc / sysctl)
#   --dry-run            Print what would be copied; do not write
#   --help               Print this and exit
#
# Exit codes: 0 success, 1 install error, 2 argument/preflight error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=scripts/lib/term.sh
. "$LIB_DIR/term.sh"
# shellcheck source=scripts/lib/platform.sh
. "$LIB_DIR/platform.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTEGRATIONS="$REPO_ROOT/integrations"

ALL_TOOLS=(claude-code copilot antigravity gemini-cli opencode cursor openclaw qwen kimi aider windsurf)

DRY_RUN=false

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---------------------------------------------------------------------------
# Dry-run aware copy helpers
# ---------------------------------------------------------------------------

# install_file <src> <dst>
# Copy src to dst, respecting DRY_RUN. Handles symlink replacement and
# identical-file optimization.
install_file() {
  local src="$1" dst="$2"

  if $DRY_RUN; then
    printf '  [dry-run] would copy: %s -> %s\n' "$src" "$dst"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"

  # Destination is a symlink: replace with regular file
  if [[ -L "$dst" ]]; then
    ats_warn "[install] replaced symlink at $dst"
    rm "$dst"
  fi

  # If files are identical, skip silently (or note at --verbose)
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    return 0
  fi

  cp "$src" "$dst"
  printf '[install] updated %s\n' "$dst"
}

# install_dir <src_dir> <dst_dir>
# Recursively install all files from src_dir into dst_dir.
install_dir() {
  local src_dir="$1" dst_dir="$2"
  local f rel_path dst_file

  while IFS= read -r -d '' f; do
    rel_path="${f#"${src_dir}"/}"
    dst_file="$dst_dir/$rel_path"
    install_file "$f" "$dst_file"
  done < <(find "$src_dir" -type f -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
check_integrations() {
  if [[ ! -d "$INTEGRATIONS" ]]; then
    ats_err "integrations/ not found. Run scripts/convert.sh first."
    exit 2
  fi
}

check_tool_integration() {
  local tool="$1"
  if [[ ! -d "$INTEGRATIONS/$tool" ]]; then
    ats_err "integrations/$tool/ not found. Run: scripts/convert.sh --tool $tool"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Tool detection
# ---------------------------------------------------------------------------
detect_claude_code()  { [[ -d "${HOME}/.claude" ]]; }
detect_copilot()      { command -v code >/dev/null 2>&1 || [[ -d "${HOME}/.github" || -d "${HOME}/.copilot" ]]; }
detect_antigravity()  { [[ -d "${HOME}/.gemini/antigravity/skills" ]]; }
detect_gemini_cli()   { command -v gemini >/dev/null 2>&1 || [[ -d "${HOME}/.gemini" ]]; }
detect_opencode()     { command -v opencode >/dev/null 2>&1 || [[ -d "$PWD/.opencode" ]]; }
detect_cursor()       { command -v cursor >/dev/null 2>&1 || [[ -d "${HOME}/.cursor" ]]; }
detect_openclaw()     { command -v openclaw >/dev/null 2>&1 || [[ -d "${HOME}/.openclaw" ]]; }
detect_qwen()         { command -v qwen >/dev/null 2>&1; }
detect_kimi()         { command -v kimi >/dev/null 2>&1 || [[ -d "${HOME}/.config/kimi" ]]; }
detect_aider()        { command -v aider >/dev/null 2>&1; }
detect_windsurf()     { command -v windsurf >/dev/null 2>&1 || [[ -d "${HOME}/.codeium/windsurf" ]]; }

is_detected() {
  case "$1" in
    claude-code)  detect_claude_code  ;;
    copilot)      detect_copilot      ;;
    antigravity)  detect_antigravity  ;;
    gemini-cli)   detect_gemini_cli   ;;
    opencode)     detect_opencode     ;;
    cursor)       detect_cursor       ;;
    openclaw)     detect_openclaw     ;;
    qwen)         detect_qwen         ;;
    kimi)         detect_kimi         ;;
    aider)        detect_aider        ;;
    windsurf)     detect_windsurf     ;;
    *)            return 1            ;;
  esac
}

# ---------------------------------------------------------------------------
# Tool labels for TUI
# ---------------------------------------------------------------------------
tool_label() {
  case "$1" in
    claude-code)  printf '%-14s  %s' 'Claude Code'  '(~/.claude/skills/)'          ;;
    copilot)      printf '%-14s  %s' 'Copilot'      '(~/.github + ~/.copilot)'     ;;
    antigravity)  printf '%-14s  %s' 'Antigravity'  '(~/.gemini/antigravity)'      ;;
    gemini-cli)   printf '%-14s  %s' 'Gemini CLI'   '(gemini extension)'           ;;
    opencode)     printf '%-14s  %s' 'OpenCode'     '(.opencode/agents)'           ;;
    cursor)       printf '%-14s  %s' 'Cursor'       '(.cursor/rules)'              ;;
    openclaw)     printf '%-14s  %s' 'OpenClaw'     '(~/.openclaw/alltheskills)'   ;;
    qwen)         printf '%-14s  %s' 'Qwen Code'    '(.qwen/agents)'               ;;
    kimi)         printf '%-14s  %s' 'Kimi Code'    '(~/.config/kimi/agents)'      ;;
    aider)        printf '%-14s  %s' 'Aider'        '(CONVENTIONS.md)'            ;;
    windsurf)     printf '%-14s  %s' 'Windsurf'     '(.windsurfrules)'             ;;
    *)            printf '%s' "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Interactive TUI selector
# Sets SELECTED_TOOLS array on exit.
# ---------------------------------------------------------------------------
interactive_select() {
  # Bash 3.2-safe: use indexed arrays with numeric indices
  local i t num
  local n_tools=${#ALL_TOOLS[@]}
  local selected=()
  local detected_map=()

  for (( i=0; i<n_tools; i++ )); do
    t="${ALL_TOOLS[$i]}"
    if is_detected "$t" 2>/dev/null; then
      selected+=(1); detected_map+=(1)
    else
      selected+=(0); detected_map+=(0)
    fi
  done

  while true; do
    printf '\n'
    box_top
    box_row "${C_BOLD}  AllTheSkillsAllTheAgents -- Skill Installer${C_RESET}"
    box_bot
    printf '\n'
    printf '  %sSystem scan:  [*] = detected on this machine%s\n' "${C_DIM}" "${C_RESET}"
    printf '\n'

    for (( i=0; i<n_tools; i++ )); do
      t="${ALL_TOOLS[$i]}"
      num=$(( i + 1 ))
      local label dot chk
      label="$(tool_label "$t")"
      if [[ "${detected_map[$i]}" == "1" ]]; then
        dot="${C_GREEN}[*]${C_RESET}"
      else
        dot="${C_DIM}[ ]${C_RESET}"
      fi
      if [[ "${selected[$i]}" == "1" ]]; then
        chk="${C_GREEN}[x]${C_RESET}"
      else
        chk="${C_DIM}[ ]${C_RESET}"
      fi
      printf '  %s  %s)  %s  %s\n' "$chk" "$num" "$dot" "$label"
    done

    printf '\n'
    printf '  ------------------------------------------------\n'
    printf '  %s[1-%s]%s toggle   %s[a]%s all   %s[n]%s none   %s[d]%s detected\n' \
      "${C_CYAN}" "$n_tools" "${C_RESET}" \
      "${C_CYAN}" "${C_RESET}" \
      "${C_CYAN}" "${C_RESET}" \
      "${C_CYAN}" "${C_RESET}"
    printf '  %s[Enter]%s install   %s[q]%s quit\n' \
      "${C_GREEN}" "${C_RESET}" "${C_RED}" "${C_RESET}"
    printf '\n'
    printf '  >> '

    local input=''
    read -r input </dev/tty || true

    case "$input" in
      q|Q)
        printf '\n'; ats_ok 'Aborted.'; exit 0 ;;
      a|A)
        # shellcheck disable=SC2004 # arithmetic array indexing: $i is conventional bash style
        for (( i=0; i<n_tools; i++ )); do selected[$i]=1; done ;;
      n|N)
        # shellcheck disable=SC2004
        for (( i=0; i<n_tools; i++ )); do selected[$i]=0; done ;;
      d|D)
        # shellcheck disable=SC2004
        for (( i=0; i<n_tools; i++ )); do selected[$i]="${detected_map[$i]}"; done ;;
      '')
        local any=false s
        for s in "${selected[@]}"; do [[ "$s" == "1" ]] && any=true && break; done
        if $any; then
          break
        else
          printf '  %sNothing selected. Pick a tool or press q to quit.%s\n' "${C_YELLOW}" "${C_RESET}"
        fi ;;
      *)
        local toggled=false
        # Allow space-separated or single number input
        for num in $input; do
          if [[ "$num" =~ ^[0-9]+$ ]]; then
            local idx=$(( num - 1 ))
            if (( idx >= 0 && idx < n_tools )); then
              # shellcheck disable=SC2004 # arithmetic array indexing: $idx is conventional
              if [[ "${selected[$idx]}" == "1" ]]; then
                selected[$idx]=0
              else
                selected[$idx]=1
              fi
              toggled=true
            fi
          fi
        done
        if ! $toggled; then
          printf '  %sInvalid input. Enter 1-%s, a/n/d, or q.%s\n' \
            "${C_RED}" "$n_tools" "${C_RESET}"
        fi ;;
    esac

    # Redraw: move cursor up to clear the UI
    local lines=$(( n_tools + 13 ))
    local l
    for (( l=0; l<lines; l++ )); do printf '\033[1A\033[2K'; done
  done

  # Build SELECTED_TOOLS from the selected array
  SELECTED_TOOLS=()
  for (( i=0; i<n_tools; i++ )); do
    [[ "${selected[$i]}" == "1" ]] && SELECTED_TOOLS+=("${ALL_TOOLS[$i]}")
  done
}

# ---------------------------------------------------------------------------
# Installers — one per tool
# ---------------------------------------------------------------------------

install_claude_code() {
  local src="$INTEGRATIONS/claude-code"
  local base_dest="${HOME}/.claude/skills"
  local count=0 skill_dir skill_name dest_dir

  check_tool_integration "claude-code" || return 1

  # Walk category/slug dirs under integrations/claude-code/
  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    local category
    category="$(basename "$(dirname "$skill_dir")")"
    dest_dir="$base_dest/$category/$skill_name"

    # Skip dirs managed by /sync-skills (symlinks at the skill level)
    if [[ -L "$dest_dir" ]]; then
      printf '[install] skipped %s (managed by /sync-skills)\n' "$skill_name" >&2
      continue
    fi

    if $DRY_RUN; then
      printf '  [dry-run] would install: %s -> %s\n' "$skill_dir" "$dest_dir"
      count=$(( count + 1 ))
      continue
    fi

    mkdir -p "$dest_dir"
    install_dir "$skill_dir" "$dest_dir"
    count=$(( count + 1 ))
  done < <(find "$src" -mindepth 2 -maxdepth 2 -type d -print0 | sort -z)

  ats_ok "Claude Code: $count skills -> $base_dest"
}

install_copilot() {
  local src="$INTEGRATIONS/copilot"
  local dest_github="${HOME}/.github/agents"
  local dest_copilot="${HOME}/.copilot/agents"
  local count=0 f

  check_tool_integration "copilot" || return 1

  if $DRY_RUN; then
    while IFS= read -r -d '' f; do
      local base; base="$(basename "$f")"
      printf '  [dry-run] would copy: %s -> %s\n' "$f" "$dest_github/$base"
      printf '  [dry-run] would copy: %s -> %s\n' "$f" "$dest_copilot/$base"
      count=$(( count + 1 ))
    done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 | sort -z)
    ats_ok "Copilot: $count skills (dry-run)"
    return 0
  fi

  mkdir -p "$dest_github" "$dest_copilot"

  while IFS= read -r -d '' f; do
    local base; base="$(basename "$f")"
    install_file "$f" "$dest_github/$base"
    install_file "$f" "$dest_copilot/$base"
    count=$(( count + 1 ))
  done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 | sort -z)

  # Also copy reference dirs
  while IFS= read -r -d '' ref_dir; do
    local rname; rname="$(basename "$ref_dir")"
    install_dir "$ref_dir" "$dest_github/$rname"
    install_dir "$ref_dir" "$dest_copilot/$rname"
  done < <(find "$src" -maxdepth 1 -type d -name '*-references' -print0 | sort -z)

  ats_ok "Copilot: $count skills -> $dest_github and $dest_copilot"
}

install_antigravity() {
  local src="$INTEGRATIONS/antigravity"
  local dest="${HOME}/.gemini/antigravity/skills"
  local count=0 skill_dir skill_name

  check_tool_integration "antigravity" || return 1

  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    if $DRY_RUN; then
      printf '  [dry-run] would install: %s -> %s/%s\n' "$skill_dir" "$dest" "$skill_name"
      count=$(( count + 1 ))
      continue
    fi
    mkdir -p "$dest/$skill_name"
    install_dir "$skill_dir" "$dest/$skill_name"
    count=$(( count + 1 ))
  done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  ats_ok "Antigravity: $count skills -> $dest"
}

install_gemini_cli() {
  local src="$INTEGRATIONS/gemini-cli"
  local dest="${HOME}/.gemini/extensions/alltheskills"
  local manifest="$src/gemini-extension.json"
  local skills_dir="$src/skills"
  local count=0 skill_dir skill_name

  check_tool_integration "gemini-cli" || return 1

  if [[ ! -f "$manifest" ]]; then
    ats_err "integrations/gemini-cli/gemini-extension.json missing. Run convert.sh --tool gemini-cli first."
    return 1
  fi

  if $DRY_RUN; then
    printf '  [dry-run] would copy: %s -> %s/gemini-extension.json\n' "$manifest" "$dest"
    while IFS= read -r -d '' skill_dir; do
      skill_name="$(basename "$skill_dir")"
      printf '  [dry-run] would install: %s -> %s/skills/%s\n' "$skill_dir" "$dest" "$skill_name"
      count=$(( count + 1 ))
    done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    ats_ok "Gemini CLI: $count skills (dry-run)"
    return 0
  fi

  mkdir -p "$dest/skills"
  install_file "$manifest" "$dest/gemini-extension.json"

  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$dest/skills/$skill_name"
    install_dir "$skill_dir" "$dest/skills/$skill_name"
    count=$(( count + 1 ))
  done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  ats_ok "Gemini CLI: $count skills -> $dest"
}

install_opencode() {
  local src="$INTEGRATIONS/opencode/agents"
  local dest="$PWD/.opencode/agents"
  local count=0 f base

  check_tool_integration "opencode" || return 1

  if $DRY_RUN; then
    while IFS= read -r -d '' f; do
      base="$(basename "$f")"
      printf '  [dry-run] would copy: %s -> %s/%s\n' "$f" "$dest" "$base"
      count=$(( count + 1 ))
    done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null | sort -z)
    ats_ok "OpenCode: $count skills (dry-run, project-scoped to $PWD)"
    return 0
  fi

  mkdir -p "$dest"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    install_file "$f" "$dest/$base"
    count=$(( count + 1 ))
  done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null | sort -z)

  ats_ok "OpenCode: $count skills -> $dest"
  ats_warn "OpenCode: project-scoped. Run from your project root."
}

install_cursor() {
  local src="$INTEGRATIONS/cursor/rules"
  local dest="$PWD/.cursor/rules"
  local count=0 f base

  check_tool_integration "cursor" || return 1

  if $DRY_RUN; then
    while IFS= read -r -d '' f; do
      base="$(basename "$f")"
      printf '  [dry-run] would copy: %s -> %s/%s\n' "$f" "$dest" "$base"
      count=$(( count + 1 ))
    done < <(find "$src" -maxdepth 1 -name '*.mdc' -type f -print0 2>/dev/null | sort -z)
    ats_ok "Cursor: $count rules (dry-run, project-scoped to $PWD)"
    return 0
  fi

  mkdir -p "$dest"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    install_file "$f" "$dest/$base"
    count=$(( count + 1 ))
  done < <(find "$src" -maxdepth 1 -name '*.mdc' -type f -print0 2>/dev/null | sort -z)

  ats_ok "Cursor: $count rules -> $dest"
  ats_warn "Cursor: project-scoped. Run from your project root."
}

install_openclaw() {
  local src="$INTEGRATIONS/openclaw"
  local dest="${HOME}/.openclaw/alltheskills"
  local count=0 skill_dir skill_name

  check_tool_integration "openclaw" || return 1

  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    if [[ ! -f "$skill_dir/SOUL.md" || ! -f "$skill_dir/AGENTS.md" || ! -f "$skill_dir/IDENTITY.md" ]]; then
      continue
    fi
    if $DRY_RUN; then
      printf '  [dry-run] would install: %s -> %s/%s/{SOUL,AGENTS,IDENTITY}.md\n' \
        "$skill_dir" "$dest" "$skill_name"
      count=$(( count + 1 ))
      continue
    fi
    mkdir -p "$dest/$skill_name"
    install_dir "$skill_dir" "$dest/$skill_name"
    count=$(( count + 1 ))
  done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  ats_ok "OpenClaw: $count skills -> $dest"
  if command -v openclaw >/dev/null 2>&1 && ! $DRY_RUN; then
    ats_warn "OpenClaw: run 'openclaw gateway restart' to activate new skills"
  fi
}

install_qwen() {
  local src="$INTEGRATIONS/qwen/agents"
  local dest="$PWD/.qwen/agents"
  local count=0 f base

  check_tool_integration "qwen" || return 1

  if $DRY_RUN; then
    while IFS= read -r -d '' f; do
      base="$(basename "$f")"
      printf '  [dry-run] would copy: %s -> %s/%s\n' "$f" "$dest" "$base"
      count=$(( count + 1 ))
    done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null | sort -z)
    ats_ok "Qwen: $count skills (dry-run, project-scoped to $PWD)"
    return 0
  fi

  mkdir -p "$dest"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    install_file "$f" "$dest/$base"
    count=$(( count + 1 ))
  done < <(find "$src" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null | sort -z)

  ats_ok "Qwen Code: $count skills -> $dest"
  ats_warn "Qwen: project-scoped. Run from your project root."
}

install_kimi() {
  local src="$INTEGRATIONS/kimi"
  local dest="${HOME}/.config/kimi/agents"
  local count=0 skill_dir skill_name

  check_tool_integration "kimi" || return 1

  while IFS= read -r -d '' skill_dir; do
    skill_name="$(basename "$skill_dir")"
    if $DRY_RUN; then
      printf '  [dry-run] would install: %s -> %s/%s/{agent.yaml,system.md}\n' \
        "$skill_dir" "$dest" "$skill_name"
      count=$(( count + 1 ))
      continue
    fi
    mkdir -p "$dest/$skill_name"
    install_dir "$skill_dir" "$dest/$skill_name"
    count=$(( count + 1 ))
  done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  ats_ok "Kimi Code: $count skills -> $dest"
}

install_aider() {
  local src="$INTEGRATIONS/aider/CONVENTIONS.md"
  local dest="$PWD/CONVENTIONS.md"

  check_tool_integration "aider" || return 1
  if [[ ! -f "$src" ]]; then
    ats_err "integrations/aider/CONVENTIONS.md missing. Run convert.sh --tool aider first."
    return 1
  fi

  if $DRY_RUN; then
    printf '  [dry-run] would copy: %s -> %s\n' "$src" "$dest"
    ats_ok "Aider: (dry-run, project-scoped to $PWD)"
    return 0
  fi

  # Per contract: refuse to overwrite existing file (user-edited project file)
  if [[ -f "$dest" ]]; then
    ats_err "$dest exists; remove or rename before install"
    return 1
  fi

  cp "$src" "$dest"
  ats_ok "Aider: installed -> $dest"
  ats_warn "Aider: project-scoped. Run from your project root."
}

install_windsurf() {
  local src="$INTEGRATIONS/windsurf/.windsurfrules"
  local dest="$PWD/.windsurfrules"

  check_tool_integration "windsurf" || return 1
  if [[ ! -f "$src" ]]; then
    ats_err "integrations/windsurf/.windsurfrules missing. Run convert.sh --tool windsurf first."
    return 1
  fi

  if $DRY_RUN; then
    printf '  [dry-run] would copy: %s -> %s\n' "$src" "$dest"
    ats_ok "Windsurf: (dry-run, project-scoped to $PWD)"
    return 0
  fi

  # Per contract: refuse to overwrite existing file (user-edited project file)
  if [[ -f "$dest" ]]; then
    ats_err "$dest exists; remove or rename before install"
    return 1
  fi

  cp "$src" "$dest"
  ats_ok "Windsurf: installed -> $dest"
  ats_warn "Windsurf: project-scoped. Run from your project root."
}

install_tool() {
  local t="$1"
  case "$t" in
    claude-code)  install_claude_code  ;;
    copilot)      install_copilot      ;;
    antigravity)  install_antigravity  ;;
    gemini-cli)   install_gemini_cli   ;;
    opencode)     install_opencode     ;;
    cursor)       install_cursor       ;;
    openclaw)     install_openclaw     ;;
    qwen)         install_qwen         ;;
    kimi)         install_kimi         ;;
    aider)        install_aider        ;;
    windsurf)     install_windsurf     ;;
    *)            ats_err "Unknown tool: $t"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Worker entry point (parallel mode)
# When ATS_INSTALL_WORKER=1, run a single tool and exit, suppressing TUI.
# ---------------------------------------------------------------------------
if [[ "${ATS_INSTALL_WORKER:-}" == "1" && -n "${ATS_INSTALL_TOOL:-}" ]]; then
  install_tool "${ATS_INSTALL_TOOL}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local interactive_mode="auto"
  local use_parallel=false
  local parallel_jobs
  parallel_jobs="$(nproc_count)"
  local explicit_tools=()
  local use_all=false
  local use_detected=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tool)          explicit_tools+=("${2:?'--tool requires a value'}"); shift 2 ;;
      --all)           use_all=true; shift ;;
      --detected)      use_detected=true; shift ;;
      --interactive)   interactive_mode="yes"; shift ;;
      --no-interactive) interactive_mode="no"; shift ;;
      --parallel)      use_parallel=true; shift ;;
      --jobs)          parallel_jobs="${2:?'--jobs requires a value'}"; shift 2 ;;
      --dry-run)       DRY_RUN=true; shift ;;
      --help|-h)       usage ;;
      -*)              ats_err "Unknown option: $1"; exit 2 ;;
      *)               explicit_tools+=("$1"); shift ;;
    esac
  done

  # Validate explicit tools
  local t valid
  for t in "${explicit_tools[@]+"${explicit_tools[@]}"}"; do
    valid=false
    local v
    for v in "${ALL_TOOLS[@]}"; do [[ "$v" == "$t" ]] && valid=true && break; done
    if ! $valid; then
      ats_err "Unknown tool '$t'. Valid: ${ALL_TOOLS[*]}"
      exit 2
    fi
  done

  check_integrations

  if $DRY_RUN; then
    ats_header "AllTheSkillsAllTheAgents -- Skill Installer (DRY RUN)"
  else
    ats_header "AllTheSkillsAllTheAgents -- Skill Installer"
  fi

  SELECTED_TOOLS=()

  # Determine selection mode
  if [[ ${#explicit_tools[@]} -gt 0 ]]; then
    SELECTED_TOOLS=("${explicit_tools[@]}")
  elif $use_all; then
    SELECTED_TOOLS=("${ALL_TOOLS[@]}")
  elif $use_detected; then
    for t in "${ALL_TOOLS[@]}"; do
      is_detected "$t" 2>/dev/null && SELECTED_TOOLS+=("$t")
    done
  else
    # Auto-mode: TUI if stdin+stdout are TTY, else detected
    if [[ "$interactive_mode" == "yes" ]] || \
       [[ "$interactive_mode" == "auto" && -t 0 && -t 1 ]]; then
      interactive_select
    else
      printf '\n  Scanning for installed tools...\n\n'
      for t in "${ALL_TOOLS[@]}"; do
        if is_detected "$t" 2>/dev/null; then
          SELECTED_TOOLS+=("$t")
          printf '  %s[*]%s  %s  %sdetected%s\n' \
            "${C_GREEN}" "${C_RESET}" "$(tool_label "$t")" "${C_DIM}" "${C_RESET}"
        else
          printf '  %s[ ]  %s  not found%s\n' "${C_DIM}" "$(tool_label "$t")" "${C_RESET}"
        fi
      done
    fi
  fi

  if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]]; then
    ats_warn "No tools selected or detected. Nothing to install."
    printf '\n'
    ats_dim "  Tip: use --tool <name> to force-install a specific tool."
    ats_dim "  Available: ${ALL_TOOLS[*]}"
    exit 0
  fi

  printf '\n'
  printf '  Repo:       %s\n' "$REPO_ROOT"
  printf '  Installing: %s\n' "${SELECTED_TOOLS[*]}"
  if $DRY_RUN; then
    printf '  Mode:       DRY RUN (no files will be written)\n'
  fi
  printf '\n'

  local installed=0 errors=0
  local n_selected=${#SELECTED_TOOLS[@]}

  if $use_parallel && (( n_selected > 1 )); then
    local install_out_dir
    install_out_dir="$(ats_mktemp_dir)"
    local tools_list
    tools_list="$(ats_mktemp_file)"
    for t in "${SELECTED_TOOLS[@]}"; do printf '%s\n' "$t"; done > "$tools_list"

    export ATS_INSTALL_WORKER=1 INTEGRATIONS DRY_RUN REPO_ROOT
    # shellcheck disable=SC2016 # single quotes: xargs shell expansion
    xargs -P "$parallel_jobs" -I {} sh -c \
      'ATS_INSTALL_TOOL="{}" ATS_INSTALL_WORKER=1 '"$SCRIPT_DIR"'/install.sh --tool "{}" --no-interactive > "'"$install_out_dir"'/{}" 2>&1' \
      < "$tools_list"
    unset ATS_INSTALL_WORKER

    for t in "${SELECTED_TOOLS[@]}"; do
      [[ -f "$install_out_dir/$t" ]] && cat "$install_out_dir/$t"
    done
    rm -rf "$install_out_dir" "$tools_list"
    installed=$n_selected
  else
    local i=0
    for t in "${SELECTED_TOOLS[@]}"; do
      (( i++ )) || true
      progress_bar "$i" "$n_selected"
      printf '\n'
      printf '  %s[%s/%s]%s %s\n' "${C_DIM}" "$i" "$n_selected" "${C_RESET}" "$t"
      local rc=0
      install_tool "$t" || rc=$?
      if (( rc != 0 )); then
        errors=$(( errors + 1 ))
      else
        installed=$(( installed + 1 ))
      fi
    done
  fi

  printf '\n'
  box_top
  if $DRY_RUN; then
    box_row "${C_BOLD}  Dry run complete. No files written.${C_RESET}"
  else
    box_row "${C_GREEN}${C_BOLD}  Done! Installed ${installed} tool(s).${C_RESET}"
  fi
  box_bot
  printf '\n'

  if (( errors > 0 )); then
    printf '[install] %d error(s) during install\n' "$errors" >&2
    exit 1
  fi
}

main "$@"
