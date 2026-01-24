---
name: release
description: Create a git tag and GitHub release with changelog from merged PRs
allowed-tools: Bash(gh:*), Bash(git:*), AskUserQuestion
model: haiku
---

# Create GitHub Release

## Step 1: Get Latest Release
```bash
gh release list --limit 1
```
Extract the latest tag (e.g., `v1.2.0`). If no releases exist, this is the first release.

## Step 2: Get Merged PRs Since Last Release
```bash
gh pr list --state merged --base main --json number,title,labels,mergedAt --limit 100
```
Filter PRs merged after the last release date. If first release, include all merged PRs.

## Step 3: Ask for Version
Show the last release version for reference, then ask the user to type the new version:

```
"Last release was vX.Y.Z. What version do you want to release?"
```

Let the user type any version they want (e.g., v1.0.0, v2.0.0-beta.1, v1.2.3-rc.1).
Do not suggest or auto-calculate - just ask and accept their input.

## Step 4: Generate Grouped Changelog
Organize PRs into categories based on title prefixes or labels:

**Features** (feat:, feature, enhancement)
- PR title (#number)

**Fixes** (fix:, bug, bugfix)
- PR title (#number)

**Improvements** (refactor:, perf:, chore:, docs:)
- PR title (#number)

If a PR doesn't match any category, put it under "Other Changes".

## Step 5: Present Draft Release Notes
Show the user the formatted release notes:

```markdown
## What's New in vX.Y.Z

### Features
- Feature description (#123)

### Fixes
- Fix description (#124)

### Improvements
- Improvement description (#125)
```

**Use AskUserQuestion tool** for approval:
```
Question: "Do these release notes look good?"
Options:
- "Yes, create release" - Proceed with release
- "Edit notes" - Let user provide adjustments
- "Cancel" - Abort release
```

## Step 6: Create Tag and Push
Only proceed if user approved in Step 5.

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Step 7: Create GitHub Release
```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "$(cat <<'EOF'
<formatted release notes from Step 5>
EOF
)"
```

## Step 8: Final Output
End with:
- Release URL
- Tag name
- Summary of what was included

## Edge Cases
- **No merged PRs since last release:** Inform user "No changes to release" and abort
- **First release:** Note this is the initial release, suggest v1.0.0 or v0.1.0
- **User on wrong branch:** Warn if not on main branch
- **Uncommitted changes:** Warn user and ask if they want to proceed anyway
