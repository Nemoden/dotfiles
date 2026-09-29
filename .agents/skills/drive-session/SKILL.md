---
name: drive-session
description: Use when the user asks to find, watch, drive, message, nudge or compact another running Claude Code session, named by session id, name, tmux location or a free-text description of what it is doing; also when a watcher or recurring check on another session is needed, or a compact on another session did not happen.
---

# Drive another Claude Code session

## Overview

The user names a target session loosely ("the session updating prod refs in S3") and a job in free form ("compact it every 30 min at 60%", "tell it to rebase when CI goes green"). You find the one live session, confirm it, agree the job, then run it with a watcher and report after each check.

Run this skill from the main session. Subagents do not have `ListAgents`, `SendMessage` to peers or `CronCreate`.

Scripts are in this skill's `scripts/` directory. Run them as `python3 scripts/find-sessions.py`, `bash scripts/send.sh` and `bash scripts/watch.sh`, with absolute paths. For private tmux sockets, see the `tmux` skill.

## 1. Find the session

```bash
python3 scripts/find-sessions.py --window 1000000 <id | name | tmux | description words>
```

- The source is `~/.claude/sessions/<pid>.json`, which every live Claude process writes: session id, name, `formerNames`, tmux pane, cwd. The script adds the transcript path, the context tokens, the latest "away summary" and the last prompt.
- Ranking is word overlap. It gives a shortlist, not an answer. Read the top candidates' `doing:` lines and judge the match yourself.
- **Forks and renames share names.** A fork keeps the parent's name, and a rename moves the old name to `formerNames`. Always identify the target by **session id**, never by name or tmux title.
- **One session id can be live in two processes** (a resumed copy). `watch.sh` uses the entry with the newest registry update and logs a note. If you are unsure, show the user both panes.
- Your own session also shows up (the `ListAgents` tool prints your own name). Exclude it.
- Show the user the match as `name · session id · tmux target · context % · what it is doing`. If two candidates are close, ask. Do not guess.

## 2. Agree the job

- **Plain instruction** (text for the session to act on): use `SendMessage` to the peer name that `ListAgents` shows. It arrives as a message. It does not execute a slash command.
- **Slash command or keys** (`/compact`, `/model`, and so on): use `bash scripts/send.sh [--wait SECS] PANE "TEXT"`. It types only when the pane is idle.
- **Compact requests:** do not invent the text. Analyse the session first: its away summary, recent prompts, the plan or spec files it tracks, running agents, the current stage. Then propose 2-3 `/compact <focus>` options with trade-offs, for example:
  - A: keep the stage tracker and decisions, drop tool output (smallest).
  - B: A plus the last N messages verbatim (safest for mid-task work).
  - C: plain `/compact` (let Claude choose).
  The user picks the option. Write focus text that stays valid across stages ("the current stage", not "Stage 3"), because the watcher sends it again and again.
- Also confirm the threshold %, the check interval and the context window size. The status line may show it (for example `/1000k`). If it does not, a `compact_boundary` row's `preTokens` value above 200k proves a 1M window. Otherwise, ask.

## 3. Run it

Start the watcher in the private tmux server so it survives your turns:

```bash
SOCK=${TMPDIR:-/tmp}/claude-tmux-sockets/claude.sock; mkdir -p "$(dirname $SOCK)"
tmux -S $SOCK new -d -s watch-<ID8> "bash <abs>/scripts/watch.sh --session-id <ID> --window <N> \
  --threshold <P> --interval <SECS> --msg-file <scratchpad>/msg-<ID8>.txt --log <scratchpad>/watch-<ID8>.log"
```

`<ID8>` is the first 8 characters of the target session id. Other watchers can run on the same private tmux server, so every name comes from the target id: the tmux session, the message file, the log. Then a tmux name tells you which session a watcher drives, and a restart cannot kill a different watcher. Before you start, run `tmux -S $SOCK ls`. A watcher with a name like `compact-watch` does not show its target, so read its command with `tmux -S $SOCK list-panes -a -F '#{session_name} #{pane_start_command}'`.

`watch.sh` holds a lock per target session id (`$TMPDIR/drive-session-locks/<ID>.pid`). A second watcher for the same id exits with code 4 and names the pid that holds the lock. That is correct: two watchers on one session both send `/compact`. Stop the old watcher first, or keep it. `--dry-run` skips the lock, so you can test next to a live watcher.

Put the text in a file and pass `--msg-file`, so quotes in the text cannot break the command. The watcher reads the file once at start. To change the text, edit the file and restart the watcher. A restart moves the check times, so move the report cron too. Test first with `--once --dry-run`. The watcher finds the pane again from the registry on each check, so a session resumed in a new pane is still followed.

Checks run on a fixed schedule from the start time (start + k × interval), and after a `/compact` send the watcher logs `compact confirmed: pre -> post` or a WARNING.

**Report after each check:** `CronCreate` a recurring job 3-5 minutes after each check time (for example, watcher started at :48 with a 30 min interval → cron `52,22`). It reads the new log lines and tells the user in 1-3 lines: context %, whether a send happened, and any "skip" or error line. If context is at or over the threshold with no send, capture the pane with `-e`, find the cause and fix it. Cron jobs last only while this session is open and expire after 7 days. Tell the user this.

## Idle rules (why `send.sh` is shaped this way)

| Signal | Use it? |
|---|---|
| Registry `status` | **No.** It stays `busy` while background agents run, even when the prompt is free. |
| `esc to interrupt` or a spinner line `… (1m 5s` | Busy. |
| `Esc to close` or a permission question | Overlay open. The keys would go into the overlay. |
| Text after `❯` | Draft, **unless it is dim** (`ESC[2m`). Dim text is a placeholder suggestion. Strip it before you test. |
| Status-line % | **No.** It sometimes disappears. Use transcript usage. |

## Common mistakes

- **The watcher runs inside a private tmux server, so `$TMUX` points bare `tmux` calls at the wrong server.** You get "can't find pane", which the log shows as "not idle" forever. Both scripts `unset TMUX`.
- **Stale context after a compact.** Until the next reply, the last usage row still shows the old size. The `compact_boundary` row's `postTokens` value replaces it. Without this rule, the watcher compacts twice.
- **`<synthetic>` assistant rows or zero usage** (API errors) are not real readings. The scripts skip them.
- **Joined log reasons.** Each skip has its own reason (`working`, `typed draft in prompt`, `overlay…`). Read the reason before you "fix" the timing.
- **A real draft blocks every check.** Tell the user once which pane holds it. After that, report `blocked by your draft` in one line. Do not repeat the full explanation.
- **Typing with a real draft present** adds your text to the user's draft. Never clear a draft without asking.
