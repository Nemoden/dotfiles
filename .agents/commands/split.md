---
description: Fork this session into a new tmux pane, window, or session (tmux-level, not the builtin /fork)
---

Fork the current Claude Code session using `~/.agents/bin/claude-split`.

Parse `$ARGUMENTS` as `<target>[: <prompt>]`:

- Target is one of `right`, `left`, `top`, `bottom`, `window`, `session`. Default to `right` when absent.
- Text after the first `:` is the prompt to send into the fork. No colon means fork idle.

Run one command, then report the pane id back to the user:

```bash
~/.agents/bin/claude-split <target> '<prompt>'
```

Notes:

- The fork is a real separate session, created by `claude --resume <id> --fork-session`. It inherits history up to the fork point, then diverges. Nothing you do afterwards reaches it.
- `--fork-session` records no `forkedFrom` link to the parent. When the user wants that provenance in the transcript, tell them to run `/branch` inside the fork instead.
- Do not drive a fork with `send-keys` after it starts. Report the pane id and let the user take it, or use `SendMessage` when the session is reachable.
