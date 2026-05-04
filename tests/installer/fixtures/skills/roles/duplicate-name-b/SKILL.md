---
name: collision-test
version: 1.0.0
description: Apply collision-test for testing the lint duplicate-name cross-skill check. This skill and duplicate-name-a intentionally share the same name value to trigger an ERROR.
---

## Overview

This is the second of two fixture skills that share the name collision-test. The lint cross-skill validator must detect that two different directories both declare name: collision-test and emit an ERROR for the duplicate.

## Expected Lint Output

The lint script should emit an error similar to: ERROR (cross-skill) name 'collision-test' is not unique. The error must reference both skill files. The exit code must be 1.

This fixture body meets the fifty-word minimum so the only lint finding is the cross-skill name collision, not any per-skill body warning.
