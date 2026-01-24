# Claude Code Config

Personal configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's agentic CLI tool. Clone directly into `~/.claude` for seamless syncing across machines.

## Setup

```bash
git clone git@github.com:Ynniss/my-claude-config.git ~/.claude
```

## Repository Structure

```
~/.claude/
├── CLAUDE.md           # Global instructions loaded in every session
├── settings.json       # Permissions, plugins, and feature flags
├── skills/
│   ├── checkout/       # /checkout - Open worktree for an issue
│   ├── push/           # /push - Split into atomic commits, push, and create PR
│   └── release/        # /release - Create git tag and GitHub release
└── README.md
```

## Skills

### `/checkout`

Opens a git worktree for an issue, enabling parallel work on multiple branches.

**What it does:**
1. Lists existing worktrees and open issues
2. Auto-cleans stale worktrees (merged PRs)
3. Creates or switches to a worktree for the selected issue
4. Runs project setup commands (e.g., `npm install`)

**Worktree convention:** Worktrees are sibling folders named after branches (e.g., `feature-23-auth/`).

### `/push`

Splits changes into atomic commits, rebases onto main, and creates a pull request.

**What it does:**
1. Reviews all staged/unstaged changes
2. Proposes a commit strategy (one commit per logical unit)
3. Asks for approval before committing
4. Creates commits using conventional format (`feat:`, `fix:`, `refactor:`, etc.)
5. Rebases onto `origin/main` to ensure branch is up-to-date
6. Pushes and creates PR (or updates existing)
7. Handles worktree cleanup if applicable

**Conventions enforced:**
- Branch naming: `<type>/<issue-number>-<slug>`
- PR body includes `Resolves #<issue-number>`
- No Co-Authored-By trailers

### `/release`

Creates a GitHub release with auto-generated changelog from merged PRs.

**What it does:**
1. Fetches the latest release tag
2. Collects all PRs merged since that release
3. Asks for the new version number
4. Groups PRs into categories (Features, Fixes, Improvements)
5. Presents draft release notes for approval
6. Creates and pushes the git tag
7. Creates the GitHub release

## Global Instructions (CLAUDE.md)

| Section | Purpose |
|---------|---------|
| **Communication** | Ask before adding dependencies, clarify before implementing |
| **Shortcuts** | "checkout", "push", "release" invoke respective skills |
| **Model Aliases** | Use `haiku`, `sonnet`, `opus` (not full model IDs) |
| **Tool Preferences** | Context7 for library docs, WebSearch for general queries |
| **GitHub Issues** | Interview before drafting, show roadmap after creating |

## MCP Servers

### Context7

Real-time documentation lookup for any library or framework. Claude fetches current docs instead of relying on training data.

### DeepL

Translation and text rephrasing:
- Translate text and documents
- Rephrase with different styles/tones
- Glossary support

### n8n MCP Skills

Specialized knowledge for [n8n](https://n8n.io) workflows:
- Node configuration, code patterns, workflow architecture
- Expression syntax validation, error interpretation

## Safety Permissions

Blocked in `settings.json`:

| Category | Examples |
|----------|----------|
| Destructive commands | `rm -rf /`, `dd`, `mkfs`, `chmod 777` |
| Credential access | `~/.aws/**`, `~/.ssh/id_*`, `~/.gnupg/**` |
| Env file editing | `.env`, `.env.local`, `.env.production` |
