#!/usr/bin/env bash
# hitl-loop.template.sh — last-resort human-in-the-loop feedback loop.
#
# Use this only when none of the ten automated loop recipes in
# references/feedback-loop-recipes.md are reachable (physical hardware,
# paid third-party UI, manual approval gate, etc.).
#
# The agent fills in three placeholders:
#   SETUP_LINE        — one shell line that prepares the system to fail
#   USER_INSTRUCTION  — what the human needs to do (printed for them)
#   CHECK_LINE        — one shell line that exits 0 on pass, 1 on fail
#
# The script loops: prompt the human, wait for them to press enter,
# run the check, print PASS/FAIL, then exit with that status so a
# bisect or outer loop can consume the signal.

set -euo pipefail

# --- agent fills these in -----------------------------------------------------

SETUP_LINE='echo "TODO: replace with one-line setup, e.g.: ./bin/reset-test-db"'
USER_INSTRUCTION='TODO: replace with the manual step the human must perform,
e.g.: "Tap the physical card reader with the test card, wait for the beep, then press Enter."'
CHECK_LINE='echo "TODO: replace with a one-line check that exits 0 on pass, 1 on fail, e.g.: grep -q SUCCESS /var/log/reader.log"'

# --- harness ------------------------------------------------------------------

echo "===== diagnose-loop: human-in-the-loop harness ====="
echo "[setup] $SETUP_LINE"
eval "$SETUP_LINE"

echo
echo "----- human step -----"
echo "$USER_INSTRUCTION"
echo "----------------------"
read -r -p "Press Enter when the step is complete (or Ctrl-C to abort)..." _

echo "[check] $CHECK_LINE"
if eval "$CHECK_LINE"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
