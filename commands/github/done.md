---
description: Finish work - split into atomic commits, create PR, cleanup if needed. Trigger phrases - "I'm done", "wrap it up", "create the PR", "let's finish", "ship it"
allowed-tools: Bash(gh:*), Bash(git:*), Bash(rm:*), Bash(pwd:*), Bash(rmdir:*), AskUserQuestion
---

# Finish Work and Create PR

## Step 1: Review Changes
```bash
git status
git diff --stat
```
Show summary of all changes to the user.

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

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`

## Step 5: Push and Create PR
```bash
git push -u origin <branch>
```

Create PR with:
```bash
gh pr create --base develop --title "<title>" --body "$(cat <<'EOF'
## Summary
- <bullet points>

Closes #<issue-number>

## Test Plan
- [ ] <verification steps>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
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
- **No changes:** Inform user "Nothing to commit" and check if PR already exists
- **PR already exists:** Show PR URL and ask if user wants to update it
- **User rejects split:** Ask for their preferred approach
