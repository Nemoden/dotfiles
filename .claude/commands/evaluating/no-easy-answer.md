---
description: Forbid the easy lookup — reason from code/docs alone
---

Answer the question below WITHOUT using the easy escape hatch. You may not:

- Read CloudWatch / deploy logs / runtime telemetry
- Read PR review comments or revert commits
- Run the failing test to see the output
- Grep for the error message in past sessions or memory

You MAY:
- Read source code
- Read project docs (CLAUDE.md, ADRs, wiki)
- Reason about types, control flow, data flow, env vars
- Read git diff of the change under examination

The point: force static reasoning that would catch the issue BEFORE deploy / BEFORE running it. If after this you still can't answer, say "I DO NOT KNOW" and name the smallest piece of forbidden evidence that would unblock you.

Question: $ARGUMENTS
