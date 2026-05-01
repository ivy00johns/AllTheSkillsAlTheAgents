
## Overview

This fixture skill has an intentionally long description that exceeds 800 characters. According to lint-rules.md version 1.1.0, no description length is ever an ERROR. Length checks are WARN-only at every threshold.

## Expected Lint Behavior

The lint script must emit a WARN about the description length and must NOT emit an ERROR. The exit code must be 0 because no errors are present. This fixture body meets the fifty-word minimum for body word count so that test is not a confound.
