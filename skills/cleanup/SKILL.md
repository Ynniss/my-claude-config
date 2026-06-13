---
name: cleanup
description: Remove merged/orphaned worktrees, leftover sibling directories, stale branches, and remote tracking refs. Optional issue-number argument scopes the whole run to one issue.
allowed-tools: Bash(gh:*), Bash(git:*), Bash(cd:*), Bash(pwd:*), Bash(ls:*), Bash(rm:*), Bash(dirname:*), Bash(basename:*), Bash(realpath:*), Bash(awk:*), AskUserQuestion
model: haiku
---

# Clean Worktrees, Leftover Dirs & Stale Branches

Full git hygiene: linked worktrees, **leftover sibling directories on disk**, local
branches, and remote tracking refs. Squash-merge aware.

## Step 0: Read the argument (optional issue number)

`$ARGUMENTS` may contain a single issue number (e.g. `/cleanup 1` → issue `1`).

- **If an issue number is given → SCOPE the entire run to that issue.** Only consider
  worktrees, sibling directories, and branches whose name matches that issue number:
  - branch matches `^[a-z]+/<N>-`  (e.g. `feature/1-meal-planner` for issue `1`)
  - directory matches `^[a-z]+-<N>-` (e.g. `feature-1-meal-planner` for issue `1`)
  - **Match on the issue boundary, not a substring** — issue `1` must NOT match
    `feature/12-home-screen`. Anchor the number with a trailing `-`.
  Ignore everything that doesn't match. Skip the broad sweeps below; only report/clean the
  matching item(s).
- **If no argument → full sweep** across all worktrees, sibling dirs, and branches.

## Step 1: Locate the primary worktree and its parent

```bash
# primary (first / non-linked) worktree path
git worktree list --porcelain | awk '/^worktree/{print $2; exit}'
```
If currently inside a linked worktree, the command still lists the primary first. `cd` to
the primary. Let `PARENT` = `dirname` of the primary worktree — sibling worktrees and
leftover dirs live here.

## Step 2: Prune remote tracking refs

```bash
git fetch --prune origin
```

## Step 3: Enumerate candidates

### 3a. Registered linked worktrees
```bash
git worktree list --porcelain
```
Parse `worktree <path>` + `branch refs/heads/<branch>`. Skip the primary.

### 3b. Leftover sibling directories on disk (orphans)
List directories directly under `PARENT`, then subtract the primary and every registered
worktree path. **What remains are orphaned directories** — folders left behind after a
worktree was removed, or stray clones. These are the "useless subdirectories" this skill
must catch, not just what `git worktree list` reports.
```bash
ls -1d "$PARENT"/*/ 2>/dev/null
```
For each orphan, note whether it's a git repo and whether it has uncommitted/unpushed work
(`git -C <dir> status --porcelain`) before proposing removal.

> If an issue number was given (Step 0), filter 3a and 3b to matching names only.

## Step 4: Decide what's stale — squash-merge aware

A worktree/branch is **removable** if ANY of these hold (check in this order, cheapest first):

1. **Merged PR:** `gh pr list --head "<branch>" --state merged --json number,title --jq '.[0] // empty'`
2. **Reachable from main:** appears in `git branch --merged origin/main`
3. **Content identical to main (catches squash merges):** `git diff --quiet origin/main "<branch>"`
   exits `0` (empty diff). Squash/rebase merges discard the original commits, so checks 1–2
   miss them — this catches them.

**Safety — never silently discard work:**
- Before removing a worktree, its tree must be clean: `git -C "<path>" status --porcelain`.
  If dirty, do NOT auto-remove. Offer it as a distinct, clearly-labelled "force" option so
  the user explicitly opts into losing those changes.
- For an orphan directory (3b), if it has uncommitted or unpushed work, surface that and
  default to keeping it unless the user opts into force-removal.

## Step 5: Stale local branches (no worktree)

Branches (excluding `main` and any with an active worktree) that are removable per Step 4.
```bash
git branch | grep -v '^\*' | grep -v 'main'
```
(If issue-scoped, only the matching branch.)

## Step 6: Select & clean

Show one table of everything cleanable:

| Type | Name | PR# | Why |
|------|------|-----|-----|

Types:
- `worktree` — removes worktree + its branch
- `worktree (force)` — dirty tree; removal discards uncommitted changes
- `dir` — orphaned directory on disk; removed with `rm -rf` (no branch)
- `branch` — local branch only

**If any found, you MUST use `AskUserQuestion` with `multiSelect: true` to let the user pick
which items to clean — never a Yes/No confirmation, and never plain text.** One option per
cleanable item: label `<type>: <name>`, description = why it's stale (e.g. "PR #11 merged",
"merged into origin/main", "squash-merged — content identical to main", "orphaned dir, no
git work").

> **One-item case:** `AskUserQuestion` requires ≥2 options per question. When exactly one
> item is cleanable, add a second option `Skip — leave it` so the picker is valid; clean the
> item only if the user selects it.

> **Pagination:** `AskUserQuestion` caps each question at 4 options but accepts up to 4
> questions per call. For >4 items, paginate across `ceil(N/4)` questions (headers
> `Cleanup 1/2`, …) in one call, each `multiSelect: true`; rebalance so no question has
> fewer than 2 options (5 items → 3 + 2, not 4 + 1). For >16, repeat calls. Merge all
> selections into one set. Never let the option cap hide an item; never fall back to plain text.

## Step 7: Execute (only the items the user selected)

- worktree (clean): `git worktree remove "<path>" && git branch -d "<branch>"`
- worktree (force): `git worktree remove --force "<path>" && git branch -D "<branch>"`
- dir (orphan):     `rm -rf "<path>"`
- branch:           `git branch -d "<branch>"` (use `-D` if `-d` fails and removable is confirmed)

## Step 8: Output

Summary: "Cleaned: removed X worktrees, Y orphan dirs, Z branches, pruned remote refs"

If nothing to clean: "All clean — no stale worktrees, leftover directories, or branches found."
(If issue-scoped and nothing matched: "Nothing to clean for issue <N>.")
