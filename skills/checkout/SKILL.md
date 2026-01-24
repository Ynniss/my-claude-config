---
name: checkout
description: Open a worktree for an issue
allowed-tools: Bash(git:*), Bash(gh:*), Bash(rm:*), Bash, Read, AskUserQuestion
model: haiku
---

# Open Worktree for Issue

Uses git worktrees - one source repo with lightweight worktrees for each branch.

## Directory Structure
```
$BASE_PATH/
├── source/                    # Main repo (always exists)
├── feature-21-i18n/           # Worktree linked to source
├── feature-22-feeding-screen/ # Worktree linked to source
└── ...
```

## Step 0: Bootstrap (if needed)
Get the base path and check if `source/` exists:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && BASE_PATH=$(dirname "$REPO_ROOT") && echo "BASE_PATH=$BASE_PATH" && test -d "$BASE_PATH/source" && echo "SOURCE_EXISTS=true" || echo "SOURCE_EXISTS=false"
```

If `source/` does NOT exist, clone it:
```bash
REPO_URL=$(gh repo view --json url -q .url) && git clone "$REPO_URL" "$BASE_PATH/source"
```

## Step 1: Gather Info in Parallel
Run these FOUR bash commands IN PARALLEL (single message, multiple tool calls):
```bash
# Command 1: List existing worktrees
REPO_ROOT=$(git rev-parse --show-toplevel) && BASE_PATH=$(dirname "$REPO_ROOT") && git -C "$BASE_PATH/source" worktree list
```
```bash
# Command 2: List open issues
gh issue list --state open --limit 10
```
```bash
# Command 3: Fetch and list remote branches
REPO_ROOT=$(git rev-parse --show-toplevel) && BASE_PATH=$(dirname "$REPO_ROOT") && git -C "$BASE_PATH/source" fetch origin --prune && git -C "$BASE_PATH/source" branch -r
```
```bash
# Command 4: List merged PRs (for cleanup)
gh pr list --state merged --base main --json headRefName --limit 50
```

## Step 2: Auto-cleanup Stale Worktrees
Compare worktree list against merged PRs. For each worktree whose branch was merged:
```bash
git -C "$BASE_PATH/source" worktree remove "$BASE_PATH/<merged-branch-folder>"
```
**Important:** If removal fails (uncommitted changes), warn and skip that worktree.

Report what was cleaned up to the user.

## Step 3: Ask Which Issue
**Use AskUserQuestion with ONE question:**
- "Which issue?" - Options: up to 4 issues from Step 1

No slot selection needed - worktrees are managed automatically.

## Step 4: Find or Create Worktree
1. Parse issue to get branch name (convention: `feature/<issue-number>-<short-description>`)
2. Check `git worktree list` output for existing worktree with this branch
3. If worktree EXISTS:
   - Just note the path, no action needed
4. If worktree does NOT exist:
   - Check if branch exists on remote (from Step 1 branch list)
   - If branch exists on remote:
     ```bash
     git -C "$BASE_PATH/source" worktree add "$BASE_PATH/<branch-name>" <branch-name>
     ```
   - If branch does NOT exist:
     ```bash
     git -C "$BASE_PATH/source" worktree add "$BASE_PATH/<branch-name>" -b <branch-name> origin/main
     ```

## Step 5: Setup (only for new worktrees)
If a NEW worktree was created (not an existing one):
1. Read the project's `CLAUDE.md` file in the new worktree
2. Look for a `## Worktree Setup` section
3. Run the commands listed there

**Skip this step** if the worktree already existed or if no setup section exists.

## Step 6: Confirm
Tell the user:
- Worktree path (full path to working directory)
- Branch name
- Issue number and title
- Any worktrees that were cleaned up (from Step 2)
- Whether setup was run (npm install)

## Edge Cases
- **Working in source:** Valid - source is the main worktree
- **Branch exists but no worktree:** Create worktree for existing remote branch
- **No branch exists:** Create new branch + worktree from origin/main
- **Worktree already exists:** Just confirm path, no action needed
- **Dirty worktree on cleanup:** Warn and skip (don't force remove)
- **source/ doesn't exist:** Auto-bootstrap by cloning
