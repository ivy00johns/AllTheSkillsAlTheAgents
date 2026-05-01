#!/usr/bin/env bash
#
# convert.sh — Convert canonical SKILL.md files into 11 tool-specific formats.
#
# Reads all skills from skills/**/SKILL.md (never claude_docs/) and writes
# converted output to integrations/<tool>/. Run this before install.sh.
#
# Usage:
#   scripts/convert.sh [--tool <name>] [--out <dir>] [--parallel] [--jobs N] [--help]
#
# Tools:
#   claude-code  antigravity  gemini-cli  opencode  cursor  openclaw
#   qwen         kimi         aider       windsurf  copilot  all (default)
#
# Options:
#   --tool NAME      Convert for a single tool only
#   --out DIR        Override output directory (default: integrations/)
#   --parallel       Run per-tool conversions concurrently (--tool all only)
#   --jobs N         Parallel worker count (default: nproc / sysctl)
#   --help           Show this help and exit
#
# Exit codes: 0 success, 1 per-skill error, 2 argument error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=scripts/lib/term.sh
. "$LIB_DIR/term.sh"
# shellcheck source=scripts/lib/platform.sh
. "$LIB_DIR/platform.sh"
# shellcheck source=scripts/lib/slug.sh
. "$LIB_DIR/slug.sh"
# shellcheck source=scripts/lib/frontmatter.sh
. "$LIB_DIR/frontmatter.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$REPO_ROOT/integrations"
SKILLS_ROOT="$REPO_ROOT/skills"
TODAY="$(date -u +%Y-%m-%d)"

ALL_TOOLS=(claude-code copilot antigravity gemini-cli opencode cursor openclaw qwen kimi aider windsurf)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---------------------------------------------------------------------------
# Walk skills in deterministic ASCII order.
# Prints absolute paths of all SKILL.md files, sorted by category/slug.
# Skips claude_docs/ (personal skills excluded from OSS bundle).
# ---------------------------------------------------------------------------
collect_skills() {
  find "$SKILLS_ROOT" -name "SKILL.md" -type f | sort
}

# ---------------------------------------------------------------------------
# derive_category_slug <skill_file>
# Sets SKILL_CATEGORY and SKILL_SLUG globals.
# Special case: skills/orchestrator/SKILL.md → category=orchestrator, slug=orchestrator
# ---------------------------------------------------------------------------
derive_category_slug() {
  local file="$1"
  local skill_dir
  skill_dir="$(dirname "$file")"
  SKILL_SLUG="$(basename "$skill_dir")"
  local parent_dir
  parent_dir="$(basename "$(dirname "$skill_dir")")"
  # When parent_dir == "skills", the skill lives directly in skills/<name>/
  # (i.e., orchestrator). Treat category as the slug itself.
  if [[ "$parent_dir" == "skills" ]]; then
    SKILL_CATEGORY="$SKILL_SLUG"
  else
    SKILL_CATEGORY="$parent_dir"
  fi
}

# ---------------------------------------------------------------------------
# write_file_verbose <dest_path> <content_on_stdin>
# Creates parent dirs and writes content from stdin.
# ---------------------------------------------------------------------------
write_file_from_stdin() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest"
}

# ---------------------------------------------------------------------------
# copy_references <skill_file> <dest_dir>
# Copies skill's references/ dir into dest_dir/references/ if it exists.
# ---------------------------------------------------------------------------
copy_references() {
  local skill_file="$1" dest_dir="$2"
  local refs_src
  refs_src="$(dirname "$skill_file")/references"
  if [[ -d "$refs_src" ]]; then
    mkdir -p "$dest_dir/references"
    ats_cp_r "$refs_src" "$dest_dir/references"
  fi
}

# ---------------------------------------------------------------------------
# inline_references <skill_file>
# Print each reference file under a ## Reference: <name> header.
# Used by cursor, qwen, kimi.
# ---------------------------------------------------------------------------
inline_references() {
  local skill_file="$1"
  local refs_src ref_file ref_name
  refs_src="$(dirname "$skill_file")/references"
  if [[ -d "$refs_src" ]]; then
    while IFS= read -r ref_file; do
      ref_name="$(basename "$ref_file" .md)"
      printf '\n## Reference: %s\n\n' "$ref_name"
      cat "$ref_file"
    done < <(find "$refs_src" -maxdepth 1 -type f | sort)
  fi
}

# ---------------------------------------------------------------------------
# Converter: claude-code
# Passthrough — preserve full canonical layout + references.
# ---------------------------------------------------------------------------
convert_claude_code() {
  local file="$1" category="$2" slug="$3"
  local dest_dir="$OUT_DIR/claude-code/$category/$slug"
  local dest_file="$dest_dir/SKILL.md"
  mkdir -p "$dest_dir"
  cp "$file" "$dest_file"
  copy_references "$file" "$dest_dir"
}

# ---------------------------------------------------------------------------
# Converter: copilot
# Flat layout. Strip agent-role fields. Copy references as <slug>-references/.
# ---------------------------------------------------------------------------
convert_copilot() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused but kept for consistent signature
  local category="$2"
  local dest_dir="$OUT_DIR/copilot"
  local dest_file="$dest_dir/${slug}.md"
  local name version description refs_src
  mkdir -p "$dest_dir"

  name="$(get_field "name" "$file")"
  version="$(get_field "version" "$file")"
  description="$(get_field_raw "description" "$file")"
  local body
  body="$(get_body "$file")"

  # Write stripped frontmatter + body
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'version: %s\n' "$version"
    # description may be multiline — write as block literal
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$dest_file"

  # Emit per-skill stderr warning only when something was actually stripped
  # (avoids false-positive noise on minimal skills with neither field).
  if fm_has_field "allowed_tools" "$file" || fm_has_field "owns" "$file"; then
    printf '[copilot] stripped allowed_tools/owns from %s\n' "$slug" >&2
  fi

  # Copy references alongside
  refs_src="$(dirname "$file")/references"
  if [[ -d "$refs_src" ]]; then
    mkdir -p "$dest_dir/${slug}-references"
    ats_cp_r "$refs_src" "$dest_dir/${slug}-references"
  fi
}

# ---------------------------------------------------------------------------
# Converter: antigravity
# Generated frontmatter: name, description, risk, source, date_added.
# ---------------------------------------------------------------------------
convert_antigravity() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused but kept for consistent signature
  local category="$2"
  local dest_dir="$OUT_DIR/antigravity/$slug"
  local dest_file="$dest_dir/SKILL.md"
  local description body
  mkdir -p "$dest_dir"

  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"

  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    printf 'risk: low\n'
    printf 'source: alltheskills\n'
    printf "date_added: '%s'\n" "$TODAY"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$dest_file"

  copy_references "$file" "$dest_dir"
}

# ---------------------------------------------------------------------------
# Converter: gemini-cli
# Per-skill: name + description frontmatter. Manifest written once at end.
# ---------------------------------------------------------------------------
convert_gemini_cli() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/gemini-cli/skills/$slug"
  local dest_file="$dest_dir/SKILL.md"
  local description body
  mkdir -p "$dest_dir"

  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"

  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$dest_file"

  copy_references "$file" "$dest_dir"
}

write_gemini_manifest() {
  local manifest="$OUT_DIR/gemini-cli/gemini-extension.json"
  mkdir -p "$OUT_DIR/gemini-cli"
  cat > "$manifest" <<'JSON'
{
  "name": "alltheskills",
  "version": "1.0.0"
}
JSON
}

# ---------------------------------------------------------------------------
# Converter: opencode
# name (original), description, mode=subagent, color=#6B7280
# ---------------------------------------------------------------------------
convert_opencode() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/opencode/agents"
  local dest_file="$dest_dir/${slug}.md"
  local name description body
  mkdir -p "$dest_dir"

  name="$(get_field "name" "$file")"
  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"

  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    printf 'mode: subagent\n'
    printf "color: '#6B7280'\n"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$dest_file"

  # Copy references as <slug>-references/ sibling
  local refs_src
  refs_src="$(dirname "$file")/references"
  if [[ -d "$refs_src" ]]; then
    mkdir -p "$dest_dir/${slug}-references"
    ats_cp_r "$refs_src" "$dest_dir/${slug}-references"
  fi
}

# ---------------------------------------------------------------------------
# Converter: cursor
# description/globs/alwaysApply frontmatter + inline references.
# ---------------------------------------------------------------------------
convert_cursor() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/cursor/rules"
  local dest_file="$dest_dir/${slug}.mdc"
  local description body
  mkdir -p "$dest_dir"

  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"

  {
    printf -- '---\n'
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    printf 'globs: ""\n'
    printf 'alwaysApply: false\n'
    printf -- '---\n'
    printf '%s\n' "$body"
    inline_references "$file"
  } > "$dest_file"
}

# ---------------------------------------------------------------------------
# Converter: openclaw
# Split body by ## headers into SOUL.md / AGENTS.md + IDENTITY.md.
# ---------------------------------------------------------------------------

# Classify a ## header line as "soul" or "agents"
_classify_header() {
  local hdr_lower="$1"
  if echo "$hdr_lower" | grep -qiE '(identity|learning.*memory|communication|style|critical.rule|rules you must follow)'; then
    printf 'soul'
  else
    printf 'agents'
  fi
}

convert_openclaw() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/openclaw/$slug"
  local name description body
  mkdir -p "$dest_dir"

  name="$(get_field "name" "$file")"
  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"

  # --- Split body into SOUL vs AGENTS sections ---
  local soul_tmp agents_tmp
  soul_tmp="$(ats_mktemp_file)"
  agents_tmp="$(ats_mktemp_file)"
  # shellcheck disable=SC2064 # we want current values of soul_tmp/agents_tmp captured now
  trap "rm -f '$soul_tmp' '$agents_tmp'" RETURN

  local current_target="agents"
  local current_section=""
  local has_headers=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]] ]]; then
      has_headers=1
      # Flush previous section
      if [[ -n "$current_section" ]]; then
        if [[ "$current_target" == "soul" ]]; then
          printf '%s' "$current_section" >> "$soul_tmp"
        else
          printf '%s' "$current_section" >> "$agents_tmp"
        fi
      fi
      current_section=""

      local hdr_lower
      hdr_lower="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
      current_target="$(_classify_header "$hdr_lower")"
    fi
    current_section="${current_section}${line}
"
  done <<< "$body"

  # Flush final section
  if [[ -n "$current_section" ]]; then
    if [[ "$current_target" == "soul" ]]; then
      printf '%s' "$current_section" >> "$soul_tmp"
    else
      printf '%s' "$current_section" >> "$agents_tmp"
    fi
  fi

  # Write SOUL.md
  if [[ "$has_headers" -eq 0 ]]; then
    # No headers: put everything in AGENTS, SOUL is a placeholder
    printf '# %s\n' "$name" > "$dest_dir/SOUL.md"
    {
      printf '%s\n' "$body"
    } > "$dest_dir/AGENTS.md"
  else
    local soul_content agents_content
    soul_content="$(cat "$soul_tmp")"
    agents_content="$(cat "$agents_tmp")"

    if [[ -n "$soul_content" ]]; then
      printf '%s\n' "$soul_content" > "$dest_dir/SOUL.md"
    else
      printf '# %s\n' "$name" > "$dest_dir/SOUL.md"
    fi

    {
      if [[ -n "$agents_content" ]]; then
        printf '%s\n' "$agents_content"
      fi
      # Footer for references
      local refs_src
      refs_src="$(dirname "$file")/references"
      if [[ -d "$refs_src" ]]; then
        printf '\n> Additional context: see references/\n'
      fi
    } > "$dest_dir/AGENTS.md"
  fi

  # Write IDENTITY.md — 3-line format with robot emoji (Slice A default)
  {
    printf '# \xf0\x9f\xa4\x96 %s\n' "$name"
    # description on next line, collapsed to one line
    printf '%s\n' "$(get_field "description" "$file")"
  } > "$dest_dir/IDENTITY.md"

  # Copy references
  copy_references "$file" "$dest_dir"
}

# ---------------------------------------------------------------------------
# Converter: qwen
# name, description, optional tools (mapped from allowed_tools).
# Body + inline references.
# ---------------------------------------------------------------------------
convert_qwen() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/qwen/agents"
  local dest_file="$dest_dir/${slug}.md"
  local description body allowed_tools_csv
  mkdir -p "$dest_dir"

  description="$(get_field_raw "description" "$file")"
  body="$(get_body "$file")"
  # Map allowed_tools (comma-separated list from get_field) to qwen's tools field
  allowed_tools_csv="$(get_field "allowed_tools" "$file")"

  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf 'description: |\n'
    while IFS= read -r dline; do
      printf '  %s\n' "$dline"
    done <<< "$description"
    if [[ -n "$allowed_tools_csv" ]]; then
      printf 'tools: %s\n' "$allowed_tools_csv"
    fi
    printf -- '---\n'
    printf '%s\n' "$body"
    inline_references "$file"
  } > "$dest_file"
}

# ---------------------------------------------------------------------------
# Converter: kimi
# agent.yaml + system.md with inline references.
# ---------------------------------------------------------------------------
convert_kimi() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local dest_dir="$OUT_DIR/kimi/$slug"
  local name description body
  mkdir -p "$dest_dir"

  name="$(get_field "name" "$file")"
  description="$(get_field "description" "$file")"
  body="$(get_body "$file")"

  cat > "$dest_dir/agent.yaml" <<YAML
version: 1
agent:
  name: ${slug}
  extend: default
  system_prompt_path: ./system.md
YAML

  {
    printf '# %s\n\n' "$name"
    printf '%s\n\n' "$description"
    printf '%s\n' "$body"
    inline_references "$file"
  } > "$dest_dir/system.md"
}

# ---------------------------------------------------------------------------
# Accumulator: aider
# All skills concatenated into one CONVENTIONS.md.
# ---------------------------------------------------------------------------
AIDER_TMP=''
WINDSURF_TMP=''
AIDER_COUNT=0
WINDSURF_COUNT=0

init_accumulators() {
  AIDER_TMP="$(ats_mktemp_file)"
  WINDSURF_TMP="$(ats_mktemp_file)"

  cat > "$AIDER_TMP" <<'HEADER'
# AllTheSkillsAllTheAgents — Skill Conventions
#
# Generated by scripts/convert.sh — do not edit manually.
# Source: https://github.com/ivy00johns/AllTheSkillsAllTheAgents
#
# To activate a skill in Aider, reference it by name in your prompt, e.g.:
#   "Apply the backend-agent skill to refactor this service."
#
HEADER

  cat > "$WINDSURF_TMP" <<'HEADER'
# AllTheSkillsAllTheAgents — Skill Rules for Windsurf
#
# Generated by scripts/convert.sh — do not edit manually.
#
HEADER
}

finalize_accumulators() {
  if [[ "$_DO_AIDER" == "1" || "$_DO_ALL" == "1" ]]; then
    mkdir -p "$OUT_DIR/aider"
    cp "$AIDER_TMP" "$OUT_DIR/aider/CONVENTIONS.md"
  fi
  if [[ "$_DO_WINDSURF" == "1" || "$_DO_ALL" == "1" ]]; then
    mkdir -p "$OUT_DIR/windsurf"
    cp "$WINDSURF_TMP" "$OUT_DIR/windsurf/.windsurfrules"
  fi
}

accumulate_aider() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local name body

  name="$(get_field "name" "$file")"
  body="$(get_body "$file")"

  {
    printf -- '\n---\n\n'
    printf '## %s\n\n' "$name"
    printf '> %s\n\n' "$(get_field "description" "$file")"
    printf '%s\n' "$body"
  } >> "$AIDER_TMP"

  # Warn about skipped references
  local refs_src
  refs_src="$(dirname "$file")/references"
  if [[ -d "$refs_src" ]]; then
    printf '[aider] skipped references for %s\n' "$slug" >&2
  fi
  AIDER_COUNT=$(( AIDER_COUNT + 1 ))
}

accumulate_windsurf() {
  local file="$1" slug="$3"
  # shellcheck disable=SC2034 # category unused
  local category="$2"
  local name body

  name="$(get_field "name" "$file")"
  body="$(get_body "$file")"

  {
    printf '\n'
    repeat_char '=' 80
    printf '\n## %s\n%s\n' "$name" "$(get_field "description" "$file")"
    repeat_char '=' 80
    printf '\n\n%s\n' "$body"
  } >> "$WINDSURF_TMP"

  # Warn about skipped references
  local refs_src
  refs_src="$(dirname "$file")/references"
  if [[ -d "$refs_src" ]]; then
    printf '[windsurf] skipped references for %s\n' "$slug" >&2
  fi
  WINDSURF_COUNT=$(( WINDSURF_COUNT + 1 ))
}

# ---------------------------------------------------------------------------
# process_skill <file> <tool>
# Dispatch to the correct converter.
# Returns: 0 ok, 1 skip (requires_claude_code + non-cc tool), 2 hard error.
# ---------------------------------------------------------------------------
process_skill() {
  local file="$1" tool="$2"
  local category slug

  derive_category_slug "$file"
  category="$SKILL_CATEGORY"
  slug="$SKILL_SLUG"

  # Check requires_claude_code for non-claude-code tools
  if [[ "$tool" != "claude-code" ]]; then
    local req_cc
    req_cc="$(get_field "requires_claude_code" "$file")"
    if [[ "$req_cc" == "true" ]]; then
      printf '[convert] skipping %s/%s for %s (requires_claude_code: true)\n' \
        "$category" "$slug" "$tool" >&2
      return 1
    fi
  fi

  case "$tool" in
    claude-code)  convert_claude_code  "$file" "$category" "$slug" ;;
    copilot)      convert_copilot      "$file" "$category" "$slug" ;;
    antigravity)  convert_antigravity  "$file" "$category" "$slug" ;;
    gemini-cli)   convert_gemini_cli   "$file" "$category" "$slug" ;;
    opencode)     convert_opencode     "$file" "$category" "$slug" ;;
    cursor)       convert_cursor       "$file" "$category" "$slug" ;;
    openclaw)     convert_openclaw     "$file" "$category" "$slug" ;;
    qwen)         convert_qwen         "$file" "$category" "$slug" ;;
    kimi)         convert_kimi         "$file" "$category" "$slug" ;;
    aider)        accumulate_aider     "$file" "$category" "$slug" ;;
    windsurf)     accumulate_windsurf  "$file" "$category" "$slug" ;;
    *) printf '[convert] ERROR: unknown tool: %s\n' "$tool" >&2; return 2 ;;
  esac
}

# ---------------------------------------------------------------------------
# run_tool <tool>
# Walk all skills for a single tool. Returns counts: processed skipped errors.
# ---------------------------------------------------------------------------
run_tool() {
  local tool="$1"
  local processed=0 skipped=0 errors=0
  local file

  while IFS= read -r file; do
    # Validate frontmatter exists
    if ! fm_check "$file" 2>/dev/null; then
      printf '[convert] ERROR: %s: malformed frontmatter — aborting conversion\n' "$file" >&2
      errors=$(( errors + 1 ))
      continue
    fi

    local name
    name="$(get_field "name" "$file")"
    if [[ -z "$name" ]]; then
      printf '[convert] ERROR: %s: missing required field "name"\n' "$file" >&2
      errors=$(( errors + 1 ))
      continue
    fi

    local rc=0
    process_skill "$file" "$tool" || rc=$?
    case "$rc" in
      0) processed=$(( processed + 1 )) ;;
      1) skipped=$(( skipped + 1 ))   ;;
      *) errors=$(( errors + 1 ))     ;;
    esac
  done < <(collect_skills)

  printf '%s %s %s\n' "$processed" "$skipped" "$errors"
}

# ---------------------------------------------------------------------------
# Parallel worker entry point.
# When ATS_INSTALL_WORKER=1, run a single tool and exit.
# (Used by parallel mode — parent spawns this script per tool.)
# ---------------------------------------------------------------------------
if [[ "${ATS_CONVERT_WORKER:-}" == "1" && -n "${ATS_CONVERT_TOOL:-}" ]]; then
  run_tool "${ATS_CONVERT_TOOL}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local tool="all"
  local use_parallel=false
  local parallel_jobs
  parallel_jobs="$(nproc_count)"
  _DO_ALL=0
  _DO_AIDER=0
  _DO_WINDSURF=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tool)     tool="${2:?'--tool requires a value'}"; shift 2 ;;
      --out)      OUT_DIR="${2:?'--out requires a value'}"; shift 2 ;;
      --parallel) use_parallel=true; shift ;;
      --jobs)     parallel_jobs="${2:?'--jobs requires a value'}"; shift 2 ;;
      --help|-h)  usage ;;
      *)          ats_err "Unknown option: $1"; exit 2 ;;
    esac
  done

  # Validate tool argument
  local valid=false t
  for t in "${ALL_TOOLS[@]}" all; do
    [[ "$t" == "$tool" ]] && valid=true && break
  done
  if ! $valid; then
    ats_err "Unknown tool '$tool'. Valid: ${ALL_TOOLS[*]} all"
    exit 2
  fi

  local tools_to_run=()
  if [[ "$tool" == "all" ]]; then
    tools_to_run=("${ALL_TOOLS[@]}")
    _DO_ALL=1
  else
    tools_to_run=("$tool")
    [[ "$tool" == "aider" ]]    && _DO_AIDER=1
    [[ "$tool" == "windsurf" ]] && _DO_WINDSURF=1
  fi

  # Initialize accumulator temp files (needed before worker dispatch)
  init_accumulators
  trap 'rm -f "$AIDER_TMP" "$WINDSURF_TMP"' EXIT

  ats_header "AllTheSkillsAllTheAgents — Converting skills to tool-specific formats"
  printf '  Repo:    %s\n' "$REPO_ROOT"
  printf '  Output:  %s\n' "$OUT_DIR"
  printf '  Tools:   %s\n' "${tools_to_run[*]}"
  printf '  Date:    %s\n' "$TODAY"
  printf '\n'

  local total_processed=0 total_skipped=0 total_errors=0
  local n_tools=${#tools_to_run[@]}

  if $use_parallel && [[ "${#tools_to_run[@]}" -gt 1 ]]; then
    # Parallel path: spawn one worker per tool.
    # Tools that accumulate (aider, windsurf) must run in the parent process
    # because they write to shared temp files. Run them serially after.
    local parallel_tools=()
    local serial_tools=()
    for t in "${tools_to_run[@]}"; do
      case "$t" in
        aider|windsurf) serial_tools+=("$t") ;;
        *)              parallel_tools+=("$t") ;;
      esac
    done

    local par_out_dir
    par_out_dir="$(ats_mktemp_dir)"

    ats_info "Parallel mode: ${#parallel_tools[@]} tools in parallel, ${#serial_tools[@]} serial (aider/windsurf)"

    if [[ ${#parallel_tools[@]} -gt 0 ]]; then
      # Export context for worker subshells
      export ATS_CONVERT_WORKER=1
      export OUT_DIR SKILLS_ROOT TODAY REPO_ROOT
      local pt
      # Write tool names to a temp file for xargs
      local tools_list
      tools_list="$(ats_mktemp_file)"
      for pt in "${parallel_tools[@]}"; do printf '%s\n' "$pt"; done > "$tools_list"
      # shellcheck disable=SC2016 # xargs shell uses single quotes intentionally
      xargs -P "$parallel_jobs" -I {} sh -c \
        'ATS_CONVERT_TOOL="{}" ATS_CONVERT_WORKER=1 '"$SCRIPT_DIR"'/convert.sh --tool "{}" --out "'"$OUT_DIR"'" > "'"$par_out_dir"'/{}" 2>&1' \
        < "$tools_list"
      rm -f "$tools_list"
      unset ATS_CONVERT_WORKER

      for pt in "${parallel_tools[@]}"; do
        [[ -f "$par_out_dir/$pt" ]] && cat "$par_out_dir/$pt"
      done
      rm -rf "$par_out_dir"
    fi

    for t in "${serial_tools[@]}"; do
      ats_header "Converting: $t"
      local counts
      counts="$(run_tool "$t")"
      local p s e
      p="$(printf '%s' "$counts" | awk '{print $1}')"
      s="$(printf '%s' "$counts" | awk '{print $2}')"
      e="$(printf '%s' "$counts" | awk '{print $3}')"
      total_processed=$(( total_processed + p ))
      total_skipped=$(( total_skipped + s ))
      total_errors=$(( total_errors + e ))
      ats_ok "$t: $p converted, $s skipped, $e errors"
    done
  else
    # Sequential path
    local i=0
    for t in "${tools_to_run[@]}"; do
      (( i++ )) || true
      progress_bar "$i" "$n_tools"
      printf '\n'
      ats_header "Converting: $t ($i/$n_tools)"

      local counts
      counts="$(run_tool "$t")"
      local p s e
      p="$(printf '%s' "$counts" | awk '{print $1}')"
      s="$(printf '%s' "$counts" | awk '{print $2}')"
      e="$(printf '%s' "$counts" | awk '{print $3}')"
      total_processed=$(( total_processed + p ))
      total_skipped=$(( total_skipped + s ))
      total_errors=$(( total_errors + e ))
      ats_ok "$t: $p converted, $s skipped, $e errors"

      # Write gemini manifest after converting gemini-cli
      if [[ "$t" == "gemini-cli" ]]; then
        write_gemini_manifest
        ats_info "Wrote integrations/gemini-cli/gemini-extension.json"
      fi
    done
  fi

  # Finalize accumulated single-file outputs
  finalize_accumulators

  if [[ "$tool" == "all" || "$tool" == "aider" ]]; then
    ats_ok "Wrote integrations/aider/CONVENTIONS.md"
  fi
  if [[ "$tool" == "all" || "$tool" == "windsurf" ]]; then
    ats_ok "Wrote integrations/windsurf/.windsurfrules"
  fi

  # Write gemini manifest when running all (sequential path)
  if [[ "$tool" == "all" ]] && ! $use_parallel; then
    write_gemini_manifest
  fi

  # Stderr summary (contract requirement)
  printf '[convert] processed %d skills across %d tools (%d skipped, %d errors)\n' \
    "$total_processed" "$n_tools" "$total_skipped" "$total_errors" >&2

  if (( total_errors > 0 )); then
    exit 1
  fi
}

main "$@"
