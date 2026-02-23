---
description: Show worktree status and list all worktrees
allowed-tools:
  - Bash(git:*)
---

Show the status of the current worktree and an overview of all worktrees.

1. **Current worktree info:**
   - Run `git rev-parse --show-toplevel` to get the current worktree path.
   - Run `git branch --show-current` to get the current branch.
   - Run `git status --short` to summarize uncommitted changes.
   - Run `git log @{upstream}.. --oneline 2>/dev/null` to check for unpushed commits (if upstream exists).

2. **Determine if this is the main worktree or a linked one:**
   - Run `git rev-parse --git-dir`. If it contains `/worktrees/`, this is a linked worktree. Otherwise, it's the main worktree.

3. **List all worktrees:**
   - Run `git worktree list` and format the output.

4. **Report:**

```
Current worktree:
  Path:     /path/to/worktree
  Branch:   <branch-name>
  Type:     main | linked
  Changes:  <N files modified, N untracked> or "clean"
  Unpushed: <N commits> or "up to date" or "no upstream"

All worktrees:
  (main)   /path/to/repo         [main]          abc1234
  (linked) .worktrees/feature-x  [feature-x]     def5678
```
