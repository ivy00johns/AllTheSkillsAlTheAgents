---
name: long-desc
description: |
  Apply long-desc when testing that description length above 500 characters produces only a WARN and never an ERROR. Use this skill whenever you need to verify the lint contract version 1.1.0 change that demoted all length checks to WARN-only. This description is intentionally verbose to exceed the 500-character threshold. It continues here with additional trigger context keywords — when converting skills, for validating lint rules, whenever checking description length enforcement, if you need to confirm that long descriptions do not block CI. The description keeps going to ensure it crosses the 800-character mark for a thorough test of the WARN-only behavior. Adding more words here to ensure the total collapsed character count is well above the 500-char soft threshold and approaching the 800-char advisory level.
---

## Overview

This fixture skill has an intentionally long description that exceeds 800 characters. According to lint-rules.md version 1.1.0, no description length is ever an ERROR. Length checks are WARN-only at every threshold.

## Expected Lint Behavior

The lint script must emit a WARN about the description length and must NOT emit an ERROR. The exit code must be 0 because no errors are present. This fixture body meets the fifty-word minimum for body word count so that test is not a confound.
