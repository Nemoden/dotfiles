---
name: handoff
description: Use when the user asks for a handoff prompt, next agent prompt, or wants to prepare context for a new session to continue current work.
---

# Agent Handoff Prompt Generator

## Overview

Generates a self-contained prompt for the next agent to pick up where the current session left off. Avoids deictic references ("this session", "recently") that lose meaning once context resets.

## Rules

- Use absolute dates (2026-04-22), not relative ("this session", "recently", "just")
- Anchor completed work to commits, ticket names, or file paths — not conversation events
- Include only what a cold-start agent needs to act — not a session summary
- Point to existing docs (CLAUDE.md, specs, ADRs) rather than restating their content

## What to Include

1. **Project identity** — one-liner + where to find full context (e.g. CLAUDE.md)
2. **What was completed** — with dates, commit SHAs, or named artifacts
3. **Current repo state** — branch, clean/dirty, ahead/behind origin
4. **Discovered constraints/gotchas** — things learned during work that aren't obvious from code
5. **Open questions** — unresolved decisions or uncertainties next agent should know about
6. **What's next** — ordered by priority; enough for the agent to pick the first task
7. **How to start** — exact first action (command, file to read, etc.)

## Steps

1. Run `git log -1 --pretty="%H %s"` — last commit for anchor
2. Run `git status --short` — current state
3. **Context audit** — scan session for knowledge not persisted in code, tickets, or docs:
   - Decisions made and why
   - Gotchas or surprises discovered
   - Open questions still unresolved
   - Constraints or assumptions learned during work
4. **Persistence recommendations** — for each audited item, recommend where it should live (ticket, doc, CLAUDE.md, project memory, inline in handoff). Do NOT create artifacts — list recommendations for user approval. Check CLAUDE.md, memory, and git history to discover what systems the project uses (Jira, Linear, Confluence, in-repo docs, etc.) — use those, don't invent new ones.
5. Identify remaining work from whatever tracking system is in use (tickets dir, TODO file, linear, etc.)
6. Fill the template below — adapt structure to the project
7. Output as a fenced code block the user can copy

## Template

```
We're working on **[PROJECT NAME]** — [one-line description].
[Where to find full context, e.g. "See `CLAUDE.md` for project conventions."]

**Completed as of [YYYY-MM-DD]:**
- [Thing done] ([commit SHA or ticket name or file])
- [Thing done] ([commit SHA or ticket name or file])

**Current state:**
- Branch: `[branch]`, [clean / N files changed], [N commits ahead of origin]
- [Any in-progress work or blockers]

**Discovered constraints/gotchas:**
- [Thing learned that isn't obvious from code]

**Open questions:**
- [Unresolved decision or uncertainty]

**What's next (priority order):**
1. [Task] — [one-line objective]
2. [Task] — [one-line objective]

**To start:** [Exact first action — e.g. read a file, run a command, open a ticket]
```
