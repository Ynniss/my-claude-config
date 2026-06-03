---
name: checkout
description: Open worktrees for one or more issues
allowed-tools: Bash(git:*), Bash(gh:*), Bash(rm:*), Bash, Read, AskUserQuestion
model: haiku
---

# Open Worktrees for Issues

Uses git worktrees - the current repo is the hub, with lightweight worktrees as sibling directories.

## Directory Structure
```
$BASE_PATH/
├── main/                              # Current repo (the hub for all worktrees)
├── feature-21-i18n/                   # Worktree (sibling to main/)
├── feature-22-feeding-screen/         # Worktree (sibling to main/)
└── ...
```

Worktree folders use the pattern: `feature-<issue-number>-<short-description>` (flat, no nesting).

## Step 0: Determine Hub
Get the base path. The current repo IS the hub — no cloning needed:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel) && BASE_PATH=$(dirname "$REPO_ROOT") && HUB="$REPO_ROOT" && echo "BASE_PATH=$BASE_PATH" && echo "HUB=$HUB"
```

## Step 1: Gather Info in Parallel
Run these FOUR bash commands IN PARALLEL (single message, multiple tool calls):
```bash
# Command 1: List existing worktrees
git worktree list
```
```bash
# Command 2: List open issues
gh issue list --state open --limit 10
```
```bash
# Command 3: Fetch and list remote branches
git fetch origin --prune && git branch -r
```
```bash
# Command 4: List merged PRs (for cleanup)
gh pr list --state merged --base main --json headRefName --limit 50
```

## Step 2: Auto-cleanup Stale Worktrees
Compare worktree list against merged PRs. For each worktree whose branch was merged:
```bash
git worktree remove "$BASE_PATH/<worktree-folder>"
```
**Important:** If removal fails (uncommitted changes), warn and skip that worktree.

Report what was cleaned up to the user.

## Step 3: Ask Which Issue(s)
**Filter issues first:** Compare the worktree list from Step 1 against open issues. Exclude any issue that already has a worktree (match by issue number in branch/folder name, e.g., `feature-23-*` means issue #23 has a worktree).

**If ALL issues already have worktrees:** Skip to Step 6 and show the existing worktrees summary.

**You MUST use the `AskUserQuestion` tool** (not plain text) with a single question, `multiSelect: true`, and up to 4 options — one per issue that doesn't already have a worktree. Format each option label as `#<number> — <title>` with a short description. Example:

```
AskUserQuestion({
  questions: [{
    question: "Which issue(s) do you want to create worktrees for?",
    header: "Issues",
    options: [
      { label: "#23 — PostHog & Sentry", description: "Analytics and crash reporting" },
      { label: "#14 — KV caching", description: "Cloudflare KV image cache" }
    ],
    multiSelect: true
  }]
})
```

Wait for the user's selection before proceeding. Do NOT create worktrees without explicit selection.

## Step 4: Create Worktrees
**Naming:** Branch name uses slashes: `feature/<number>-<desc>`. Folder name uses dashes: `feature-<number>-<desc>` (sibling to main/).

**For each selected issue:**
1. Parse issue to get names:
   - Branch: `feature/<issue-number>-<short-description>`
   - Folder: `feature-<issue-number>-<short-description>`
2. Check if branch exists on remote (from Step 1 branch list)
3. If branch exists on remote:
   ```bash
   git worktree add "$BASE_PATH/<folder-name>" <branch-name>
   ```
   Then rebase onto origin/main to ensure it's up to date:
   ```bash
   git -C "$BASE_PATH/<folder-name>" rebase origin/main
   ```
4. If branch does NOT exist:
   ```bash
   git worktree add "$BASE_PATH/<folder-name>" -b <branch-name> origin/main
   ```
   (New branches are already up to date since they start from origin/main)

**Tip:** Run worktree creation commands in parallel when creating multiple new worktrees. Run rebase commands after all worktrees are created.

## Step 5: Setup (only for new worktrees)
For each NEW worktree created (not existing ones):
1. Read the project's `CLAUDE.md` file in the new worktree
2. Look for a `## Worktree Setup` section
3. Run the setup commands for each new worktree (can run in parallel)

**Skip this step** for worktrees that already existed or if no setup section exists.

## Step 6: Confirm
Show a summary table of newly created worktrees:

| Issue | Branch | Path | Status |
|-------|--------|------|--------|
| #21 | feature/21-i18n | /path/to/feature-21-i18n | Created (setup complete) |
| #16 | feature/16-cicd | /path/to/feature-16-cicd | Created (rebased, setup complete) |

Also report:
- Existing worktrees that were skipped (listed for reference)
- Any worktrees that were cleaned up (from Step 2)
- Any rebase conflicts (if rebase failed, warn user to resolve manually)
- Any errors encountered

## Edge Cases
- **Branch exists but no worktree:** Create worktree for existing remote branch, rebase onto origin/main
- **No branch exists:** Create new branch + worktree from origin/main (already up to date)
- **All issues have worktrees:** Skip to summary, show existing worktrees
- **Rebase conflicts:** Abort rebase (`git rebase --abort`), warn user to resolve manually
- **Dirty worktree on cleanup:** Warn and skip (don't force remove)
