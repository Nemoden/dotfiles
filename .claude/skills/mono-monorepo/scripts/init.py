#!/usr/bin/env python3
"""
Mono-monorepo scaffold — creates the full project shell.

Usage:
    init.py <project-name> --description "<desc>" --path <dir> [--nix] [--git-init]

Examples:
    init.py my-saas --description "SaaS billing platform" --path ~/Projects
    init.py my-saas --description "SaaS billing platform" --path ~/Projects --nix --git-init
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def slugify(text: str) -> str:
    """Turn a title into a kebab-case slug."""
    return text.lower().replace(" ", "-").replace("_", "-")


def title_from_slug(slug: str) -> str:
    """Turn a kebab-case slug into a Title Case string."""
    return " ".join(w.capitalize() for w in slug.split("-"))


# ---------------------------------------------------------------------------
# File content templates
# ---------------------------------------------------------------------------

def claude_md(project_name: str, description: str) -> str:
    return f"""\
# {title_from_slug(project_name)}

{description}

## Working with AI Assistants

### Permission to Ask vs. Guess

**Rule:** If you are SURE something needs to be done (clearly wrong, ambiguous, or conflicts with established decisions), do it. If you're UNSURE, **ASK first**.

### Content Preservation

Do NOT delete useful content unless it is ambiguous, conflicting, confusing, or demonstrably wrong. Ask before removing anything you're uncertain about.

### Reading Order

When starting a task: **Ticket -> SPEC -> ADR -> Research -> Samples**

### Order of Truth

If documents conflict: **Ticket > SPEC > ADR > Samples**

Follow the higher-precedence document and flag the conflict.

### Project Structure

This is a mono-monorepo:

- `/code/` — all implementation (apps, shared libs, migrations, tooling)
- `/project/` — all knowledge (ADRs, SPECs, tickets, samples, ideas)

**Never modify files under `/project/`** unless explicitly asked or fixing clear errors.

### Code Conventions

(Fill in as decisions are made — language, framework, ORM, etc.)

### Testing

(Fill in as testing strategy is established.)
"""


AGENTS_MD = "Read CLAUDE.md for instructions\n"


def readme_md(project_name: str, description: str) -> str:
    return f"""\
# {title_from_slug(project_name)}

{description}

## Structure

```
{project_name}/
├── code/           # All implementation code
│   ├── apps/       # Application packages
│   └── migrations/ # Database migrations
└── project/        # Project knowledge
    ├── adr/        # Architecture Decision Records
    ├── specs/      # Feature specifications
    ├── tickets/    # Implementation tickets (todo/in-progress/blocked/done)
    ├── samples/    # Reference examples
    ├── ideas/      # Future considerations
    └── research/   # Domain research and analysis
```

## Setup

(Fill in setup instructions as the project evolves.)
"""


PROJECT_README = """\
# Project Documentation

This directory is the single source of truth for all project knowledge.

## Documentation Types

### ADRs (Architecture Decision Records)

**Location:** `adr/`

Document **WHY** architectural decisions were made. One decision per file. Never modify old ADRs — supersede them with new ones.

**Format:** `NNNN-descriptive-title.md`

```markdown
# ADR NNNN: Title

## Status
Proposed | Decided | Superseded | Deprecated

## Context
What problem are we solving?

## Decision
What did we decide?

## Consequences
Positive and negative trade-offs.

## Alternatives Considered
What else was considered and why it was rejected.
```

### SPECs (Specifications)

**Location:** `specs/`

Define **WHAT** and **HOW** to implement. Living documents — update as design evolves.

**Format:** `NNNN-descriptive-title.md`

```markdown
# SPEC-NNNN: Title

**Version:** 1.0
**Status:** Draft | Active | Superseded
**Related ADRs:** ADR-XXXX

## Overview
What this spec defines.

## Design
Detailed implementation blueprint.
```

### Tickets

**Location:** `tickets/`

Track implementation work. Status = directory location.

```
tickets/
├── todo/          # Backlog
├── in-progress/   # Active work
├── blocked/       # Waiting on dependency
└── done/          # Completed
```

State transitions via `git mv`. See `tickets/README.md` for details.

### Samples

**Location:** `samples/`

Concrete examples referenced by tickets, SPECs, or ADRs. Any format (JSON, HTML, SQL, etc.).

### Ideas

**Location:** `ideas/`

Design thoughts and potential features for future consideration. Not commitments.

### Research

**Location:** `research/`

Sourced reports and domain analysis that inform decisions. One directory per topic; main file named after the topic (kebab-case `.md`).

Not decisions — no precedence in the order of truth. Never modify during ticket work unless explicitly asked. Never deleted if any ADR or SPEC references it.

## Cross-Referencing

Documents are expected to reference each other — this is encouraged, not optional. A well-connected project knowledge base is easier to navigate and harder to contradict.

**Standard reference syntax:**

| From | To | Syntax |
|---|---|---|
| Ticket | SPEC | `See SPEC-0003` |
| Ticket | ADR | `See ADR-0007` |
| SPEC | ADR | `**Related ADRs:** ADR-0007, ADR-0009` |
| SPEC | SPEC | `**Related SPECs:** SPEC-0002` |
| SPEC | Sample | `See [samples/product-response.json](../samples/product-response.json)` |
| ADR | ADR | `Supersedes ADR-0004` |
| ADR | SPEC | `See SPEC-0006 for implementation details` |

**Example reference chain:**

```
tickets/todo/add-search-api.md
  └─ See SPEC-0005 for design
       └─ Related ADRs: ADR-0003 (why PostgreSQL full-text over Elasticsearch)
            └─ See samples/search-response.json for expected output shape
```

Following the chain from ticket to sample gives full context: what to build, how it's designed, why decisions were made, and what the output looks like.

**Rule of thumb:** if you wrote a SPEC or ADR that informed a ticket, link it. If a sample illustrates something in a SPEC, link it. Orphaned documents get stale.

## Reading Order

1. **Ticket** — What am I supposed to do?
2. **SPEC** — What is the design?
3. **ADR** — Why was it designed this way?
4. **Research** — What do we know about this domain?
5. **Samples** — What do examples look like?

## Order of Truth

If documents conflict: **Ticket > SPEC > ADR > Samples**
"""


TICKETS_README = """\
# Ticket System

Status = directory location. Transitions via `git mv`.

## Directory Structure

```
tickets/
├── todo/          # Backlog
├── in-progress/   # Active work (1-2 at a time)
├── blocked/       # Waiting on dependency
└── done/          # Completed
```

## Ticket Format

```markdown
# Descriptive Title

Brief description. Reference specs (SPEC-XXXX) or ADRs (ADR-XXXX).

## What to Build

- Deliverable 1
- Deliverable 2

## Done When

- [ ] Acceptance criterion 1
- [ ] Tests pass

## Notes

(Optional implementation hints)
```

## Naming

Descriptive kebab-case filenames, no numeric prefixes:
- `setup-dev-environment.md`
- `fix-connection-pool-leak.md`

## State Transitions

```bash
# Start work
git mv project/tickets/todo/name.md project/tickets/in-progress/
git commit -m "start: name"

# Complete
git mv project/tickets/in-progress/name.md project/tickets/done/
git commit -m "done: name"

# Block
git mv project/tickets/in-progress/name.md project/tickets/blocked/
git commit -m "blocked: name"

# Unblock
git mv project/tickets/blocked/name.md project/tickets/todo/
git commit -m "unblocked: name"
```
"""


def justfile_content(project_name: str) -> str:
    return f"""\
# {title_from_slug(project_name)} task runner

# Show all available commands
default:
    @just --list

# === Ticket Management ===

# List all tickets by status
tickets:
    @echo "=== TODO ==="
    @find project/tickets/todo -name "*.md" ! -name "README.md" -exec basename {{}} \\; 2>/dev/null | sed 's/\\.md$//' || echo "(none)"
    @echo ""
    @echo "=== IN PROGRESS ==="
    @find project/tickets/in-progress -name "*.md" -exec basename {{}} \\; 2>/dev/null | sed 's/\\.md$//' || echo "(none)"
    @echo ""
    @echo "=== BLOCKED ==="
    @find project/tickets/blocked -name "*.md" -exec basename {{}} \\; 2>/dev/null | sed 's/\\.md$//' || echo "(none)"
    @echo ""
    @echo "=== DONE (last 5) ==="
    @find project/tickets/done -name "*.md" -exec ls -t {{}} \\; 2>/dev/null | head -5 | xargs -I {{}} basename {{}} .md || echo "(none)"

# Show ticket details
ticket NAME:
    @find project/tickets -name "{{{{NAME}}}}.md" -exec cat {{}} \\; 2>/dev/null || echo "Ticket not found: {{{{NAME}}}}"

# Start working on a ticket (move to in-progress)
ticket-start NAME:
    @if [ -f "project/tickets/todo/{{{{NAME}}}}.md" ]; then \\
        git mv "project/tickets/todo/{{{{NAME}}}}.md" "project/tickets/in-progress/" && \\
        echo "Started: {{{{NAME}}}}" && \\
        echo "Don't forget to commit: git commit -m 'start: {{{{NAME}}}}'"; \\
    else \\
        echo "Ticket not found in todo/: {{{{NAME}}}}"; \\
        exit 1; \\
    fi

# Mark ticket as done
ticket-done NAME:
    @if [ -f "project/tickets/in-progress/{{{{NAME}}}}.md" ]; then \\
        git mv "project/tickets/in-progress/{{{{NAME}}}}.md" "project/tickets/done/" && \\
        echo "Completed: {{{{NAME}}}}" && \\
        echo "Don't forget to commit: git commit -m 'done: {{{{NAME}}}}'"; \\
    else \\
        echo "Ticket not found in in-progress/: {{{{NAME}}}}"; \\
        exit 1; \\
    fi

# Block a ticket
ticket-block NAME REASON:
    @if [ -f "project/tickets/in-progress/{{{{NAME}}}}.md" ]; then \\
        git mv "project/tickets/in-progress/{{{{NAME}}}}.md" "project/tickets/blocked/" && \\
        echo "Blocked: {{{{NAME}}}}" && \\
        echo "Reason: {{{{REASON}}}}"; \\
    else \\
        echo "Ticket not found in in-progress/: {{{{NAME}}}}"; \\
        exit 1; \\
    fi

# Unblock a ticket (move back to todo)
ticket-unblock NAME:
    @if [ -f "project/tickets/blocked/{{{{NAME}}}}.md" ]; then \\
        git mv "project/tickets/blocked/{{{{NAME}}}}.md" "project/tickets/todo/" && \\
        echo "Unblocked: {{{{NAME}}}}"; \\
    else \\
        echo "Ticket not found in blocked/: {{{{NAME}}}}"; \\
        exit 1; \\
    fi

# Show ticket history
ticket-history NAME:
    @git log --follow --oneline -- "project/tickets/**/{{{{NAME}}}}.md" || echo "No history found for: {{{{NAME}}}}"

# Create a new ticket
ticket-new NAME:
    @if [ -f "project/tickets/todo/{{{{NAME}}}}.md" ]; then \\
        echo "Ticket already exists: {{{{NAME}}}}"; \\
        exit 1; \\
    fi
    @printf '# {{{{NAME}}}}\\n\\nBrief description.\\n\\n## What to Build\\n\\n-\\n\\n## Done When\\n\\n- [ ]\\n- [ ] Tests pass\\n\\n## Notes\\n\\n' > "project/tickets/todo/{{{{NAME}}}}.md"
    @echo "Created: project/tickets/todo/{{{{NAME}}}}.md"
"""


GITIGNORE = """\
# OS
.DS_Store
Thumbs.db

# Editors
.idea/
.vscode/
*.swp
*.swo
*~

# Nix
result
.direnv/

# Python
__pycache__/
*.pyc
*.pyo
.pytest_cache/
*.egg-info/
dist/
build/
.venv/

# Node
node_modules/

# Environment
.env
"""


def flake_nix(project_name: str) -> str:
    return f"""\
{{
  description = "{title_from_slug(project_name)}";

  inputs = {{
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  }};

  outputs = {{ self, nixpkgs, flake-utils }}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${{system}};
      in
      {{
        devShells.default = pkgs.mkShell {{
          buildInputs = with pkgs; [
            just
          ];

          shellHook = ''
            echo "{title_from_slug(project_name)} dev shell"
          '';
        }};
      }});
}}
"""


ENVRC = "use flake\n"


# ---------------------------------------------------------------------------
# Scaffold logic
# ---------------------------------------------------------------------------

def create_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def gitkeep(path: Path) -> None:
    create_dir(path)
    (path / ".gitkeep").touch()


def scaffold(
    project_name: str,
    description: str,
    target_path: Path,
    nix: bool,
    git_init: bool,
) -> Path:
    root = target_path / project_name

    if root.exists():
        print(f"Error: {root} already exists")
        return None

    # Root files
    create_dir(root)
    write_file(root / "CLAUDE.md", claude_md(project_name, description))
    write_file(root / "AGENTS.md", AGENTS_MD)
    write_file(root / "README.md", readme_md(project_name, description))
    write_file(root / ".gitignore", GITIGNORE)
    write_file(root / "justfile", justfile_content(project_name))

    if nix:
        write_file(root / "flake.nix", flake_nix(project_name))
        write_file(root / ".envrc", ENVRC)

    # code/
    gitkeep(root / "code" / "apps")
    gitkeep(root / "code" / "migrations")

    # project/
    write_file(root / "project" / "README.md", PROJECT_README)
    gitkeep(root / "project" / "adr")
    gitkeep(root / "project" / "specs")
    gitkeep(root / "project" / "samples")
    gitkeep(root / "project" / "ideas")
    gitkeep(root / "project" / "research")

    # project/tickets/
    tickets = root / "project" / "tickets"
    write_file(tickets / "README.md", TICKETS_README)
    gitkeep(tickets / "todo")
    gitkeep(tickets / "in-progress")
    gitkeep(tickets / "blocked")
    gitkeep(tickets / "done")

    # Git init
    if git_init:
        subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
        subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "Initial scaffold"],
            cwd=root,
            check=True,
            capture_output=True,
        )
        print(f"Git repository initialized with initial commit")

    return root


def main():
    parser = argparse.ArgumentParser(description="Scaffold a mono-monorepo project")
    parser.add_argument("project_name", help="Project name (kebab-case)")
    parser.add_argument("--description", required=True, help="One-line project description")
    parser.add_argument("--path", required=True, help="Parent directory to create project in")
    parser.add_argument("--nix", action="store_true", help="Include flake.nix and .envrc")
    parser.add_argument("--git-init", action="store_true", help="Initialize git repo with initial commit")

    args = parser.parse_args()
    target = Path(args.path).expanduser().resolve()

    if not target.exists():
        print(f"Error: target directory does not exist: {target}")
        sys.exit(1)

    result = scaffold(args.project_name, args.description, target, args.nix, args.git_init)

    if result:
        print(f"Scaffolded mono-monorepo at {result}")
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
