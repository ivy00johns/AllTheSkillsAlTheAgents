---
version: 1.0.0
description: Apply missing-name for lint error testing. This skill has no name field.
---

## Overview

This fixture is missing the required name field. The lint script must emit an ERROR and exit 1.

The body word count exceeds fifty words to ensure the only lint finding is the missing name field. This body exists purely to pad the word count above the threshold so tests can isolate the name-missing error from the body-stub warning.
