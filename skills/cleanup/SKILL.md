---
name: cleanup
description: Remove merged worktrees, stale branches, and remote tracking refs
allowed-tools: Bash(gh:*), Bash(git:*), Bash(cd:*), Bash(pwd:*), AskUserQuestion
model: haiku
---

# Clean Merged Worktrees & Stale Branches

Full git hygiene: worktrees, local branches, and remote tracking refs.

## Step 1: Go to Source Directory

If in a worktree, navigate to source:
```bash
cd "$(git rev-parse --git-dir | sed 's|/.git/worktrees/.*||')/source" 2>/dev/null || true
pwd
```

## Step 2: Prune Remote Tracking Refs

Remove stale remote tracking refs (branches deleted on GitHub):
```bash
git fetch --prune origin
```

## Step 3: Find Merged Worktrees

List worktrees and check merged status in batch:
```bash
git worktree list --porcelain | grep "^worktree" | grep -v "/source$" | cut -d' ' -f2
```

For each path, get branch and check if merged:
```bash
gh pr list --head "<branch>" --state merged --json number,title --jq '.[0] // empty'
```

## Step 4: Find Stale Local Branches

Find local branches (excluding main) with no worktree that are either:
- Merged into origin/main
- Have a merged PR on GitHub

```bash
git branch --merged origin/main | grep -v '^\*' | grep -v 'main' | xargs -I{} echo {}
```

Also check any remaining unmerged branches (excluding main) for merged PRs:
```bash
git branch | grep -v '^\*' | grep -v 'main'
```
For each, check: `gh pr list --head "<branch>" --state merged --json number --jq '.[0] // empty'`

Exclude branches that have an active worktree.

## Step 5: Confirm & Clean

Show a single table of everything to clean:

| Type | Branch | PR# | Title |
|------|--------|-----|-------|

Types: `worktree` (will remove worktree + branch), `branch` (local branch only)

If any found, use AskUserQuestion once:
- "Clean up N items?" → "Yes, clean all" / "No, skip"

If confirmed:
- Worktrees: `git worktree remove "<path>" && git branch -d "<branch>"`
- Branches: `git branch -d "<branch>"` (use `-D` if `-d` fails and PR is confirmed merged)

## Step 6: Output

Summary: "Cleaned: removed X worktrees, Y branches, pruned remote refs"

If nothing to clean: "All clean — no stale worktrees or branches found."
