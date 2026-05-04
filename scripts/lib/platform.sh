#!/usr/bin/env bash
# lib/platform.sh — Cross-platform shims for AllTheSkillsAllTheAgents scripts.
#
# Provides: nproc_count (portable nproc), portable mktemp, portable cp -r.
#
# Usage:
#   . "$(dirname "$0")/lib/platform.sh"

# ---------------------------------------------------------------------------
# nproc_count — portable CPU core count.
# Returns nproc on Linux, sysctl on macOS, fallback 4.
# ---------------------------------------------------------------------------
nproc_count() {
  local n
  n=$(nproc 2>/dev/null) && [[ -n "$n" ]] && echo "$n" && return
  n=$(sysctl -n hw.ncpu 2>/dev/null) && [[ -n "$n" ]] && echo "$n" && return
  echo 4
}

# ---------------------------------------------------------------------------
# ats_mktemp_dir — portable temp dir.
# macOS mktemp requires a template argument for -d.
# ---------------------------------------------------------------------------
ats_mktemp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/ats.XXXXXX"
}

# ---------------------------------------------------------------------------
# ats_mktemp_file — portable temp file.
# ---------------------------------------------------------------------------
ats_mktemp_file() {
  mktemp "${TMPDIR:-/tmp}/ats.XXXXXX"
}

# ---------------------------------------------------------------------------
# ats_cp_r <src> <dst> — portable recursive copy.
# On macOS, cp -r <src>/ <dst>/ copies contents (not the dir itself).
# We normalize to: copy contents of src/ into dst/.
# ---------------------------------------------------------------------------
ats_cp_r() {
  local src="$1" dst="$2"
  # Ensure trailing slash so cp copies contents, not the directory node itself
  src="${src%/}/"
  mkdir -p "$dst"
  # BSD and GNU cp both handle this form correctly
  cp -r "$src." "$dst/"
}
