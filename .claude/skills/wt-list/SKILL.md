---
name: wt-list
description: "List all git worktrees with their paths, branches, and commits."
allowed-tools:
  - Bash(git worktree:*)
---

# /wt-list — List Worktrees

List all git worktrees in the current repository.

## Steps

1. Run `git worktree list` to get all worktrees.
2. Format the output clearly, showing for each worktree:
   - **Path** — the worktree directory
   - **Branch** — the checked-out branch
   - **Commit** — the HEAD commit (short hash)
3. Indicate which entry is the **main** worktree (the first one listed by git, typically the original clone).
4. If there are no linked worktrees (only the main one), tell the user: "No linked worktrees. Use `/wt` to create one."
