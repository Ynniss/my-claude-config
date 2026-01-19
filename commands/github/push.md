---
description: Split into atomic commits, push, and create PR
allowed-tools: Bash(gh:*), Bash(git:*), Bash(rm:*), Bash(pwd:*), Bash(rmdir:*), AskUserQuestion
---

# Finish Work and Create PR

## Git Conventions (GitHub Flow)
- **PRs always target `main`** - no long-lived feature branches
- **Branch naming**: `<type>/<issue-number>-<slug>` (types: `feature/`, `fix/`, `docs/`, `refactor/`)
- **Commits**: Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`). No Co-Authored-By trailers.
- **PR body**: Always include `Resolves #<issue-number>`. No "Generated with Claude Code" footer.

## Step 1: Review Changes & Check for Existing PR
```bash
git status
git diff --stat
git branch --show-current
gh pr list --head $(git branch --show-current) --json number,url --jq '.[0]'
```
Show summary of changes. If a PR already exists, note that we'll just commit and push (skip PR creation).

## Step 2: Extract Issue Number
Get issue number from branch name (format: `<type>/<issue-number>-<slug>`):
```bash
git branch --show-current | grep -oE '[0-9]+' | head -1
```

## Step 3: Propose Commit Strategy
Split changes into **lean, atomic commits** - each commit should do ONE thing.

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

## Step 5: Push (and Create PR if needed)
```bash
git push -u origin <branch>
```

**If PR already exists (detected in Step 1):** Stop here. Show the existing PR URL and confirm the push was successful.

**If no PR exists:** Create PR with:
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

## Step 6: Worktree Cleanup (conditional)
Check if in a worktree:
```bash
git rev-parse --git-dir
```

**If output contains "worktrees":**
Inform user with cleanup command.

**If NOT in a worktree:** Skip this step entirely.

## Step 7: Final Output
End with:
- PR URL
- Branch name
- Worktree cleanup instructions (only if applicable)

## Edge Cases
- **No changes:** Inform user "Nothing to commit" and show existing PR URL if one exists
- **User rejects split:** Ask for their preferred approach
