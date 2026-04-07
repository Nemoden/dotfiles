---
name: ticket
description: >
  End-to-end Jira ticket workflow: deeply understand scope and WHY, verify prior work,
  branch, implement, review, ship as draft PR. Rigid workflow — understanding phase is a
  hard gate before any implementation.
  TRIGGER when: user says 'work on PROJ-123', 'pick up PROJ-123', 'start PROJ-123',
  'ticket PROJ-123', or references a Jira ticket key (KEY-NNN pattern) to start working on.
  Works with both epics and regular tickets.
---

# Ticket Workflow

Rigid skill. Follow phases in exact order. Do not skip phases.

Use the `jira` skill for all Jira operations (fetching tickets, transitions, comments, etc.).

## Detecting ticket type

Fetch the ticket. Check `issuetype.name`:
- **Epic**: Follow Epic Flow, then pick a child ticket and proceed to Phase 1
- **Task/Story/Bug**: Proceed directly to Phase 1

## Epic Flow

When pointed at an epic:

1. Read the epic description thoroughly — it often contains the implementation plan
2. Fetch all child tickets (JQL: `parent = {EPIC_KEY}`)
3. For each child ticket, note: summary, status, assignee
4. For completed tickets: find evidence in the codebase (`git log`, file changes). Do not trust Jira status alone
5. Assess: are any tickets missing from the epic? If gaps exist, propose creating them
6. Identify the next actionable ticket — first unblocked, unassigned pending ticket
7. Present to user: epic overview, what's done (with evidence), what's next, any gaps
8. Wait for user to confirm which ticket to pick up
9. Proceed to Phase 1 with the chosen ticket

## Phase 1: Understand

**HARD GATE. Do not write any code until understanding is confirmed with the user.**

### Read the ticket
- Fetch the ticket — read summary, description, status, linked issues
- If ticket has a parent epic: fetch and read the epic description too
- The epic description often has the architectural context and design decisions

### Check dependencies
- Identify tickets that block this one
- For blockers marked done: find evidence in the codebase, not just Jira status
- If evidence cannot be found, ask the user

### Check prior work
- For sibling tickets marked complete: verify with `git log`, file existence, deployed code
- If evidence cannot be found, ask the user

### Confirm understanding

Present to the user:
1. **What** — what we're building (1-2 sentences)
2. **Why** — business/technical motivation from ticket + epic context
3. **Scope** — what's in, what's explicitly out
4. **Dependencies** — what must exist first, does it?
5. **Approach** — high-level implementation plan

**Wait for explicit user confirmation before proceeding.**

## Phase 2: Setup

```bash
git checkout main && git pull
git checkout -b {TICKET_KEY}
```

Branch name is the ticket key only. No description suffix. Example: `PROJ-364`.

Move Jira ticket to "In Progress" (use the jira skill).

## Phase 3: Implement

- Follow the approach confirmed in Phase 1
- If the epic has an implementation plan, follow it
- Commit messages: `{TICKET_KEY}: description of change`
- If scope questions arise during implementation, stop and ask — do not guess

## Phase 4: Review

- Run tests (unit tests; flag integration tests if they exist)
- Review all changes: `git diff main...HEAD`
- Check for over-engineering, unnecessary abstractions, dead code
- Verify implementation matches the scope from Phase 1

## Phase 5: Ship

Suggest to the user (do NOT execute without confirmation):
- Create a draft PR: `gh pr create --draft --title "{TICKET_KEY}: short description"`
- PR body references the Jira ticket URL and summarizes changes
- Move Jira ticket to "In Review"
