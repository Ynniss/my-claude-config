# Claude Code Config

Personal configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's agentic CLI tool. This repository is designed to be cloned directly into `~/.claude` for seamless syncing across machines.

## What This Does

This configuration extends Claude Code with:

- **Custom slash commands** for GitHub workflows (commits, PRs, releases, worktree management)
- **Safety guardrails** to prevent destructive operations and credential exposure
- **MCP integrations** for enhanced documentation lookup and workflow automation
- **Global behavior rules** for consistent communication and git practices

## Setup

```bash
git clone git@github.com:Ynniss/my-claude-config.git ~/.claude
```

## Repository Structure

```
~/.claude/
├── CLAUDE.md           # Global instructions loaded in every session
├── settings.json       # Permissions, plugins, and feature flags
├── commands/
│   └── github/
│       ├── push.md     # /github:push - Commit, push, and create PRs
│       ├── release.md  # /github:release - Create releases with changelogs
│       ├── checkout.md # /github:checkout - Switch worktree slots to branches
│       └── clone.md    # /github:clone - Clone repo into new worktree slot
└── README.md
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
