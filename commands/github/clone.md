---
description: Clone repo into a new dev slot
allowed-tools: Bash(git:*), Bash(ls:*), Bash(mkdir:*), Bash(wc:*), AskUserQuestion
---

# Clone Repo into New Dev Slot

## Step 1: Get Repo URL
Get the remote URL from the current repo:
```bash
git remote get-url origin
```

## Step 2: Detect Base Path
Get the current git repo root, then go up one level:
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_PATH=$(dirname "$REPO_ROOT")
echo "$BASE_PATH"
```

## Step 3: Count Existing Slots
Count how many slots (folders) already exist:
```bash
ls -1 "$BASE_PATH" | wc -l
```
The new slot will be named after the next letter in the alphabet based on this count.

Letter mapping: 1→a, 2→b, 3→c, 4→d, etc.

So if there are 3 existing slots, the new one will be `d` (the 4th letter).

## Step 4: Confirm with User
**Use AskUserQuestion tool:**
- Question: "Create new slot '<letter>' in <base_path>?"
- Options:
  - "Yes, create it" → proceed
  - "Cancel" → abort

## Step 5: Clone the Repo
```bash
cd "$BASE_PATH" && git clone <repo-url> <letter>
```

## Step 6: Ask Which Branch to Checkout
Fetch and list remote branches:
```bash
cd "$BASE_PATH/<letter>" && git fetch --all && git branch -r --format='%(refname:short)' | sed 's|origin/||' | grep -v HEAD
```

**Use AskUserQuestion tool:**
- Question: "Which branch do you want to work on?"
- Options: List up to 4 most relevant branches. User can type custom branch via "Other".

## Step 7: Checkout Branch and Rename Slot
```bash
cd "$BASE_PATH/<letter>" && git checkout <branch-name>
```

**If the branch is `main`:** Keep the slot named as the letter (e.g., `b`). Do NOT rename to `main`.

**If the branch is NOT `main`:** Rename the slot to match the branch name:
```bash
mv "$BASE_PATH/<letter>" "$BASE_PATH/<branch-name>"
```

If the branch doesn't exist locally:
```bash
git checkout -b <branch-name> origin/<branch-name>
```

## Step 8: Confirm
Tell the user:
- New slot created (letter name if on `main`, branch name otherwise)
- Which branch is checked out
- The full path to the working directory

## Edge Cases
- **Not in a git repo:** Inform user they need to run this from inside an existing slot
- **Clone fails:** Show error and suggest checking repo URL or network
- **Branch doesn't exist on remote:** Ask if they want to create it locally
