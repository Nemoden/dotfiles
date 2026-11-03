---
name: restore-agent-sessions
description: Use only when the user runs /restore-agent-sessions, to snapshot the live tmux layout with the Claude Code, Codex or pi session in each pane, list snapshots, or rebuild tmux sessions, windows and panes after a crash, reboot, dead battery or killed tmux server.
disable-model-invocation: true
argument-hint: "[snapshot | list | restore [FILE] [--only a,b] [--skip a,b] | rebuild | install | uninstall]"
---

# Restore agent sessions into tmux

## Overview

A snapshot records each tmux session, window (name, order, pane geometry) and pane (directory, command, agent session id). A restore rebuilds that layout and resumes the session in each agent pane:

| Tool | The snapshot gets the session id from | The restore runs |
|---|---|---|
| Claude Code | Claude's process registry (`~/.claude/sessions/`) | `claude -r <id>` |
| Codex | the tmux pane title, which holds the thread id after `install` | `codex resume <id>` |
| pi | the record that `pi-extension.ts` writes to `~/.cache/restore-agent-sessions/registry/` | `pi --session <file>` |

With no snapshot, `rebuild` gets the layout from the Claude session transcripts instead. `rebuild`, the resume message and the reply check work for Claude sessions only.

Scripts are in `scripts/` next to this file. Run them as `python3 -I <abs path>/scripts/<name>.py`. Snapshots are in `~/.cache/restore-agent-sessions/snapshots/`. Keep other work files in the scratchpad.

## Setup on a machine

1. `dot pull`. It brings this skill, its link in `~/.claude/skills/`, and the link `~/.pi/agent/extensions/restore-agent-sessions.ts` to `pi-extension.ts`. pi loads the extension at its next start.
2. Run `/restore-agent-sessions install` once. It adds the launchd job, and it adds `"thread-id"` to `terminal_title` in `~/.codex/config.toml`. Both are local to the machine, so the dotfiles cannot hold them.

Codex and pi windows that were open before the setup do not report their ids. Restart them.

## Modes (the argument)

| Argument | Do |
|---|---|
| `snapshot` | `snapshot.py`, then report the line it prints. |
| `list` | `snapshot.py --list`. |
| `install` / `uninstall` | `snapshot.py --install` adds a launchd job that takes a snapshot every 10 minutes, and adds the thread id to the Codex title. The job saves only when the layout changed and keeps 200. `--uninstall` removes the job. |
| `restore [FILE]`, or no argument | Restore flow below. With no FILE, use `auto`: the newest snapshot taken before the last boot. |
| `rebuild` | Rebuild flow below. Use it when no snapshot exists or the snapshot is too old. |

## Restore flow

1. `restore.py auto|FILE plan.json --dry-run [--only ..] [--skip ..]`. The dry run prints each pane and what it runs, plus notes on what it leaves out: live sessions, windows that exist already, missing directories.
2. **Show the user the plan and STOP.** Group by tmux session: windows, agent session ids (8 chars) with their tool, other panes ("shell, was: nvim"). Ask which tmux sessions to restore and which Claude sessions get the resume message. Recommend the message only for sessions that were mid-task, plus watchers.
3. Run without `--dry-run`. Then do steps 7-9 below.

## Rebuild flow (no snapshot)

1. Run `tmux ls` and `sysctl -n kern.boottime`. Existing tmux sessions get windows appended, and their current windows stay as they are.
2. `scan.py --days 7 --exclude <own session id> --json OUT`. It prints each session with: `OPEN(burst)` (open at the crash: the newest same-second write burst before boot), `OPEN(active)` (written after that burst), `closed?`, `LIVE`, `START-DIR-GONE`, start dir, branch, Claude's own recap and the last prompt.
3. Get old tmux names from the transcripts (`tmux session <name>`, `new-session -s`, `rename-window`).
4. Propose a layout as in restore step 2, and STOP for the user's OK. Name the watchers, the forks (same `customTitle`) and the sessions with nothing pending.
5. Write the layout file in the format at the top of `restore.py`. A watcher goes in a `"split": "25%"` pane to the right of its target.
6. Dry run, then run `restore.py`.

## After every restore

7. **Verify every pane.** For each pane in `plan.json`, capture the pane. Confirm the input prompt: `❯` and the session id for Claude, `›` for Codex, the status line with token counts for pi. Handle dialogs (see table).
8. **Send the message** (Claude sessions only). Write `messages.json` (session id → extra text). `{pane:<id>}` becomes that session's new pane id. Every watcher gets its target's new pane id and must set up its timers again. Run `nudge.py plan.json messages.json`.
9. **Read the replies from the transcripts** (Claude sessions only). Run `check.py <ids>` in a background loop until `done=True`. Report: who needs the user (with the question), who continues, and who is finished. Give `tmux attach -t <name>`.

## Problems found in real runs

| Symptom | Cause | Fix |
|---|---|---|
| Restore shows only the layout made after the reboot | The newest snapshot is from after the reboot | `auto` takes the newest snapshot from BEFORE boot |
| Fork comes back as its parent | `claude --resume X --fork-session` gets a new id, so X on its command line is the parent | The snapshot takes the id from the registry and never from a fork's command line |
| Old `✓` or `⛔` marks frozen in window names | Hooks add live state marks to names | Marks are stripped on snapshot and when names are compared |
| Session shows as live after a reboot | The registry file outlived its process, and the OS reused the pid | The live check confirms that the pid belongs to `claude` or `pi` |
| Message looks "stuck in input" | A sent message and an unsent draft look the same on screen | Judge delivery from the transcript (`check.py`) |
| `claude -r` cannot find a session | It looks under the START dir | Snapshots record the launch dir. `rebuild` uses `start_cwd`, or the repo root if that dir is gone |
| Watcher compacts nothing | It still targets the old pane id | Give it `{pane:<target id>}` in its message |
| "Do you trust this folder" in one pane | Many processes wrote the config at once | If other sessions in that dir opened without it, choose Yes. Otherwise ask the user |
| Machine stalls | Dozens of transcripts load at once | Launches wait 3 s each. Warn when the count × 0.7 GB nears RAM |
| `sleep 25` blocked by the harness | Foreground sleep is blocked | Loop inside python, or `run_in_background` |
| tmux reports `fish` as the command of a Codex or pi pane | tmux names the shell, not the program in it | The snapshot looks for `claude`, `codex` and `pi` in the pane's process tree |
| A Codex hook reports the wrong pane | Codex runs hooks in one server process that all Codex windows share, with the environment of the window that started it | The snapshot reads the thread id from the pane title. Do not use Codex hooks for this |
| Codex pane has no session id ("codex without a known session id") | The Codex window started before `install`, or it has no message yet, so no conversation file exists | Restart that Codex window. A window with no message has nothing to restore |
| Codex shows "Update available" and waits | Codex checks for updates at start | Choose `2. Skip` (Down, Enter). Do not update during a restore |
| pi record stays after its pane closes | pi removes its record only on a clean exit | The snapshot removes the records of processes that no longer run |
