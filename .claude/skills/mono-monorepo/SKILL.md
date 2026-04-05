---
name: mono-monorepo
description: "Scaffold and manage mono-monorepo projects — a single repo with two internal structures: /code/ for all implementation (apps, libs, migrations) and /project/ for all knowledge (ADRs, SPECs, tickets, samples, ideas). Use when: user says 'mono-monorepo', or 'monomonorepo', 'scaffold a project', 'new project', 'create a monorepo', 'add an app', 'add app', 'new app', 'add adr', 'add spec', 'add ticket', 'new ticket', 'start ticket', 'done ticket', 'block ticket', 'unblock ticket', or asks about mono-monorepo structure. Also use when user wants to bootstrap a new project with structured documentation and filesystem-based ticket tracking."
---

# Mono-Monorepo

A mono-monorepo is a single repository containing two parallel structures:

- **`/code/`** — all implementation: apps, shared libs, migrations, tooling
- **`/project/`** — all knowledge: ADRs, SPECs, tickets, samples, ideas

The key insight: `/project/` often has meaningful content before `/code/` has a single line. Design decisions, specs, and tickets come first. Code follows.

## Operations

### 1. init — Scaffold a New Mono-Monorepo

**Trigger:** "scaffold a project", "new project", "create a monorepo", "mono-monorepo init"

**Ask the user:**
1. Project name (kebab-case slug) + one-line description
2. Use Nix flake + direnv for dev environment? (yes / no / skip)
3. Initialize git repo + initial commit? (yes / no)

**Run:** `python3 <skill_dir>/scripts/init.py <project-name> --description "<desc>" --path <target-dir>` with optional `--nix` and `--git-init` flags.

**What it creates:**

```
<project-name>/
├── CLAUDE.md              # Minimal universal AI assistant instructions
├── AGENTS.md              # Points to CLAUDE.md
├── README.md              # Project name + description + setup stub
├── .gitignore
├── justfile               # Ticket lifecycle commands
├── flake.nix              # (only if --nix)
├── .envrc                 # (only if --nix)
├── code/
│   ├── apps/
│   │   └── .gitkeep
│   └── migrations/
│       └── .gitkeep
└── project/
    ├── README.md          # Documentation guide
    ├── adr/
    │   └── .gitkeep
    ├── specs/
    │   └── .gitkeep
    ├── tickets/
    │   ├── README.md      # Ticket system guide
    │   ├── todo/
    │   │   └── .gitkeep
    │   ├── in-progress/
    │   │   └── .gitkeep
    │   ├── blocked/
    │   │   └── .gitkeep
    │   └── done/
    │       └── .gitkeep
    ├── samples/
    │   └── .gitkeep
    └── ideas/
        └── .gitkeep
```

### 2. add-app — Add an App to the Monorepo

**Trigger:** "add an app", "new app", "add app <name>"

**Ask the user:**
1. App name (kebab-case)
2. Language/runtime: Python, Node, Go, or other

**Run:** `python3 <skill_dir>/scripts/add_app.py <app-name> --lang <language> --repo-root <root>`

**What it creates per language:**

**Python:**
```
code/apps/<name>/
├── __init__.py
├── pyproject.toml
├── tests/
│   └── __init__.py
└── README.md
```

**Node/TypeScript:**
```
code/apps/<name>/
├── package.json
├── src/
│   └── index.ts
├── tests/
└── README.md
```

**Go:**
```
code/apps/<name>/
├── go.mod
├── main.go
├── main_test.go
└── README.md
```

**Other:** Creates just the directory, `README.md`, and a `tests/` stub. User fills in the rest.

### 3. add-adr — Create a New ADR

**Trigger:** "add adr", "new adr", "create adr"

**Ask the user:** ADR title (e.g., "Work Queue and Leasing").

**Procedure:**
1. Scan `project/adr/` for existing files, find highest `NNNN` prefix
2. Create `project/adr/NNNN+1-<slugified-title>.md` with template:

```markdown
# ADR NNNN: <Title>

## Status

Proposed

## Context

[What problem are we solving? What constraints exist?]

## Decision

[What did we decide?]

## Consequences

### Positive

-

### Negative

-

## Alternatives Considered

###

[What else was considered and why was it rejected?]
```

### 4. add-spec — Create a New SPEC

**Trigger:** "add spec", "new spec", "create spec"

**Ask the user:** SPEC title and optionally related ADRs.

**Procedure:**
1. Scan `project/specs/` for highest `NNNN` prefix
2. Create `project/specs/NNNN+1-<slugified-title>.md` with template:

```markdown
# SPEC-NNNN: <Title>

**Version:** 1.0
**Status:** Draft
**Related ADRs:** [ADR-XXXX]

## Overview

[What this spec defines]

## Design

[Detailed design sections]
```

### 5. add-ticket — Create a New Ticket

**Trigger:** "add ticket", "new ticket", "create ticket"

**Ask the user:** Ticket name (descriptive, kebab-case).

**Procedure:** Create `project/tickets/todo/<name>.md` with template:

```markdown
# <Title>

Brief description.

## What to Build

-

## Done When

- [ ]
- [ ] Tests pass

## Notes

```

### 6. Ticket Lifecycle

**Trigger:** "start ticket", "done ticket", "block ticket", "unblock ticket", or contextually when finishing implementation work.

**State machine:** Status = directory location. Transitions via `git mv`.

| Transition | Command | After |
|---|---|---|
| Start work | `git mv project/tickets/todo/<name>.md project/tickets/in-progress/` | — |
| Complete | `git mv project/tickets/in-progress/<name>.md project/tickets/done/` | → [Post-Completion Review](#7-post-completion-review) |
| Block | `git mv project/tickets/in-progress/<name>.md project/tickets/blocked/` | — |
| Unblock | `git mv project/tickets/blocked/<name>.md project/tickets/todo/` | — |

After each transition, commit: `git commit -m "<action>: <ticket-name>"` where action is `start`, `done`, `blocked`, or `unblocked`.

**Contextual use:** When you finish implementing a ticket's acceptance criteria, proactively suggest moving it to done.

### 7. Post-Completion Review

**Trigger:** Automatically after every "Complete" ticket transition.

**Purpose:** Run three parallel reviewers against the completed ticket to catch architectural gaps, documentation inconsistencies, and broken cross-references before they accumulate.

#### Step 1 — Assemble Context

Gather the following before spawning any agents:

1. **Ticket content** — read `project/tickets/done/<ticket>.md`
2. **Diff** — find the commit that moved this ticket to `in-progress/`:
   ```
   git log --oneline --diff-filter=A -- project/tickets/in-progress/<ticket>.md
   ```
   Then get all changes since that commit:
   ```
   git diff <in-progress-commit> HEAD
   ```
   If no in-progress commit is found, ask the user to clarify the diff scope before proceeding.
3. **Linked SPECs/ADRs** — scan the ticket file for explicit references (e.g. `SPEC-0001`, `ADR-0002`). If none found, fuzzy-match the ticket slug against filenames in `project/specs/` and `project/adr/`. Read all matched files.

#### Step 2 — Spawn Three Parallel Agents

Use `superpowers:dispatching-parallel-agents` to run all three simultaneously:

| Agent | Focus |
|---|---|
| `mono-monorepo:architecture-reviewer` | Does implementation match SPEC/ADR? Implicit decisions? Undocumented dependencies? |
| `mono-monorepo:consistency-checker` | Are acceptance criteria met? Contradictions introduced? Stale specs or ideas? |
| `mono-monorepo:cross-ref-checker` | Broken or missing cross-references after this ticket's changes? |

Pass each agent: the ticket content, the full diff, and the linked SPEC/ADR content.

#### Step 3 — Output

1. **Write** combined findings to `project/tickets/done/<ticket>-review.md`
2. **Print** a summary to stdout

The review file format:

```markdown
# Review: <ticket-name>

## Architecture Review
<findings from mono-monorepo:architecture-reviewer>

## Consistency Check
<findings from mono-monorepo:consistency-checker>

## Cross-Reference Check
<findings from mono-monorepo:cross-ref-checker>
```

## Conventions

**Naming:**
- ADRs: `NNNN-descriptive-title.md` (zero-padded 4 digits)
- SPECs: `NNNN-descriptive-title.md` (zero-padded 4 digits)
- Tickets: `descriptive-name.md` (no numeric prefix)

**Document reading order:** Ticket -> SPEC -> ADR -> Samples

**Order of truth (precedence):** Ticket > SPEC > ADR > Samples. If documents conflict, follow the higher-precedence one and flag the conflict to the user.

**Never modify files under `/project/`** without explicit permission unless fixing clear errors.

**Required agents:** The post-completion review depends on three agents that must exist at `~/.claude/agents/mono-monorepo/`:
- `architecture-reviewer.md` (name: `mono-monorepo:architecture-reviewer`)
- `consistency-checker.md` (name: `mono-monorepo:consistency-checker`)
- `cross-ref-checker.md` (name: `mono-monorepo:cross-ref-checker`)
