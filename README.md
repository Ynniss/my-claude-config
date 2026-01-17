# Claude Code Config

Personal Claude Code configuration for syncing across machines.

## Setup

```bash
git clone git@github.com:Ynniss/my-claude-config.git ~/.claude
```

## Contents

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Global instructions (communication style, git workflow) |
| `settings.json` | Global settings (permissions, plugins) |
| `commands/` | Custom slash commands |

## Permissions

The `settings.json` includes safety rules that block dangerous operations:

- Catastrophic deletions (`rm -rf /`, `rm -rf ~`)
- Disk operations (`dd`, `mkfs`)
- Reading system credentials (`~/.aws`, `~/.ssh`, `~/.gnupg`)
- Editing production env files (`.env`, `.env.production`)
