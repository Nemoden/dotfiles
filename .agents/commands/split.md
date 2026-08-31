---
description: Fork this session into a new tmux pane, window, or session (tmux-level, not the builtin /fork)
---

Run `~/.agents/bin/claude-split` and say NOTHING.

Parse `$ARGUMENTS` as `<target>[: <prompt>]`:

- Target is one of `right`, `left`, `top`, `bottom`, `window`, `session`. Default to `right` when absent.
- Text after the first `:` is the prompt to send into the fork. No colon means fork idle.

```bash
~/.agents/bin/claude-split <target> '<prompt>'
```

Output rules, strict:

- The script is silent on success. Add nothing of your own: no echo of the ask, no confirmation, no pane id, no insight block, no summary. Emit zero characters.
- Speak only when the script writes to stderr or exits non-zero. Then give the error and stop.

Background facts, for answering later questions only. Never volunteer them:

- The fork is a separate session from `claude --resume <id> --fork-session`. It inherits history to the fork point, then diverges.
- `--fork-session` records no `forkedFrom` link. `/branch` inside the fork does record one.
- Do not drive a fork with `send-keys` after it starts.
