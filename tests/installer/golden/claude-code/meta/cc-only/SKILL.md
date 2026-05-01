---
name: cc-only
version: 1.0.0
description: Apply cc-only when testing requires_claude_code skip behavior. This skill must appear in claude-code output and be skipped for all other ten tools with a stderr warning per skip.
requires_claude_code: true
---

## Overview

This fixture skill sets requires_claude_code to true. The converter must include it in claude-code output and skip it for all other tools.

## Expected Behavior

When convert.sh processes this skill for a non-claude-code tool, it must print a stderr line in the form: `[convert] skipping meta/cc-only for <tool> (requires_claude_code: true)`.

When convert.sh processes this skill for claude-code, it must be included normally without any skip warning.

## Test Coverage

The determinism test (04-convert-determinism-and-skip.bats) verifies that running convert.sh twice produces the same output and that exactly ten skip warnings appear — one for each non-claude-code tool — and that the claude-code output directory contains this skill's SKILL.md while no other tool's output directory contains it.
