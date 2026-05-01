#!/usr/bin/env bash
# lib/frontmatter.sh — SKILL.md frontmatter parser for AllTheSkillsAllTheAgents.
#
# Uses Python 3 + PyYAML for correctness on multiline descriptions.
# Provides targeted field-extraction functions that are called individually
# rather than bulk-parsed-and-evaled, avoiding shell eval of arbitrary data.
#
# Public API (all print to stdout):
#   get_field <field> <file>        — scalar field value (whitespace-collapsed)
#   get_field_raw <field> <file>    — scalar field value (newlines preserved)
#   get_array <field> <file>        — one array element per line
#   get_owns_dirs <file>            — owns.directories, one per line
#   get_owns_patterns <file>        — owns.patterns, one per line
#   get_owns_shared <file>          — owns.shared_read, one per line
#   get_body <file>                 — everything after the closing ---
#   fm_raw <file>                   — raw YAML between the two --- markers
#   fm_check <file>                 — exit 1 if frontmatter malformed
#   fm_has_field <field> <file>     — exit 0 if field present, 1 if absent
#
# Usage:
#   . "$(dirname "$0")/lib/frontmatter.sh"

# ---------------------------------------------------------------------------
# get_field <field> <file>
# Print a single scalar field value with whitespace collapsed to one line.
# ---------------------------------------------------------------------------
get_field() {
  local field="$1" file="$2"
  python3 - "$file" "$field" <<'PYEOF'
import sys, re

path = sys.argv[1]
field = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    val = data.get(field)
    if val is None:
        sys.exit(0)
    if isinstance(val, bool):
        print('true' if val else 'false')
    elif isinstance(val, list):
        print(','.join(str(v) for v in val))
    elif isinstance(val, dict):
        pass  # dicts not useful as scalar
    else:
        print(' '.join(str(val).split()))
except ImportError:
    # Hand-rolled fallback for simple scalars only
    for line in fm_text.split('\n'):
        if line.startswith((' ', '\t')):
            continue
        m = re.match(r'^' + re.escape(field) + r':\s*(.*)', line)
        if m:
            val = m.group(1).strip()
            if val in ('|', '>', '>-', '|-'):
                pass  # multiline -- can't parse without yaml
            elif val.startswith(('"', "'")):
                print(val.strip('"\''))
            elif val.lower() in ('true', 'false'):
                print(val.lower())
            else:
                print(val)
            break
PYEOF
}

# ---------------------------------------------------------------------------
# get_field_raw <field> <file>
# Print a scalar field value preserving internal newlines (for description).
# ---------------------------------------------------------------------------
get_field_raw() {
  local field="$1" file="$2"
  python3 - "$file" "$field" <<'PYEOF'
import sys

path = sys.argv[1]
field = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    val = data.get(field)
    if val is None:
        sys.exit(0)
    if isinstance(val, bool):
        print('true' if val else 'false', end='')
    elif isinstance(val, str):
        # Print raw (may include newlines) without trailing newline
        sys.stdout.write(val)
    else:
        sys.stdout.write(str(val))
except ImportError:
    pass
PYEOF
}

# ---------------------------------------------------------------------------
# get_array <field> <file>
# Print each element of a YAML array field, one per line.
# ---------------------------------------------------------------------------
get_array() {
  local field="$1" file="$2"
  python3 - "$file" "$field" <<'PYEOF'
import sys

path = sys.argv[1]
field = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    val = data.get(field)
    if isinstance(val, list):
        for item in val:
            print(str(item))
    elif val is not None:
        print(str(val))
except ImportError:
    pass
PYEOF
}

# ---------------------------------------------------------------------------
# get_owns_dirs / get_owns_patterns / get_owns_shared <file>
# Print owns sub-field elements, one per line.
# ---------------------------------------------------------------------------
get_owns_dirs() {
  local file="$1"
  python3 - "$file" 'directories' <<'PYEOF'
import sys

path = sys.argv[1]
subfield = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    owns = data.get('owns') or {}
    items = owns.get(subfield) or []
    for item in items:
        print(str(item))
except ImportError:
    pass
PYEOF
}

get_owns_patterns() {
  local file="$1"
  python3 - "$file" 'patterns' <<'PYEOF'
import sys

path = sys.argv[1]
subfield = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    owns = data.get('owns') or {}
    items = owns.get(subfield) or []
    for item in items:
        print(str(item))
except ImportError:
    pass
PYEOF
}

get_owns_shared() {
  local file="$1"
  python3 - "$file" 'shared_read' <<'PYEOF'
import sys

path = sys.argv[1]
subfield = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.split('\n')
if not lines or lines[0].rstrip() != '---':
    sys.exit(0)

fm_end = None
for i in range(1, len(lines)):
    if lines[i].rstrip() == '---':
        fm_end = i
        break
if fm_end is None:
    sys.exit(0)

fm_text = '\n'.join(lines[1:fm_end])

try:
    import yaml
    data = yaml.safe_load(fm_text) or {}
    owns = data.get('owns') or {}
    items = owns.get(subfield) or []
    for item in items:
        print(str(item))
except ImportError:
    pass
PYEOF
}

# ---------------------------------------------------------------------------
# get_body <file>
# Print everything after the closing --- of the frontmatter block.
# ---------------------------------------------------------------------------
get_body() {
  local file="$1"
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$file"
}

# ---------------------------------------------------------------------------
# fm_raw <file>
# Print the raw YAML text between the two --- markers (no delimiters).
# ---------------------------------------------------------------------------
fm_raw() {
  local file="$1"
  awk 'NR==1{next} /^---$/{exit} {print}' "$file"
}

# ---------------------------------------------------------------------------
# fm_check <file>
# Return 0 if frontmatter is well-formed; print error and return 1 if not.
# ---------------------------------------------------------------------------
fm_check() {
  local file="$1"
  local first_line found line_num
  first_line=$(head -1 "$file")
  if [[ "$first_line" != "---" ]]; then
    printf '[frontmatter] ERROR: %s: missing opening ---\n' "$file" >&2
    return 1
  fi
  found=0
  line_num=0
  while IFS= read -r line; do
    (( line_num++ )) || true
    if (( line_num == 1 )); then continue; fi
    if [[ "$line" == "---" ]]; then found=1; break; fi
    if (( line_num > 100 )); then break; fi
  done < "$file"
  if (( found == 0 )); then
    printf '[frontmatter] ERROR: %s: no closing --- within 100 lines\n' "$file" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# fm_has_field <field> <file>
# Return 0 if the field is present and non-empty in frontmatter, 1 otherwise.
# ---------------------------------------------------------------------------
fm_has_field() {
  local field="$1" file="$2" val
  val=$(get_field "$field" "$file")
  [[ -n "$val" ]]
}
