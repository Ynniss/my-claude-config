---
description: Switch a dev slot to a remote branch
allowed-tools: Bash(git:*), Bash(ls:*), Bash(mv:*), Bash(cd:*), AskUserQuestion
---

# Checkout Branch to Dev Slot

## Step 1: Detect Base Path
Get the current git repo root, then go up one level to find the slots directory:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_PATH=$(dirname "$REPO_ROOT")
echo "$BASE_PATH"
```
This is the directory containing all the slots (a, b, c, or branch-named folders).

## Step 2: List Available Slots
```bash
ls -1 "$BASE_PATH"
```
Show all folders - both available slots (`a`, `b`, `c`) and active ones (branch names).

## Step 3: Ask Which Slot
**Use AskUserQuestion tool:**
- Question: "Which slot do you want to use?"
- Options: List all folders found in Step 2 (max 4, prioritize letter slots first)

## Step 4: Fetch and List Remote Branches
From the current repo, fetch and list remote branches:
```bash
git fetch --all && git branch -r --format='%(refname:short)' | sed 's|origin/||' | grep -v HEAD
```

## Step 5: Ask Which Branch
**Use AskUserQuestion tool:**
- Question: "Which branch do you want to work on?"
- Options: List up to 4 most relevant branches (prioritize feature branches, exclude main if others exist). User can type custom branch via "Other".

## Step 6: Rename Slot (if needed)
If the selected slot name differs from the branch name:
```bash
mv "$BASE_PATH/<old-slot-name>" "$BASE_PATH/<branch-name>"
```

## Step 7: Checkout Branch
```bash
cd "$BASE_PATH/<branch-name>" && git checkout <branch-name>
```

If the branch doesn't exist locally:
```bash
git checkout -b <branch-name> origin/<branch-name>
```

## Step 8: Confirm
Tell the user:
- Which slot is now active
- Which branch is checked out
- The full path to the working directory

## Edge Cases
- **No letter slots available:** Show all slots anyway, user can overwrite an active one
- **Branch doesn't exist on remote:** Inform user and ask if they want to create it locally
- **Uncommitted changes in slot:** Warn user before switching, ask if they want to stash or discard
