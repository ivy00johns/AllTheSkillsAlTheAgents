---
name: wrong-name
version: 1.0.0
description: Apply name-mismatch for lint error testing. This skill declares name wrong-name but will be placed in a directory that does not match.
---

## Overview

This fixture's name field does not match its containing directory. The lint script must emit an ERROR because the name must equal the basename of the skill directory.

The body exceeds fifty words to ensure the only lint finding is the name-mismatch error. This body exists purely to satisfy the word count threshold so tests can isolate the name-mismatch error finding from the body-stub warning.
