---
name: checkout
description: Open and fully initialize (install dependencies) worktrees for one or more issues
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
Run these bash commands IN PARALLEL (single message, multiple tool calls):
```bash
# Command 1: List existing worktrees
git worktree list
```
```bash
# Command 2: List open issues (high limit so NONE are dropped)
gh issue list --state open --limit 100
```
```bash
# Command 3: Fetch and list remote branches
git fetch origin --prune && git branch -r
```
```bash
# Command 4: List merged PRs (for cleanup detection)
gh pr list --state merged --base main --json headRefName --limit 100
```
```bash
# Command 5: List CLOSED issues (for cleanup detection — closed-but-not-merged counts as stale)
gh issue list --state closed --limit 100 --json number,title
```

## Step 2: Propose Stale Worktree Cleanup
A worktree is **stale** if EITHER condition holds (match by issue number in the branch/folder name, e.g. `feature-23-*` ⇒ issue #23):
- its branch appears in the merged-PR list (Command 4), OR
- its issue number appears in the closed-issues list (Command 5).

**Never** treat the current worktree or the `main` worktree as stale.

**If there are stale worktrees, you MUST propose them for removal via the `AskUserQuestion` tool** — do NOT auto-delete and do NOT use plain text. One option per stale worktree (label `#<number> — <folder>`, description = why it's stale: "PR merged" or "issue closed"), `multiSelect: true`.

> **Pagination (same as Step 3):** each question caps at 4 options, but a single call accepts up to 4 questions. For >4 stale worktrees, paginate across `ceil(N/4)` questions (headers `Stale 1/2`, …) in one call; for >16, repeat calls. Never fall back to plain text.

For each worktree the user chose to remove:
```bash
git worktree remove "$BASE_PATH/<worktree-folder>"
```
**Important:** If removal fails (uncommitted changes / dirty worktree), warn and skip that worktree — never force-remove.

Report what was removed and what was skipped.

## Step 3: Ask Which Issue(s)
**Filter issues first:** Compare the worktree list from Step 1 against open issues. Exclude any issue that already has a worktree (match by issue number in branch/folder name, e.g., `feature-23-*` means issue #23 has a worktree).

**If ALL issues already have worktrees:** Skip to Step 6 and show the existing worktrees summary.

**You MUST ALWAYS use the `AskUserQuestion` tool** to collect the selection — never plain text. Every candidate issue must appear as a selectable option.

`AskUserQuestion` caps each **question** at 4 options, but accepts up to **4 questions** in a single call. Use that to fit every candidate (up to 16) into one interview by **paginating**:

- **≤4 candidates** → one question, one option per issue, `multiSelect: true`.
- **5–16 candidates** → split into `ceil(N/4)` questions in a SINGLE `AskUserQuestion` call. Header each `Issues 1/2`, `Issues 2/2`, etc.; every question `multiSelect: true`. Merge the selections from all questions into one set.
  - **Each question needs 2–4 options** (the tool rejects a 1-option question). Rebalance chunks so none has fewer than 2 — e.g. 5 issues → **3 + 2**, not 4 + 1; 9 issues → 3 + 3 + 3, not 4 + 4 + 1.
- **>16 candidates** (rare) → make repeated `AskUserQuestion` calls of 4 questions each until all issues have been offered, then merge.

Label each option `#<number> — <title>` with a short description. Example for 5 candidates (rebalanced 3 + 2):
```
AskUserQuestion({
  questions: [
    { question: "Which issue(s)? (1/2)", header: "Issues 1/2", multiSelect: true, options: [
      { label: "#1 — Weekly Meal Planner", description: "Full feature, P1" },
      { label: "#2 — Authentication", description: "Anonymous-first, P1" },
      { label: "#4 — Testing foundation", description: "testID convention, P2" }
    ]},
    { question: "Which issue(s)? (2/2)", header: "Issues 2/2", multiSelect: true, options: [
      { label: "#5 — Onboarding pager test", description: "Maestro matching bug, P2" },
      { label: "#7 — Localization pipeline", description: "DeepL → Claude review" }
    ]}
  ]
})
```

Wait for the user's explicit selection before proceeding. Do NOT create worktrees without it.

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

## Step 5: Initialize each NEW worktree
A new worktree shares git history with the hub but has its **own working directory with NO
`node_modules`** (dependencies are git-ignored and per-worktree), so it can't build,
type-check, or run until it's initialized. Fully initialize every NEW worktree — skip
worktrees that already existed.

### 5a. Install dependencies (the default — always do this)
Detect the package manager from the lockfile **in the worktree** and install. Use the
manager's directory flag (NOT `cd`, which can trip permission prompts). Run these in
parallel across new worktrees:
- `bun.lockb` → `bun install --cwd "$BASE_PATH/<folder>"`
- `pnpm-lock.yaml` → `pnpm -C "$BASE_PATH/<folder>" install`
- `yarn.lock` → `yarn --cwd "$BASE_PATH/<folder>" install`
- `package-lock.json` present, or only `package.json` → `npm install --prefix "$BASE_PATH/<folder>"`
- No `package.json` → not a Node project; skip install and rely on 5b.

**Wait for installs to finish** before calling a worktree ready. If an install fails (e.g.
no network, registry auth), report it plainly and mark that worktree **"created · install
FAILED"** in the summary — never pretend it's ready.

### 5b. Run project-specific setup
Read the project's `CLAUDE.md` in the new worktree; if it has a `## Worktree Setup`
section, run those commands **after** the install. They cover anything beyond a plain
install (copying `.env`, codegen, `expo prebuild`, DB seed, etc.). Skip if absent.

### 5c. Native builds — note, don't run
If the project is Expo / React Native (or otherwise has native modules), a dev-client
rebuild (`expo run:*` / EAS) is a device-side step, NOT part of worktree init. Don't
attempt it — just mention it in the summary if the project clearly needs one.

## Step 6: Confirm
Show a summary table of newly created worktrees:

| Issue | Branch | Path | Status |
|-------|--------|------|--------|
| #21 | feature/21-i18n | /path/to/feature-21-i18n | Created · deps installed |
| #16 | feature/16-cicd | /path/to/feature-16-cicd | Created · rebased · deps installed |

Also report:
- Any worktree where dependency install FAILED (created but not ready — tell the user how to finish it)
- Existing worktrees that were skipped (listed for reference)
- Any stale worktrees removed in Step 2 (and any skipped because they were dirty)
- Any rebase conflicts (if rebase failed, warn user to resolve manually)
- Any errors encountered

## Edge Cases
- **Branch exists but no worktree:** Create worktree for existing remote branch, rebase onto origin/main
- **No branch exists:** Create new branch + worktree from origin/main (already up to date)
- **All issues have worktrees:** Skip to summary, show existing worktrees
- **More than 4 candidate issues (or >4 stale worktrees):** `AskUserQuestion` caps each question at 4 options but takes up to 4 questions per call — paginate across multiple questions (`ceil(N/4)`) so every item is a selectable option. ALWAYS use the interview tool; never fall back to plain text. Never let the option cap hide an item.
- **Stale worktree (issue closed or PR merged):** Propose for removal via Step 2 — never auto-delete.
- **Rebase conflicts:** Abort rebase (`git rebase --abort`), warn user to resolve manually
- **Dirty worktree on cleanup:** Warn and skip (don't force remove)
