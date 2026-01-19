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

## Commands

### `/github:push`

Splits staged changes into atomic, conventional commits and creates a pull request.

**What it does:**
1. Reviews all staged/unstaged changes
2. Proposes a commit strategy (one commit per logical unit)
3. Asks for approval before committing
4. Creates commits using conventional commit format (`feat:`, `fix:`, `refactor:`, etc.)
5. Pushes to remote and creates a PR targeting `main` (or updates existing PR)
6. Handles worktree cleanup if applicable

**Conventions enforced:**
- Branch naming: `<type>/<issue-number>-<slug>` (e.g., `feature/123-add-auth`)
- PR body includes `Resolves #<issue-number>`
- No Co-Authored-By trailers or "Generated with Claude Code" footers

### `/github:release`

Creates a GitHub release with an auto-generated changelog from merged PRs.

**What it does:**
1. Fetches the latest release tag
2. Collects all PRs merged since that release
3. Asks for the new version number
4. Groups PRs into categories (Features, Fixes, Improvements)
5. Presents draft release notes for approval
6. Creates and pushes the git tag
7. Creates the GitHub release

### `/github:checkout`

Switches an existing dev slot (worktree) to a different remote branch.

**What it does:**
1. Lists available slots in the parent directory
2. Lists remote branches
3. Renames the slot folder to match the branch name
4. Checks out the selected branch

**Dev slot convention:** Worktrees are organized as sibling folders (`a/`, `b/`, `c/` or branch-named folders) allowing parallel work on multiple branches.

### `/github:clone`

Creates a new dev slot by cloning the current repo into a sibling folder.

**What it does:**
1. Detects the repo URL and base path
2. Names the new slot with the next letter (`a` → `b` → `c`)
3. Clones the repo into the new slot
4. Checks out the desired branch (renames slot to branch name if not `main`)

## MCP Servers & Plugins

### Context7 (MCP Server)

Provides real-time documentation lookup for any library or framework. Instead of relying on training data, Claude can fetch current docs and code examples.

**Usage:** Claude automatically uses this when you ask about library APIs, syntax, or best practices.

### n8n MCP Skills

Specialized knowledge for building [n8n](https://n8n.io) workflows:
- Node configuration guidance
- JavaScript/Python code node patterns
- Workflow architectural patterns
- Expression syntax validation
- Validation error interpretation

### DeepL (MCP Server)

Translation and text rephrasing capabilities:
- Translate text between languages
- Translate documents (PDF, DOCX, etc.)
- Rephrase text with different styles/tones
- Glossary support for consistent terminology

## Safety Permissions

The `settings.json` blocks dangerous operations:

| Category | Blocked Patterns |
|----------|------------------|
| Destructive commands | `rm -rf /`, `rm -rf ~`, `dd`, `mkfs`, `chmod 777` |
| Credential access | `~/.aws/**`, `~/.ssh/id_*`, `~/.ssh/*.pem`, `~/.gnupg/**`, `**/*.key` |
| Env file editing | `.env`, `.env.local`, `.env.production` |

## Feature Flags

- **`alwaysThinkingEnabled`**: Claude shows its reasoning process (extended thinking) for all responses
