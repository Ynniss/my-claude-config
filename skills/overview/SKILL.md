---
name: overview
description: Show status of all active worktrees, branches, and linked issues
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cd:*)
model: haiku
---

# Worktree Overview

Show a summary of all active work across worktrees.

## Step 1: Gather Info in Parallel

Run these THREE bash commands IN PARALLEL (single message, multiple tool calls):

```bash
# Command 1: List all worktrees
git worktree list
```
```bash
# Command 2: List open issues
gh issue list --state open --limit 20
```
```bash
# Command 3: For each non-main worktree, get status + commits ahead
git worktree list --porcelain | grep "^worktree " | grep -v "$(git rev-parse --show-toplevel)$" | sed 's/^worktree //' | while read wt; do
  branch=$(git -C "$wt" branch --show-current)
  echo "=== $branch ==="
  echo "Path: $wt"
  echo "Unstaged:"
  git -C "$wt" status --short
  echo "Commits ahead of main:"
  git -C "$wt" log main..HEAD --oneline 2>/dev/null
  echo ""
done
```

## Step 2: Display Summary

Show a table with one row per worktree (exclude main):

| Issue | Branch | Unstaged | Commits | Status |
|-------|--------|----------|---------|--------|
| #22 — Supabase auth | `feature/22-supabase-auth` | 8M + 4N | 0 | Uncommitted changes |
| #23 — PostHog & Sentry | `feature/23-posthog-sentry` | 21M + 1N | 3 | In progress |

Column definitions:
- **Issue**: Match issue number from branch name (e.g., `feature/22-*` → `#22`) against open issues list to get the title
- **Branch**: Branch name
- **Unstaged**: Count of modified (M) and new/untracked (N) files from `git status --short`
- **Commits**: Number of commits ahead of main
- **Status**: Derive from state:
  - `Uncommitted changes` — unstaged changes but 0 commits
  - `In progress` — has commits and/or unstaged changes
  - `Ready to push` — has commits, no unstaged changes
  - `Clean` — no commits, no unstaged changes (freshly created)

## Step 3: Show Issues Without Worktrees

Show open issues that do NOT have a matching worktree in a second table:

| Issue | Labels | Created |
|-------|--------|---------|
| #16 — Add daily rate limit for Pro subscribers | | Feb 12 |
| #14 — Add Cloudflare KV caching | | Feb 11 |

If all issues have worktrees, show: "All open issues have active worktrees."

## Formatting Rules
- Output ONLY the two tables with headers "Active Worktrees" and "Backlog" — no explanations or prose
- Use backticks for branch names
- Link issue numbers as `#<number>`
- Use short date format (e.g., "Feb 28")
- Keep issue titles concise — truncate if longer than ~50 chars
