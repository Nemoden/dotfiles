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

One-shot session recap. Help user re-orient when lost thread. NO new work, NO tools, NO read files for context — work purely from conversation history.

## Two modes

**Default (no arg)** — terse. 2-5 lines. User want know what session about in seconds, nothing more.

**`full`** (arg: `full`, `--full`, `detailed`) — structured breakdown w/ split pending actions.

## Default output

Bare list of what worked on, each line tagged w/ status. Nothing else.

```
We were:
- <thing 1> (done)
- <thing 2> (still on it)
- <thing 3> (blocked on <one-word reason>)
```

Statuses (pick one per line): `done`, `still on it`, `blocked on <X>`, `dropped`.

Rules default mode:
- **Hard cap: 5 lines incl "We were:" header.** If >4 things, collapse smaller or merge.
- **No IDs, paths, commit hashes** — that `full` job.
- **No preamble, no trailing offers.** First word `We`.
- If tool mode still active (plan mode, ralph, autopilot), append one line: `Note: <mode> still active.`
- If session genuinely single trivial exchange, one-liner beat template: `We were just <thing> — done.`

## `full` output

Structured. Use only when user pass `full`/`--full`/`detailed`. Aim <20 lines total.

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

Rules `full` mode:
- **Concrete over abstract.** "Created Confluence page id `6207865149`" beat "Set up doc". Include IDs, paths, branch names, commit hashes.
- **Split pending by owner.** "Pending from me" = blocked on user input. "Pending from you" = blocked on user doing thing themselves. If neither blocked, say so.
- **Surface side-quests.** If chat drifted into sub-topic, name on own line.
- **Flag stale state.** If tool mode still active or long-running process still in flight, mention bottom under `Note:` line.

## Rules both modes

- **No fluff.** No "Sure!", no "Here's recap…", no apologies, no "let me know if I missed anything".
- **No editorialising.** No suggestions, no "want me to…?" offers. User asked recap, not next steps.
- **No re-explanation of why** decisions made — user was there.
- **Recall, not insight.** No synthesise new conclusions.