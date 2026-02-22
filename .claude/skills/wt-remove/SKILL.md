---
name: wt-remove
description: "Interactively remove a git worktree with safety checks for uncommitted changes and unpushed commits."
allowed-tools:
  - Bash(git:*)
  - Bash(rm:*)
---

# /wt-remove — Remove Worktree

Interactively remove a git worktree with safety checks.

## Step 1: List Worktrees

Run `git worktree list` to get all worktrees. Parse the output to identify:
- The **main worktree** (first entry) — this must NOT be removable
- All **linked worktrees** — these are candidates for removal

If there are no linked worktrees, tell the user: "No linked worktrees to remove."

## Step 2: Present Choices

If arguments were provided (a name or path), match them against the linked worktrees. If a match is found, select it directly without prompting.

Otherwise, show a numbered list of linked worktrees:

```
Linked worktrees:

  1. .worktrees/feature-auth  [feature-auth]  abc1234
  2. .worktrees/fix-login     [fix-login]     def5678

Which worktree do you want to remove? (number or name)
```

Use `AskUserQuestion` to let the user pick.

## Step 3: Safety Checks

Before removing, check the selected worktree for:

1. **Uncommitted changes:** Run `git -C <worktree-path> status --porcelain`. If there's output, warn the user:
   > This worktree has uncommitted changes. Removing it will lose these changes.

   Ask for confirmation to proceed.

2. **Unpushed commits:** Run `git -C <worktree-path> log @{upstream}.. --oneline 2>/dev/null`. If there are commits (and an upstream exists), warn:
   > This worktree has N unpushed commit(s).

   Ask for confirmation to proceed.

If either check triggers a warning and the user declines, abort the removal.

## Step 4: Remove Worktree

```bash
git worktree remove <worktree-path>
```

If this fails (e.g., dirty worktree and user confirmed), try with `--force`:
```bash
git worktree remove --force <worktree-path>
```

## Step 5: Branch Cleanup

After successful removal, ask the user if they also want to delete the branch:

> Worktree removed. Delete branch `<branch-name>` as well?

If yes:
```bash
git branch -d <branch-name>
```

If `-d` fails (unmerged), inform the user and ask if they want to force-delete with `-D`.

## Step 6: Verify

Run `git worktree list` to confirm the worktree is gone. Report success.
