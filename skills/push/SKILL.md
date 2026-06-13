---
name: push
description: Split into atomic commits, push, and create PR (optionally against a target repo path)
allowed-tools: Bash(gh:*), Bash(git:*), Bash(rm:*), Bash(pwd:*), Bash(rmdir:*), AskUserQuestion
model: sonnet
effort: low
---

# Finish Work and Create PR

## Step 0: Resolve Target Repo
This skill operates on **one** repo. By default that's the current session's repo (cwd), but
the user can point it at any repo out of session scope by passing a path argument.

**Parse the invocation argument** (everything after `/push`):
- **A path** — `~/.claude`, `--repo <path>`, `--repo=<path>`, or a bare absolute/relative path
  (e.g. `/push ~/.claude`, `/push the .claude config dir`). Resolve `~` and relative paths to
  an absolute path → `$REPO`.
- **No path** (e.g. `/push`, or only a PR title/notes) → `$REPO` = current working directory.

Then resolve and verify, and compute the GitHub slug for `gh`:
```bash
REPO="$(cd "<parsed-path-or-.>" 2>/dev/null && git rev-parse --show-toplevel)" || { echo "Not a git repo: <parsed-path>"; exit 1; }
SLUG="$(git -C "$REPO" remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
echo "REPO=$REPO" && echo "SLUG=${SLUG:-<no origin remote>}"
```

**Convention for every command below (Steps 1–8):**
- Run **all `git` commands** with `git -C "$REPO" …` (the snippets below omit `-C "$REPO"` for
  brevity — always add it).
- Run **all `gh` commands** with `gh … -R "$SLUG"` when `$SLUG` is set. If there's no origin
  remote, a local-only repo can still commit; skip PR creation (Step 6) and say so.
- Never `cd` into `$REPO` (it can trip permission prompts) — use the flags above.

## Git Conventions (GitHub Flow)
- **PRs always target `main`** - no long-lived feature branches
- **Branch naming**: `<type>/<issue-number>-<slug>` (types: `feature/`, `fix/`, `docs/`, `refactor/`)
- **Commits**: Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`). No Co-Authored-By trailers.
- **PR body**: Always include `Resolves #<issue-number>`. No "Generated with Claude Code" footer.

## IMPORTANT: Direct push on main
- **If already on `main`**: commit and push directly to `main`. Do NOT create a feature branch or PR. Just commit, push, done.
- **If on a feature branch**: follow the full PR flow below.

## Step 1: Review Changes & Check for Existing PR
```bash
git -C "$REPO" status
git -C "$REPO" diff --stat
git -C "$REPO" branch --show-current
gh pr list --head "$(git -C "$REPO" branch --show-current)" --json number,url --jq '.[0]' -R "$SLUG"
```
Show summary of changes. (This is the convention from Step 0 made explicit — apply the same
`-C "$REPO"` / `-R "$SLUG"` treatment to every git/gh command in the remaining steps.)

**If on `main`:** Skip Steps 2, 5, 6 PR creation, and 7. Just commit (Steps 3-4), push to main, and done.

**If on a feature branch and a PR already exists:** Note that we'll just commit and push (skip PR creation).

## Step 2: Extract Issue Number (feature branches only)
Get issue number from branch name (format: `<type>/<issue-number>-<slug>`):
```bash
git branch --show-current | grep -oE '[0-9]+' | head -1
```

## Step 3: Propose Commit Strategy
Split changes into **lean, atomic commits** - each commit should do ONE thing.

**Scope = everything by default.** Commit and push ALL changed files. Do NOT single out
incidental churn (e.g. a rotated spinner verb, a bumped timestamp, formatting) and ask whether
to skip it — just include it. The ONLY reason to hold back or flag a change is that it's
genuinely **unsuitable to publish**: secrets, API keys, tokens, credentials, private absolute
paths, or other sensitive data — especially when pushing to a public repo. When you spot
something like that, stop and flag it specifically; otherwise include everything without asking.

Guidelines:
- Each commit must be focused and self-contained
- Split by logical unit, not by file type
- Each commit should leave the codebase in a working state
- The more commits the better (within reason)

Present the proposed commit list, then **use AskUserQuestion tool** to get approval:
```
Question: "Does this commit strategy look good?"
Options:
- "Yes, proceed" - Continue with commits
- "Adjust splits" - Let user explain changes
- "I'll do it manually" - Abort and let user handle
```

## Step 4: Create Commits
Only proceed if user approved in Step 3.

For each logical group:
1. Stage relevant files: `git add <files>`
2. Commit with conventional format and HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
<type>(scope): description
EOF
)"
```

## Step 5: Rebase onto Main
Ensure branch is up-to-date with main before pushing:
```bash
git fetch origin main
git rebase origin/main
```

**If conflicts occur:**
1. Inform user about the conflicts
2. Show conflicting files with `git status`
3. Stop and let user resolve manually (don't attempt auto-resolution)

## Step 6: Push (and Create PR if needed)
```bash
git push -u origin <branch>
```

**If on `main`:** Just `git push origin main` and skip PR creation. Done.

**If push is rejected (remote has changes):** Force push with lease (safe force push):
```bash
git push --force-with-lease origin <branch>
```

**If PR already exists (detected in Step 1):** Stop here. Show the existing PR URL and confirm the push was successful.

**If no PR exists (feature branch only):** Create PR with:
```bash
gh pr create --base main --title "<title>" --body "$(cat <<'EOF'
## Summary
<Brief description of what this PR does>

## Changes
- <bullet points of specific changes>

## Why
<Context: why is this change needed? Link to discussion/issue if relevant>

## Screenshots
<If UI changes, add before/after screenshots. Remove section if not applicable>

Resolves #<issue-number>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

## Step 7: Worktree Cleanup (conditional)
Check if in a worktree:
```bash
git rev-parse --git-dir
```

**If output contains "worktrees":**
Inform user with cleanup command.

**If NOT in a worktree:** Skip this step entirely.

## Step 8: Final Output
End with:
- PR URL
- Branch name
- Worktree cleanup instructions (only if applicable)

## Edge Cases
- **No changes:** Inform user "Nothing to commit" and show existing PR URL if one exists
- **User rejects split:** Ask for their preferred approach
- **Rebase conflicts:** Stop and show conflicting files, let user resolve
- **Push rejected after rebase:** Use `--force-with-lease` (safe force push)
