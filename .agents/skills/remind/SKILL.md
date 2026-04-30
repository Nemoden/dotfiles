---
name: remind
description: >
  Ultra-quick session recap in 2 seconds. Default: 2-5 lines, what we were doing
  and its status. Use `full` arg for the structured breakdown with split pending
  actions. One-shot, no mode change, no files written. Trigger: /remind,
  "remind me", "remind me what this chat is about", "quick recap", "where are
  we", "what was this chat about", "catch me up", "tldr this chat".
---

# Remind

One-shot session recap. Help the user re-orient when they've lost the thread. Do NOT do new work, run tools, or read files for context — work purely from conversation history.

## Two modes

**Default (no arg)** — terse. 2-5 lines. The user wants to know what the session is about in seconds, nothing more.

**`full`** (arg: `full`, `--full`, or `detailed`) — structured breakdown with split pending actions.

## Default output

Bare list of what was being worked on, each line tagged with status. Nothing else.

```
We were:
- <thing 1> (done)
- <thing 2> (still on it)
- <thing 3> (blocked on <one-word reason>)
```

Statuses (pick one per line): `done`, `still on it`, `blocked on <X>`, `dropped`.

Rules for default mode:
- **Hard cap: 5 lines including the "We were:" header.** If there are more than 4 things, collapse the smaller ones or merge them.
- **No IDs, paths, or commit hashes** — that's what `full` is for.
- **No preamble, no trailing offers.** First word of the response is `We`.
- If a tool mode is still active (plan mode, ralph, autopilot), append one line: `Note: <mode> still active.`
- If the session is genuinely a single trivial exchange, a one-liner beats the template: `We were just <thing> — done.`

## `full` output

Structured. Use this only when the user passes `full`/`--full`/`detailed`. Aim for under 20 lines total.

```
**Topic:** <one line — what the chat is actually about>

**Done:**
- <bullet — completed action with concrete artifact: file, page id, PR, commit, etc.>
- <bullet>

**Pending (from me, awaiting your call):**
- <bullet — decision the assistant is waiting on>
- <bullet>

**Pending (from you):**
- <bullet — work the user still has to do, or "none — ball's in your court on the above">
```

Rules for `full` mode:
- **Concrete over abstract.** "Created Confluence page id `6207865149`" beats "Set up a doc". Include IDs, paths, branch names, commit hashes.
- **Split pending by owner.** "Pending from me" = blocked on user input. "Pending from you" = blocked on user doing something themselves. If neither side is blocked, say so.
- **Surface side-quests.** If the chat drifted into a sub-topic, name it on its own line.
- **Flag stale state.** If a tool mode is still active or a long-running process is still in flight, mention it at the bottom under a `Note:` line.

## Rules for both modes

- **No fluff.** No "Sure!", no "Here's a recap…", no apologies, no "let me know if I missed anything".
- **No editorialising.** No suggestions, no "want me to…?" offers. The user asked for a recap, not next steps.
- **No re-explanation of why** decisions were made — the user was there.
- **Recall, not insight.** Don't synthesise new conclusions.
