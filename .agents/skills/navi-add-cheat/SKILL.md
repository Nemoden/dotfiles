---
name: navi-add-cheat
description: Use when the user asks to save a shell command to navi cheatsheets — phrases like "add this to navi", "add to cheats", "add this to my cheatsheet", usually pasting a command (optionally with its output)
---

# Add cheat to navi cheatsheets

Repo: `~/Projects/navi-cheatsheets`. All `*.cheat` files live at repo root.

## If repo missing

Stop. Do not create files anywhere else. Suggest:

```sh
git clone git@github.com:Nemoden/navi-cheatsheets.git ~/Projects/navi-cheatsheets
```

## Steps

1. Pick file by tool: check existing `*.cheat` files and their `%` tag lines first — the file for a tool may not be named after the binary (`kubectl` → `kubernetes.cheat`, tags `% kubernetes, k8s`). Only when nothing matches, create `<tool>.cheat` starting with `% <tool>`.
2. Read the target file and match its style.
3. Write the entry — generalised, not the user's literal invocation:
   - `# <description>` — what the command does in general terms
   - the command with concrete values (profiles, regions, names, ids, search words) replaced by `<kebab-case-placeholders>`; keep flags and query structure intact
   - if a placeholder's values can be listed by a command, add a `$ placeholder: <command>` suggestion line in the file's `$` block
   - pasted output is context for understanding the command only — it never goes into the cheat
4. Append the entry before the `$` suggestion block (or at end of file if none).
5. Commit and push without asking — it is part of the task:
   `git add <file>` → commit message in history style (`Added <tool> <what>`) → `git pull --rebase` → `git push`.

## Common mistakes

| Mistake | Fix |
|---|---|
| Copying user's literal values into the cheat | Generalise to `<placeholders>` |
| Putting command output into the cheat | Output is context only |
| Stopping before commit/push to ask permission | Commit + push, then report |
| Repo missing → creating dirs or writing elsewhere | Suggest `git clone`, stop |
