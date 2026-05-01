#!/usr/bin/env bash
#
# lint-skills.sh — Validate all skills/**/SKILL.md files.
#
# Checks frontmatter schema, body quality, and cross-skill invariants.
# This is the CI gate — errors block PR merges.
#
# Usage:
#   scripts/lint-skills.sh [OPTIONS] [PATH ...]
#
# Options:
#   --quiet          Suppress WARN output
#   --verbose        Show INFO output
#   --fix-trivial    Auto-fix trivial issues (prompts before each fix)
#   --format FORMAT  Output format: text (default) or junit
#   --help           Print this and exit
#
# PATH may be a directory (recurse) or an individual SKILL.md.
# If no PATH given, lints all skills/**/SKILL.md.
#
# Exit codes: 0 no errors, 1 at least one error, 2 argument failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=scripts/lib/term.sh
. "$LIB_DIR/term.sh"
# shellcheck source=scripts/lib/frontmatter.sh
. "$LIB_DIR/frontmatter.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="$REPO_ROOT/skills"

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------
QUIET=false
VERBOSE=false
# shellcheck disable=SC2034  # FIX_TRIVIAL: reserved for future auto-fix implementation
FIX_TRIVIAL=false
FORMAT="text"
LINT_PATHS=()

# ---------------------------------------------------------------------------
# Issue tracking
# ---------------------------------------------------------------------------
ERRORS=()    # "FILE:LINE:MESSAGE"
WARNS=()
INFOS=()

record_error() { ERRORS+=("$1"); }
record_warn()  { WARNS+=("$1"); }
record_info()  { INFOS+=("$1"); }

# emit_issue <severity> <file> [line] <message>
emit_issue() {
  local sev="$1" file="$2" line_or_msg="$3"
  local msg="${4:-}"
  local line=""

  if [[ -n "$msg" ]]; then
    line="$line_or_msg"
  else
    msg="$line_or_msg"
  fi

  local loc="$file"
  [[ -n "$line" ]] && loc="${file}:${line}"

  case "$sev" in
    ERROR) record_error "${loc}:${msg}" ;;
    WARN)  record_warn  "${loc}:${msg}" ;;
    INFO)  record_info  "${loc}:${msg}" ;;
  esac
}

# ---------------------------------------------------------------------------
# YAML-aware python3 parser for lint checks
# ---------------------------------------------------------------------------
_lint_py3() {
  local file="$1"
  python3 - "$file" <<'PYEOF'
import sys, json, re

path = sys.argv[1]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
result = {
    "ok": False,
    "error": None,
    "fm_end_line": None,
    "data": {},
    "body_lines": [],
    "body_word_count": 0,
}

# Check opening ---
if not lines or lines[0].rstrip() != '---':
    result["error"] = "missing opening ---"
    print(json.dumps(result))
    sys.exit(0)

fm_end = None
for i in range(1, min(101, len(lines))):
    if lines[i].rstrip() == '---':
        fm_end = i
        break

if fm_end is None:
    result["error"] = "no closing --- within 100 lines"
    print(json.dumps(result))
    sys.exit(0)

result["fm_end_line"] = fm_end + 1  # 1-based

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    try:
        data = yaml.safe_load(fm_text) or {}
    except yaml.YAMLError as e:
        result["error"] = f"YAML parse error: {e}"
        print(json.dumps(result))
        sys.exit(0)
except ImportError:
    result["error"] = "install python3 pyyaml for full YAML validation"
    print(json.dumps(result))
    sys.exit(0)

result["ok"] = True
result["data"] = data

# Body analysis
body_lines = lines[fm_end + 1:]
result["body_lines"] = body_lines
result["body_word_count"] = len(' '.join(body_lines).split())
result["body_line_count"] = len([l for l in body_lines if l.strip()])

# Description char count (collapsed)
desc = data.get('description', '')
if isinstance(desc, str):
    result["desc_len"] = len(' '.join(desc.split()))
else:
    result["desc_len"] = 0

# Check if description starts with action verb (first 5 words)
action_verbs = {
    'use', 'apply', 'generate', 'validate', 'coordinate', 'author', 'review',
    'audit', 'create', 'build', 'analyze', 'check', 'extract', 'prepare',
    'design', 'manage', 'track', 'convert', 'install', 'lint', 'fix',
    'refactor', 'test', 'run', 'write', 'read', 'update', 'set', 'add',
    'remove', 'deploy', 'debug', 'implement', 'scaffold', 'plan', 'parse',
    'emit', 'walk', 'scan', 'detect', 'verify', 'enforce', 'produce',
    'output', 'sync', 'migrate', 'query', 'clean', 'prune', 'stage',
    'commit', 'push', 'pull', 'merge', 'rebase', 'branch', 'tag',
    'profile', 'monitor', 'alert', 'log', 'trace', 'instrument', 'bootstrap',
    'configure', 'format', 'render', 'compile', 'bundle', 'optimize',
    'benchmark', 'measure', 'report', 'summarize', 'document', 'draft',
    'lead', 'coordinate', 'orchestrate', 'spawn', 'dispatch', 'gate',
    'consolidate', 'research', 'improve', 'deep', 'guide', 'chart',
}
first_words = ' '.join(desc.split()).split()[:5]
first_words_lower = [w.lower().strip('.,;:!?') for w in first_words]
result["has_action_verb"] = any(w in action_verbs for w in first_words_lower)

# Check trigger context hint (when/for/whenever/if)
result["has_trigger_context"] = bool(re.search(r'\b(when|for|whenever|if)\b', desc, re.IGNORECASE))

print(json.dumps(result))
PYEOF
}

# ---------------------------------------------------------------------------
# Collect SKILL.md files to lint
# ---------------------------------------------------------------------------
collect_files() {
  if [[ ${#LINT_PATHS[@]} -eq 0 ]]; then
    find "$SKILLS_ROOT" -name "SKILL.md" -type f | sort
    return
  fi
  local p
  for p in "${LINT_PATHS[@]}"; do
    if [[ -f "$p" ]]; then
      printf '%s\n' "$p"
    elif [[ -d "$p" ]]; then
      find "$p" -name "SKILL.md" -type f | sort
    else
      printf '%s: not a file or directory\n' "$p" >&2
    fi
  done | sort -u
}

# ---------------------------------------------------------------------------
# lint_one <file>
# ---------------------------------------------------------------------------
lint_one() {
  local file="$1"

  # Basic file check
  if [[ ! -f "$file" ]]; then
    emit_issue ERROR "$file" "" "file not found"
    return
  fi

  # Run python3 analysis
  local json_out
  json_out="$(_lint_py3 "$file")"
  if [[ -z "$json_out" ]]; then
    emit_issue ERROR "$file" "" "python3 lint helper returned no output"
    return
  fi

  # Extract fields via python3 json parsing (avoids jq dependency)
  local ok fm_error fm_end_line desc_len body_wc body_lc has_verb has_trigger
  ok="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['ok'])")"
  fm_error="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['error'] or '')" 2>/dev/null || echo '')"

  if [[ "$ok" != "True" ]]; then
    emit_issue ERROR "$file" "1" "$fm_error"
    return
  fi

  fm_end_line="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['fm_end_line'])")"
  desc_len="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('desc_len',0))")"
  body_wc="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['body_word_count'])")"
  body_lc="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body_line_count',0))")"
  has_verb="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('has_action_verb',False))")"
  has_trigger="$(printf '%s' "$json_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('has_trigger_context',False))")"

  # Derive slug and category from path
  local skill_dir slug category
  skill_dir="$(dirname "$file")"
  slug="$(basename "$skill_dir")"
  local parent_dir
  parent_dir="$(basename "$(dirname "$skill_dir")")"
  if [[ "$parent_dir" == "skills" ]]; then
    category="$slug"
  else
    category="$parent_dir"
  fi

  # ---------------------------------------------------------------------------
  # Required field: name
  # ---------------------------------------------------------------------------
  local name
  name="$(get_field "name" "$file")"
  if [[ -z "$name" ]]; then
    emit_issue ERROR "$file" "1" "required field 'name' is missing or empty"
  else
    # kebab-case check
    if ! printf '%s' "$name" | grep -qE '^[a-z][a-z0-9-]*$'; then
      emit_issue ERROR "$file" "1" "name '$name' is not kebab-case (must match ^[a-z][a-z0-9-]*$)"
    fi
    # length check
    if (( ${#name} > 64 )); then
      emit_issue ERROR "$file" "1" "name '$name' exceeds 64 characters"
    fi
    # name must match directory
    if [[ "$name" != "$slug" ]]; then
      emit_issue ERROR "$file" "1" "name '$name' does not match directory '$slug'"
    fi
  fi

  # ---------------------------------------------------------------------------
  # Required field: version
  # ---------------------------------------------------------------------------
  local version
  version="$(get_field "version" "$file")"
  if [[ -z "$version" ]]; then
    emit_issue ERROR "$file" "1" "required field 'version' is missing or empty"
  elif ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    emit_issue ERROR "$file" "1" "version '$version' is not valid semver (expected X.Y.Z)"
  fi

  # ---------------------------------------------------------------------------
  # Required field: description
  # ---------------------------------------------------------------------------
  if (( desc_len == 0 )); then
    emit_issue ERROR "$file" "1" "required field 'description' is missing or empty"
  elif (( desc_len > 500 )); then
    emit_issue WARN "$file" "" "description is ${desc_len} chars (consider whether some trigger context belongs in body/references)"
  elif (( desc_len > 200 )); then
    emit_issue WARN "$file" "" "description is ${desc_len} chars (soft target ≤200; pushy descriptions are OK per CLAUDE.md)"
  fi

  # ---------------------------------------------------------------------------
  # Body: must exist
  # ---------------------------------------------------------------------------
  if (( body_wc == 0 )); then
    emit_issue ERROR "$file" "$(( fm_end_line + 1 ))" "body is empty (≥1 non-frontmatter line required)"
  elif (( body_wc < 50 )); then
    emit_issue WARN "$file" "" "body is ${body_wc} words (likely a stub; target ≥50)"
  fi

  # Body line count
  if (( body_lc > 500 )); then
    emit_issue WARN "$file" "" "body is ${body_lc} non-blank lines (target ≤500; move detail to references/)"
  fi

  # ---------------------------------------------------------------------------
  # Description quality heuristics (WARN)
  # ---------------------------------------------------------------------------
  if [[ "$has_verb" != "True" ]]; then
    emit_issue WARN "$file" "" "description may not start with an action verb (check first 5 words)"
  fi
  if [[ "$has_trigger" != "True" ]]; then
    emit_issue WARN "$file" "" "description lacks a trigger context (consider adding 'when', 'for', 'if', or 'whenever')"
  fi

  # ---------------------------------------------------------------------------
  # Recommended fields for role skills
  # ---------------------------------------------------------------------------
  if [[ "$category" == "roles" ]]; then
    local owns_dirs
    owns_dirs="$(get_owns_dirs "$file")"
    if [[ -z "$owns_dirs" ]]; then
      emit_issue WARN "$file" "" "role skill missing recommended 'owns.directories' (agent roles need exclusive ownership)"
    fi

    local allowed_tools
    allowed_tools="$(get_field "allowed_tools" "$file")"
    if [[ -z "$allowed_tools" ]]; then
      emit_issue WARN "$file" "" "role skill missing recommended 'allowed_tools' (prevents agents reaching outside their domain)"
    fi
  fi

  # composes_with recommended for all
  local composes_with_val
  composes_with_val="$(get_field "composes_with" "$file")"
  if [[ -z "$composes_with_val" ]]; then
    emit_issue WARN "$file" "" "missing recommended 'composes_with' (helps orchestrator understand skill relationships)"
  fi
}

# ---------------------------------------------------------------------------
# Cross-skill validation (requires all files)
# ---------------------------------------------------------------------------
cross_validate() {
  local files=("$@")

  # Build name→file map and collect owns.directories
  # Use temp files (bash 3.2 has no associative arrays)
  local name_map_file
  name_map_file="$(mktemp "${TMPDIR:-/tmp}/ats-lint-names.XXXXXX")"
  local owns_map_file
  owns_map_file="$(mktemp "${TMPDIR:-/tmp}/ats-lint-owns.XXXXXX")"
  # shellcheck disable=SC2064 # capture current values of temp files
  trap "rm -f '$name_map_file' '$owns_map_file'" RETURN

  local f name owns_dirs dir

  # First pass: collect names and ownership
  for f in "${files[@]}"; do
    name="$(get_field "name" "$f")"
    [[ -z "$name" ]] && continue
    # Append "name TAB file" to map
    printf '%s\t%s\n' "$name" "$f" >> "$name_map_file"

    owns_dirs="$(get_owns_dirs "$f")"
    if [[ -n "$owns_dirs" ]]; then
      while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        printf '%s\t%s\n' "$dir" "$f" >> "$owns_map_file"
      done <<< "$owns_dirs"
    fi
  done

  # Check name uniqueness
  while IFS= read -r name; do
    local count
    count="$(grep -c "^${name}	" "$name_map_file" || true)"
    if (( count > 1 )); then
      local files_with_name
      files_with_name="$(grep "^${name}	" "$name_map_file" | awk -F'\t' '{print $2}' | tr '\n' ' ')"
      emit_issue ERROR "(cross-skill)" "" "name '$name' is not unique: $files_with_name"
    fi
  done < <(awk -F'\t' '{print $1}' "$name_map_file" | sort | uniq)

  # Check owns.directories uniqueness (no overlap between role skills)
  while IFS= read -r dir; do
    local count
    count="$(grep -c "^${dir}	" "$owns_map_file" || true)"
    if (( count > 1 )); then
      local owners
      owners="$(grep "^${dir}	" "$owns_map_file" | awk -F'\t' '{print $2}' | tr '\n' ' ')"
      emit_issue ERROR "(cross-skill)" "" "owns.directories '$dir' claimed by multiple skills: $owners"
    fi
  done < <(awk -F'\t' '{print $1}' "$owns_map_file" | sort | uniq)

  # Check composes_with references exist
  local all_names
  all_names="$(awk -F'\t' '{print $1}' "$name_map_file" | sort)"

  for f in "${files[@]}"; do
    while IFS= read -r ref_name; do
      [[ -z "$ref_name" ]] && continue
      if ! printf '%s\n' "$all_names" | grep -qxF "$ref_name"; then
        emit_issue WARN "$f" "" "composes_with references unknown skill '$ref_name'"
      fi
    done < <(get_array "composes_with" "$f")

    while IFS= read -r ref_name; do
      [[ -z "$ref_name" ]] && continue
      if ! printf '%s\n' "$all_names" | grep -qxF "$ref_name"; then
        emit_issue WARN "$f" "" "spawned_by references unknown skill '$ref_name'"
      fi
    done < <(get_array "spawned_by" "$f")
  done
}

# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

# Print issues in text format to stdout
print_text_report() {
  local n_files="$1"
  local n_errors=${#ERRORS[@]}
  local n_warns=${#WARNS[@]}

  printf 'Linting %s skills...\n\n' "$n_files"

  local issue
  for issue in "${ERRORS[@]+"${ERRORS[@]}"}"; do
    local loc msg
    # Split on last colon-prefixed message: "file:line:msg" or "file:msg"
    # We stored as "loc:msg" with loc possibly containing ":"
    # Strategy: last field after ":" is the message if it starts uppercase, else join
    msg="${issue##*:}"
    loc="${issue%:*}"
    printf '%-6s %s  %s\n' 'ERROR' "$loc" "$msg"
  done

  if ! $QUIET; then
    for issue in "${WARNS[@]+"${WARNS[@]}"}"; do
      msg="${issue##*:}"
      loc="${issue%:*}"
      printf '%-6s %s  %s\n' 'WARN' "$loc" "$msg"
    done
  fi

  if $VERBOSE; then
    for issue in "${INFOS[@]+"${INFOS[@]}"}"; do
      msg="${issue##*:}"
      loc="${issue%:*}"
      printf '%-6s %s  %s\n' 'INFO' "$loc" "$msg"
    done
  fi

  printf '\nResults: %d error(s), %d warning(s) across %d skills.\n' \
    "$n_errors" "$n_warns" "$n_files"

  if (( n_errors > 0 )); then
    printf 'FAILED: fix the errors above before merging.\n'
  else
    printf 'PASSED\n'
  fi
}

# Print issues in JUnit XML format to stdout
print_junit_report() {
  local n_files="$1"
  local n_errors=${#ERRORS[@]}

  printf '<?xml version="1.0" encoding="UTF-8"?>\n'
  printf '<testsuites name="skill-lint" tests="%s" failures="%s" errors="0">\n' \
    "$n_files" "$n_errors"

  # Group by file
  local all_issues=()
  local issue
  for issue in "${ERRORS[@]+"${ERRORS[@]}"}"; do
    all_issues+=("ERROR:$issue")
  done
  if ! $QUIET; then
    for issue in "${WARNS[@]+"${WARNS[@]}"}"; do
      all_issues+=("WARN:$issue")
    done
  fi

  # Collect unique files mentioned
  local files_seen=()
  for issue in "${all_issues[@]+"${all_issues[@]}"}"; do
    local raw="${issue#*:}"
    local loc="${raw%:*}"
    # strip line number if present (loc might be "file:lineno")
    local fpart
    fpart="$(printf '%s' "$loc" | sed 's/:[0-9]*$//')"
    local already=false fs
    for fs in "${files_seen[@]+"${files_seen[@]}"}"; do
      [[ "$fs" == "$fpart" ]] && already=true && break
    done
    $already || files_seen+=("$fpart")
  done

  local fpart
  for fpart in "${files_seen[@]+"${files_seen[@]}"}"; do
    local suite_name="${fpart#"$REPO_ROOT"/}"
    local f_errors=0 f_warns=0
    for issue in "${ERRORS[@]+"${ERRORS[@]}"}"; do
      [[ "$issue" == "${fpart}"* ]] && f_errors=$(( f_errors + 1 ))
    done
    for issue in "${WARNS[@]+"${WARNS[@]}"}"; do
      [[ "$issue" == "${fpart}"* ]] && f_warns=$(( f_warns + 1 ))
    done
    local f_tests=$(( f_errors + f_warns ))
    (( f_tests == 0 )) && f_tests=1

    printf '  <testsuite name="%s" tests="%s" failures="%s">\n' \
      "$suite_name" "$f_tests" "$f_errors"

    for issue in "${ERRORS[@]+"${ERRORS[@]}"}"; do
      if [[ "$issue" == "${fpart}"* ]]; then
        local msg="${issue##*:}"
        local loc="${issue%:*}"
        local lineno="${loc##*:}"
        [[ "$lineno" =~ ^[0-9]+$ ]] || lineno=""
        printf '    <testcase classname="frontmatter" name="%s">\n' \
          "$(printf '%s' "$msg" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g')"
        printf '      <failure message="%s"/>\n' \
          "$(printf '%s' "$msg" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g')"
        printf '    </testcase>\n'
      fi
    done

    printf '  </testsuite>\n'
  done

  printf '</testsuites>\n'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
usage() {
  sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet)        QUIET=true; shift ;;
      --verbose)      VERBOSE=true; shift ;;
      --fix-trivial)  FIX_TRIVIAL=true; shift ;;  # future: implement trivial auto-fixes
      --format)       FORMAT="${2:?'--format requires a value'}"; shift 2 ;;
      --help|-h)      usage ;;
      -*)             ats_err "Unknown option: $1"; exit 2 ;;
      *)              LINT_PATHS+=("$1"); shift ;;
    esac
  done

  case "$FORMAT" in
    text|junit) ;;
    *) ats_err "Unknown format '$FORMAT'. Use: text or junit"; exit 2 ;;
  esac

  # Collect files
  local files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(collect_files)

  if [[ ${#files[@]} -eq 0 ]]; then
    printf 'No SKILL.md files found.\n' >&2
    exit 1
  fi

  # Per-skill lint (--fix-trivial is reserved for a future interactive pass)
  if $FIX_TRIVIAL; then
    ats_warn "--fix-trivial: auto-fix not yet implemented; running lint-only"
  fi
  local f
  for f in "${files[@]}"; do
    lint_one "$f"
  done

  # Cross-skill checks
  cross_validate "${files[@]}"

  local n_errors=${#ERRORS[@]}
  local n_files=${#files[@]}

  # Print report
  if [[ "$FORMAT" == "junit" ]]; then
    print_junit_report "$n_files"
  else
    print_text_report "$n_files"
  fi

  if (( n_errors > 0 )); then
    exit 1
  fi
  exit 0
}

main "$@"
