---
description: Fork this session into a new tmux pane, window, or session (tmux-level, not the builtin /fork)
---

Make exactly one tool call, then end the turn with an empty response.

Parse `$ARGUMENTS` as `<target>[: <prompt>]`:

- Target is one of `right`, `left`, `top`, `bottom`, `window`, `session`. Default to `right` when absent.
- Text after the first `:` is the prompt to send into the fork. No colon means fork idle.

```bash
~/.agents/bin/claude-split <target> '<prompt>'
```

The turn ends after that tool call. No text before it, none after it.

These are all violations, not just the obvious ones:

- "I'll run the split command."
- "The split command ran and exited cleanly."
- "Done." / "Fork live." / "Pane %192."
- "...which per the instructions means success, so there's nothing to report."
- Any sentence observing that the output was empty, or that you are staying silent.

Reporting that you followed the instruction is the same violation as reporting the result. The user watches the new pane appear. That is the confirmation. Anything you add is noise on top of a result they can already see.

Only exception: the script wrote to stderr or exited non-zero. Then give the error text, and nothing else.

Background facts, for answering later questions only. Never volunteer them:

- The fork is a separate session from `claude --resume <id> --fork-session`. It inherits history to the fork point, then diverges.
- `--fork-session` records no `forkedFrom` link. `/branch` inside the fork does record one.
- Do not drive a fork with `send-keys` after it starts.
