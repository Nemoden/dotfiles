---
name: remind
description: >
  Quick session recap. Summarises the current chat in seconds — main topic(s),
  what's been done, and pending actions split between user and assistant.
  One-shot, no mode change, no files written. Trigger: /remind, "remind me",
  "remind me what this chat is about", "quick recap", "where are we",
  "what was this chat about", "catch me up", "tldr this chat".
---

# Remind

One-shot session recap. Help the user re-orient when they've lost the thread of a long conversation. Do NOT do new work, run tools, or read files for context — work purely from conversation history.

## Output shape

Keep it scannable. Aim for under 20 lines total. Use this structure:

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

## Rules

- **No fluff.** Skip preamble like "Sure! Here's a recap…". Start with `**Topic:**`.
- **Concrete over abstract.** "Created Confluence page id `6207865149`" beats "Set up a doc". Include IDs, paths, branch names, commit hashes — anything the user can act on.
- **Split pending by owner.** "Pending from me" = blocked on user input. "Pending from you" = blocked on user doing something themselves. If neither side is blocked, say so.
- **Surface side-quests.** If the chat drifted into a sub-topic (e.g. a question that spawned mid-task), name it on its own line so the user remembers it happened.
- **Flag stale state.** If a tool mode is still active (plan mode, ralph, autopilot) or a long-running process is still in flight, mention it at the bottom under a `Note:` line.
- **Don't editorialise.** Don't add suggestions, opinions, or "want me to…?" offers. The user asked for a recap, not next steps. They'll ask for those separately.

## What NOT to include

- Re-explanation of *why* a decision was made (the user was there).
- Verbatim code snippets or full file paths from earlier replies (cite IDs/names instead).
- Apologies, hedging, "let me know if I missed anything".
- New synthesis or analysis. This is recall, not insight.

## When to skip the structure

If the chat is genuinely tiny (1-2 turns, single trivial task), a one-line answer beats the template. Use judgement — the template is the floor for non-trivial sessions, not a mandate.
