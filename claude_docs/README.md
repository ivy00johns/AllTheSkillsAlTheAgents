# claude_docs

Personal skills that depend on private infrastructure and are **not** part of
the OSS skill bundle in `../skills/`.

When the public repository is cut from this monorepo, this directory is
excluded. It exists here so the skills stay close to the rest of the
toolkit during local development.

## Layout

```text
claude_docs/
└── .claude/
    └── skills/
        └── workflows/
            ├── hive-cli/      # operates against a private platform repo
            └── env-setup/     # ties to a personal 1Password vault
```

The `.claude/skills/` substructure mirrors the layout Claude Code expects
for project-scoped skills, so the directory itself is also a valid Claude
Code project root.

## Why these skills are here, not in `skills/`

| Skill | Reason |
|---|---|
| `hive-cli` | Hardcoded to `~/Repos/the-hive-ecosystem/The-Hive` (private). |
| `env-setup` | Built around a specific personal 1Password vault name. |

If either of these is generalized away from its private dependency, it can
move back to `skills/workflows/`.
