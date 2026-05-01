---
name: minimal-agent
description: |
  Apply minimal-agent when you need a baseline role skill with only required fields for testing convert and lint tools.
---

## Overview

This is a minimal fixture skill used by the installer test suite. It contains only the three required frontmatter fields: name, version, and description.

## Purpose

When the installer test suite runs convert.sh against this fixture, every per-tool converter must produce output using only the required fields. No owns block, no allowed_tools list, no composes_with.

## Behavior

The converter reads the three required fields and emits tool-specific output. Because no agent-role optional fields are present, no stripping warnings are expected for this skill on any tool.

This body is intentionally kept short but above the fifty-word threshold so lint passes cleanly.
