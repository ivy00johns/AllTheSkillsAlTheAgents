#!/usr/bin/env python3
"""Bulk skill audit - parse all frontmatter + body stats."""
import os
import re
import json
import yaml
import glob
from pathlib import Path

SKILLS_DIR = "/Users/johns/Repos/the-hive-ecosystem/Skill-Madness/skills"
ROOT = "/Users/johns/Repos/the-hive-ecosystem/Skill-Madness"

skill_files = []
for path in sorted(Path(SKILLS_DIR).rglob("SKILL.md")):
    if "/archive/" in str(path):
        continue
    skill_files.append(str(path))

FIELD_ORDER = [
    "name", "version", "description", "compatibility", "license",
    "allowed-tools", "allowed_tools", "metadata",
    "requires_agent_teams", "requires_claude_code", "min_plan",
    "owns", "composes_with", "spawned_by"
]

skills = []
all_names = set()

for path in skill_files:
    with open(path, "r") as f:
        content = f.read()

    if not content.startswith("---"):
        skills.append({"path": path, "error": "no frontmatter"})
        continue

    parts = content.split("---", 2)
    if len(parts) < 3:
        skills.append({"path": path, "error": "malformed frontmatter"})
        continue

    fm_text = parts[1]
    body = parts[2]

    try:
        fm = yaml.safe_load(fm_text)
    except Exception as e:
        skills.append({"path": path, "error": f"yaml parse fail: {e}"})
        continue

    raw_field_order = []
    for line in fm_text.split("\n"):
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_\-]*?):", line)
        if m:
            raw_field_order.append(m.group(1))

    name = fm.get("name", "")
    all_names.add(name)
    if path.endswith("/skills/orchestrator/SKILL.md"):
        category = "orchestrator"
    else:
        category = Path(path).parent.parent.name

    desc = fm.get("description", "")
    desc_len = len(desc) if isinstance(desc, str) else 0

    body_lines = len(body.split("\n"))
    body_words = len(body.strip().split())

    ref_dir = Path(path).parent / "references"
    ref_files = []
    if ref_dir.exists():
        ref_files = [str(f.relative_to(ref_dir)) for f in ref_dir.rglob("*") if f.is_file()]

    body_ref_links = re.findall(r'references/([^\s\)\]\"\'`]+)', body)
    body_ref_links = list(set(body_ref_links))

    skills.append({
        "name": name,
        "path": path.replace(ROOT + "/", ""),
        "category": category,
        "version": fm.get("version", ""),
        "description": desc if isinstance(desc, str) else str(desc),
        "desc_len": desc_len,
        "body_lines": body_lines,
        "body_words": body_words,
        "refs": ref_files,
        "refs_count": len(ref_files),
        "body_ref_links": body_ref_links,
        "has_allowed_tools_hyphen": "allowed-tools" in fm,
        "has_allowed_tools_underscore": "allowed_tools" in fm,
        "has_requires_agent_teams": "requires_agent_teams" in fm,
        "has_requires_claude_code": "requires_claude_code" in fm,
        "has_min_plan": "min_plan" in fm,
        "has_version": "version" in fm,
        "has_composes_with": "composes_with" in fm,
        "has_spawned_by": "spawned_by" in fm,
        "has_owns": "owns" in fm,
        "composes_with": fm.get("composes_with", []) or [],
        "spawned_by": fm.get("spawned_by", []) or [],
        "owns": fm.get("owns", {}) or {},
        "raw_field_order": raw_field_order,
        "metadata": fm.get("metadata", {}) or {},
        "compatibility": fm.get("compatibility", ""),
        "license": fm.get("license", ""),
    })

out = {"skills": skills, "all_names": sorted(all_names)}
out_path = "/Users/johns/Repos/the-hive-ecosystem/Skill-Madness/audit/_tools/skills_dump.json"
with open(out_path, "w") as f:
    json.dump(out, f, indent=2, default=str)

print(f"Parsed {len(skills)} skills, dump at {out_path}")
print(f"Errors: {sum(1 for s in skills if 'error' in s)}")
