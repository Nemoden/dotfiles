---
description: Create a git worktree from a description or branch name
argument-hint: <description-or-branch-name> [--base <branch>]
allowed-tools:
  - Bash(git:*)
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(rm:*)
  - Bash(ls:*)
  - Bash(npm:*)
  - Bash(yarn:*)
  - Bash(pnpm:*)
  - Bash(bun:*)
  - Bash(df:*)
  - Read
  - Glob
---

# /wt — Create Worktree

Create a new git worktree with automatic branch name generation from natural-language descriptions.

## Input Format

```
/wt <description-or-branch-name> [--base <branch>]
```

**Examples:**
- `/wt working on something awesome` → generates branch name from description
- `/wt working on something awesome --base master` → generated name, based on master
- `/wt fix-auth-bug` → uses as-is (already a branch name)
- `/wt fix-auth-bug --base release/2.0` → explicit name + explicit base

## Step 1: Parse Input

1. Extract `--base <branch>` if present anywhere in the input. The word immediately after `--base` is the base branch. Remove the `--base <branch>` portion from the input.
2. If `--base` was not provided, the default base is the current branch (`HEAD`).
3. The remaining text (trimmed) is the **remainder** — either a description or a branch name.

## Step 2: Detect Description vs Branch Name

Apply this heuristic to the remainder:

- **Contains spaces** → it's a **natural-language description** → go to Step 3
- **No spaces** (kebab-case, snake_case, camelCase, slash-delimited, etc.) → it's an **explicit branch name** → skip to Step 4

## Step 3: Generate Branch Name (description path only)

Convert the description to a short kebab-case branch name:

1. Strip filler phrases: "working on", "I want to", "need to", "let's", "I need to", "we should", "going to", "try to", "start", "begin", "implement", "add support for"
2. Extract the core concept (2-4 meaningful words)
3. Convert to kebab-case (lowercase, hyphens between words)
4. Do NOT add any prefix like `feat/`, `fix/`, `chore/`, etc.
5. Keep it short and descriptive

**Examples:**
| Input | Generated Name |
|-------|---------------|
| "working on user authentication" | `user-authentication` |
| "I want to fix the login page bug" | `fix-login-page-bug` |
| "add dark mode support for the dashboard" | `dark-mode-dashboard` |
| "refactor database connection pooling" | `refactor-db-connection-pooling` |

**Tell the user** the generated branch name before proceeding. Example:
> Branch name: `user-authentication`

## Step 4: Validate

1. **Verify git repo:** Run `git rev-parse --git-dir`. If it fails, stop and tell the user this is not a git repository.
2. **Check branch doesn't exist:** Run `git branch --list <name>`. If the branch already exists, stop and tell the user. Suggest they use `git worktree add .worktrees/<name> <name>` to attach to the existing branch, or pick a different name.
3. **Check worktree directory doesn't exist:** If `.worktrees/<name>` already exists, stop and tell the user.
4. **Check disk space:** Run `df -h .` and warn if less than 1GB free.
5. **Verify base branch exists** (if explicitly provided via `--base`): Run `git rev-parse --verify <base>`. If it fails, stop and tell the user the base branch doesn't exist.

## Step 5: Create Worktree

```bash
git worktree add .worktrees/<name> -b <name> <base>
```

Where `<base>` is the resolved base branch (explicit or HEAD).

If this fails:
- **Locked worktree:** Tell user to run `git worktree unlock` or use `--force`
- **Other errors:** Show the error, attempt cleanup of any partial state (`rm -rf .worktrees/<name>` if directory was created, `git branch -d <name>` if branch was created), and report what happened.

## Step 6: Copy Environment Files

Copy these files from the repo root into the new worktree, **without overwriting** existing files:

Patterns to copy: `.env*`, `.nvmrc`, `.node-version`, `.npmrc`, `.tool-versions`

For each file matching these patterns in the repo root:
```bash
cp -n <file> .worktrees/<name>/
```

Use `cp -n` (no-clobber) to avoid overwriting. Track which files were copied for the final report.

## Step 7: Detect Package Manager and Install Dependencies

Check the new worktree directory for lock files to detect the package manager:

| Lock file | Manager | Install command |
|-----------|---------|----------------|
| `bun.lockb` or `bun.lock` | bun | `bun install` |
| `pnpm-lock.yaml` | pnpm | `pnpm install` |
| `yarn.lock` | yarn | `yarn install` |
| `package-lock.json` | npm | `npm install` |
| `package.json` (no lock) | npm | `npm install` |

If a `package.json` exists, run the appropriate install command inside the worktree directory. If install fails, warn the user but don't fail the overall operation — the worktree is still usable.

If no `package.json` exists, skip this step.

## Step 8: Update .gitignore

Check if `.worktrees/` or `.worktrees` appears in the repo root's `.gitignore`. If not, append `.worktrees/` to `.gitignore`.

## Step 9: Verify and Report

Run `git worktree list` to confirm the new worktree appears.

Report to the user:

```
Worktree created successfully!

  Location: .worktrees/<name>
  Branch:   <name>
  Base:     <base branch>
  Copied:   <list of env files copied, or "none">
  Install:  <package manager result or "skipped">
```
