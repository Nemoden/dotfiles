---
name: restore-agent-sessions-add-agent
description: Use when the user asks to add support for another coding agent or CLI tool (for example Antigravity, omp, Gemini CLI, Aider, OpenCode) to restore-agent-sessions, or says such a tool's tmux panes do not come back after a restore.
---

# Add an agent tool to restore-agent-sessions

## Overview

restore-agent-sessions (`~/.agents/skills/restore-agent-sessions/`) resumes each agent pane after a crash. For each tool it must know which conversation runs in which tmux pane. Find that link by running the real tool in a throwaway tmux session. Do not use docs or memory for this: docs do not show which process runs a hook, and that decides if a link is correct.

Read `scripts/snapshot.py` and `scripts/restore.py` first. Each tool is one branch in `read_layout()`, one branch in `resume_cmd()` and one line in the docstring table.

## Facts to find

| Fact | How to find it |
|---|---|
| Process name | `ps -o comm= -p <pid>` for the process below the pane's shell. The snapshot matches this name in `AGENTS`. `pgrep -l` can show another name (pi shows `node` there). |
| Where conversations live, and the id format | `find ~/.<tool> -newer <marker file> -type f` after one message |
| Resume command | `<tool> --help`, then test it: the old message must show on screen |
| An exact link from pane to conversation | The probes below |
| Dialogs at start | Capture the pane after each start |

## Link options, best first

1. **The tool's own record per process**, with the pid or the pane (Claude's `~/.claude/sessions/<pid>.json`).
2. **The pane title.** Some tools can put the id in the terminal title (Codex `tui.terminal_title` with `thread-id`). Read it with `tmux display -p -t <pane> '#{pane_title}'`. Check for a cut id, and match a prefix to one file.
3. **An extension or hook that runs inside the pane's process** and writes `~/.cache/restore-agent-sessions/registry/<tool>-<pid>.json` (pi: `pi-extension.ts`). The pid in the file name makes a new process overwrite a stale record.
4. **The command line** (`-r <id>`, `resume <id>`, `--session <file>`). Always add it as the fallback: a pane that a restore starts has no other link until its first message.

Do not use the newest file in the pane's directory as the link. It fails when two panes run the tool in one directory.

## Probe rules

- Work in a tmux session named `probe`, in a folder in the scratchpad. Never send keys to the user's panes.
- Prefer a one-time override: a config-dir variable (`CODEX_HOME`, `PI_CODING_AGENT_DIR`) pointing to a scratchpad copy, or a flag that loads one extension (`pi -e file.ts`). Link the auth file; do not copy it.
- Send one short message (`reply with the single word ok`). Many tools write no conversation file before the first message.
- Flags named `--dangerously-*` are blocked. Use the tool's own trust prompt.
- Send keys one at a time with a short wait between them (`python3 -c 'import time; time.sleep(0.5)'`, because foreground `sleep` is blocked).

**Hook test.** Log what the hook sees:

```sh
#!/bin/sh
{ echo "=== TMUX_PANE=$TMUX_PANE ppid=$PPID"
  p=$PPID; for i in 1 2 3 4; do ps -o pid=,ppid=,comm= -p $p; p=$(ps -o ppid= -p $p | tr -d ' '); done
  echo "stdin:"; cat; echo; } >> "$LOG"
```

The parent chain must lead to the pane's shell and then `tmux`. Then close the probe session, start a second window, and run the test again. If the second log shows the first pane id, or a parent with ppid 1, the tool shares one server between windows, and the hook cannot name its pane. Codex fails this test.

## Add the tool

1. `snapshot.py`: add the name to `AGENTS`, add a branch in `read_layout()` (exact link, then command line), and add a row to the module docstring. Extra fields a resume needs go on the pane (pi: `session_file`). If the tool writes registry records, give `pi_registry()` a tool-name argument so both tools use one reader.
2. `restore.py`: add a branch to `resume_cmd()`. Quote paths with `shlex.quote`.
3. Code that the tool loads (an extension or plugin) lives in the skill folder. Link it into the tool's config folder with a relative link, so it works under any home path.
4. A setting in a machine-local config file goes in `install` (pattern: `codex_title()`). Make it idempotent, check the result parses, print what changed, and copy the file to the scratchpad first.
5. `SKILL.md` of restore-agent-sessions: add a row to the Overview table, and a row to the Problems table for each surprise.

## End-to-end test

1. Start the tool in `probe`, send the message, and read the live layout. `python3 -I` leaves the script folder off the module path, so add it: `sys.path.insert(0, "<skill>/scripts"); import snapshot; snapshot.read_layout()`.
2. Save the `probe` session from that layout to a scratchpad file.
3. Dry run with `probe` still open: expect "window exists already". Run a copy with another window name: expect "is live already".
4. Kill `probe`, run `restore.py <file> <plan> --only probe`, and confirm the old message on screen.
5. Kill `probe` again. If the tool writes registry records, confirm the snapshot removes the stale one.
6. Delete the test conversations you made. If the tool also keeps them in a database, leave them and tell the user.

## Commit

The skill is in the public dotfiles repo (`dot`). Stage named paths with `dot add -f`, then unstage `__pycache__`. Commit with caveman-commit. Fish has no `<<<`, so write the message to a file and use `dot commit -F <file>`. Then `dot pull --rebase` and `dot push`.

## Common mistakes

| Mistake | Fix |
|---|---|
| Trust `pane_current_command` | tmux names the shell (`fish`). Walk the process tree. |
| Hook test with one window only | Test a second window after the first closes. |
| Process-tree probe run with a `-c` override | Overrides can change how the tool runs (Codex runs without its shared server). Use a config-dir copy for process questions. |
| Expect the hook to fire on resume | Codex fires `SessionStart` only at the first message. Keep the command-line fallback. |
| Expect a clean exit to remove records | tmux kill skips clean shutdown. The snapshot removes records of dead pids. |
| Stop at an update prompt | Choose Skip. Add the prompt to the Problems table. |
