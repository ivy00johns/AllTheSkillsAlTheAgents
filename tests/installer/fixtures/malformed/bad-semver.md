---
name: bad-semver
version: not-a-version
description: Apply bad-semver for lint error testing. This skill has an invalid semver version field.
---

## Overview

This fixture has a version field that does not match the semver pattern X.Y.Z. The lint script must emit an ERROR for the invalid version and exit 1.

The body exceeds fifty words to ensure the only lint finding is the invalid version. This body exists purely to satisfy the word count threshold so tests can isolate the version-error finding from the body-stub warning.
