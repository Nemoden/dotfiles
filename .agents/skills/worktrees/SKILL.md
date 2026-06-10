---
name: worktrees
description: >
  Personal convention for git worktrees. Use whenever creating, switching to, listing,
  moving, or removing a git worktree, or whenever starting feature work that needs an
  isolated branch (so you don't dirty the current checkout). Enforces the layout
  <repo>/.worktrees/<kebab-branch>/ — never sibling paths like ../<repo>-<branch>.
  Also use when the user says: "make a worktree", "spin up a worktree", "branch this off
  in a worktree", "let me play with this in isolation", "park this on a branch",
  or invokes /wt, /wt-list, /wt-remove, /wt-status.
---

# Worktrees — personal convention

## The rule

**Worktrees live at `<repo-root>/.worktrees/<branch-name>/`. Never at a sibling path.**

Sibling paths (e.g. `../svc-python-apg-835`) work but:

- Pollute `~/Projects/` with one dir per branch.
- Break `git worktree list` discoverability — you have to remember where you put them.
- Skip `.gitignore` integration. `.worktrees/` is ignored once; siblings are invisible to repo tooling.
- Break editors / tooling that scope to the repo root.

When you catch yourself about to run `git worktree add ../something`, **stop**. Use `.worktrees/<name>` instead. If a sibling worktree already exists, `git worktree move <sibling> <repo>/.worktrees/<name>` fixes it without losing the branch.

## Branch naming

- **kebab-case**, no slashes, no prefixes (`feat/`, `fix/`, etc).
- Project-specific prefix when the repo has a convention. For `svc-python`: `apg-<ticket>-<desc>` (e.g. `apg-835-unit-tests-ci`). Check `CLAUDE.md` of the repo for branch conventions before naming.
- Directory name **matches** branch name 1:1 — no transformations.

## Creating a worktree

When the user describes work that needs isolation, infer the branch name from context (ticket key + 2-4 word topic), then run:

```bash
git worktree add .worktrees/<branch-name> -b <branch-name> <base>
```

`<base>` defaults to current `HEAD`. Override with explicit base when the user mentions one (e.g. "off main", "based on apg-487-monorepo").

### Steps (in order)

1. **Verify git repo.** `git rev-parse --git-dir` — abort if not a repo.
2. **Resolve branch name.** From user input:
   - Looks like a branch name already (no spaces, kebab/snake/camel) → use as-is.
   - Natural language description → derive 2-4 word kebab-case. Strip fillers ("working on", "I want to", "let's", "implement", "add support for"). Add ticket prefix if the repo uses one.
3. **Tell the user the branch name** before creating, so they can object.
4. **Check uniqueness.** `git branch --list <name>` → abort if branch exists (suggest `git worktree add .worktrees/<name> <name>` to attach instead of create). `.worktrees/<name>` exists → abort.
5. **Disk space.** `df -h .` → warn if < 1GB free.
6. **Base branch exists** (if explicit). `git rev-parse --verify <base>` → abort if not.
7. **Create.** `git worktree add .worktrees/<name> -b <name> <base>`.
8. **Copy env files** that are typically gitignored but needed locally — without overwriting. Patterns: `.env*`, `.nvmrc`, `.node-version`, `.npmrc`, `.tool-versions`. Use `cp -n`. Track which files actually copied.
9. **Install deps** if package.json present. Detect manager by lock file:
   - `bun.lockb` / `bun.lock` → `bun install`
   - `pnpm-lock.yaml` → `pnpm install`
   - `yarn.lock` → `yarn install`
   - `package-lock.json` / no lock → `npm install`
   On Python repos with per-svc venvs (e.g. `svc-python`), direnv + nix flake handles activation on `cd` — don't pre-install Python deps.
10. **`.gitignore`.** If `.worktrees/` / `.worktrees` not in repo root `.gitignore`, append it.
11. **Verify.** `git worktree list` → confirm new entry. Report path + branch + base + copied files + install result.

## Listing / removing / status

- **List:** `git worktree list`
- **Remove:** `git worktree remove .worktrees/<name>` (clean), `git worktree remove --force` if dirty + intentional.
- **Move:** `git worktree move <old-path> .worktrees/<name>` — use when a sibling worktree needs to be brought into the convention.
- **Prune:** `git worktree prune` to clean stale entries when a worktree dir was deleted manually.

## Working *inside* a worktree

- Commits target the worktree's branch, not the parent repo's `HEAD`. Sanity check `git branch --show-current` if confused about which branch you're on.
- Worktrees share the same `.git/` storage but separate index + working tree. Pushes / fetches happen on the same remote.
- Don't checkout the same branch in two worktrees simultaneously — git refuses unless `--force`.

## Tells that you should be using a worktree

- About to start work on a different ticket while current dir has uncommitted changes.
- User says "park this", "let me try this on a branch", "spin off an experiment", "test this without disturbing main".
- Multi-PR cascade where each PR builds on the previous (stacked diffs) — one worktree per stack level.
- Long-running review or rebase that would block other work.

## Anti-patterns

- **Sibling paths** (`../<repo>-<branch>`). Use `.worktrees/`.
- **Worktree without a branch** (`git worktree add <path> <commit>`). Detached HEAD worktrees are confusing — always create with `-b <name>`.
- **Renaming the branch but not the worktree dir.** Keep them 1:1. If you rename one, run `git worktree move` to match.
- **Hand-deleting the worktree dir.** Use `git worktree remove` so git's metadata stays in sync. If you already nuked the dir, run `git worktree prune`.

## Slash commands

These exist as thin wrappers:

- `/wt <description-or-name> [--base <branch>]` — create.
- `/wt-list` — list.
- `/wt-remove <name>` — remove with safety checks.
- `/wt-status` — show current worktree + list.

The slash commands delegate to this skill's logic. When the user invokes them, follow the same rules as above.
