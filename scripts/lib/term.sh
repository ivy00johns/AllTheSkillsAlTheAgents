#!/usr/bin/env bash
# lib/term.sh — Terminal / color helpers for AllTheSkillsAllTheAgents scripts.
#
# Source this file; it sets COLOR vars and defines logging + box-drawing funcs.
# Respects NO_COLOR and TERM=dumb.  Only emits ANSI when stdout is a TTY.
#
# Usage:
#   . "$(dirname "$0")/lib/term.sh"

# ---------------------------------------------------------------------------
# Color setup
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # C_* vars exported for use by sourcing scripts (install.sh TUI, etc.)
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[0;31m'
  C_CYAN=$'\033[0;36m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
  C_CYAN=''
  C_BOLD=''
  C_DIM=''
  C_RESET=''
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
ats_ok()     { printf '%s[OK]%s  %s\n'  "${C_GREEN}"  "${C_RESET}" "$*"; }
ats_warn()   { printf '%s[!!]%s  %s\n'  "${C_YELLOW}" "${C_RESET}" "$*"; }
ats_err()    { printf '%s[ERR]%s %s\n'  "${C_RED}"    "${C_RESET}" "$*" >&2; }
ats_info()   { printf '%s[--]%s  %s\n'  "${C_DIM}"    "${C_RESET}" "$*"; }
ats_header() { printf '\n%s%s%s\n'       "${C_BOLD}"   "$*"         "${C_RESET}"; }
ats_dim()    { printf '%s%s%s\n'         "${C_DIM}"    "$*"         "${C_RESET}"; }

# ---------------------------------------------------------------------------
# strip_ansi <string>
# Remove ANSI escape sequences for accurate length measurement.
# ---------------------------------------------------------------------------
strip_ansi() {
  # shellcheck disable=SC2016 # awk uses single-quoted strings; $ is awk syntax
  printf '%s' "$1" | awk '{ gsub(/\033\[[0-9;]*m/, ""); printf "%s", $0 }'
}

# ---------------------------------------------------------------------------
# Box drawing — pure ASCII, fixed BOX_INNER-char wide (no Unicode box chars).
# BOX_INNER = inner content width (between the two | walls), default 50.
# ---------------------------------------------------------------------------
BOX_INNER=${BOX_INNER:-50}

box_top() {
  local i; printf '  +'
  for (( i=0; i<BOX_INNER; i++ )); do printf '-'; done
  printf '+\n'
}
box_bot() { box_top; }

box_sep() {
  local i; printf '  +'
  for (( i=0; i<BOX_INNER; i++ )); do printf '-'; done
  printf '+\n'
}

# box_row <text>  — content row, right-padded to BOX_INNER width.
box_row() {
  local raw="$1"
  local visible
  visible="$(strip_ansi "$raw")"
  local content_len=${#visible}
  local pad=$(( BOX_INNER - 2 - content_len ))
  if (( pad < 0 )); then pad=0; fi
  printf '  | %s%*s |\n' "$raw" "$pad" ''
}

box_blank() {
  local i; printf '  |'
  for (( i=0; i<BOX_INNER; i++ )); do printf ' '; done
  printf '|\n'
}

# ---------------------------------------------------------------------------
# progress_bar <current> <total> [width]
# tqdm-style progress bar.  Safe to call when not a TTY (adds newline).
# ---------------------------------------------------------------------------
progress_bar() {
  local current="$1" total="$2" width="${3:-20}"
  local i filled empty
  (( total > 0 )) || return 0
  filled=$(( width * current / total ))
  empty=$(( width - filled ))
  printf '\r  ['
  for (( i=0; i<filled; i++ )); do printf '='; done
  if (( filled < width )); then printf '>'; (( empty > 0 )) && (( empty-- )) || true; fi
  for (( i=0; i<empty; i++ )); do printf ' '; done
  printf '] %s/%s' "$current" "$total"
  if [[ ! -t 1 ]]; then printf '\n'; fi
}
