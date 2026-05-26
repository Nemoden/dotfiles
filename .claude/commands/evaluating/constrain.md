---
description: Solve under hard constraints — minimal, no deps, no new files, etc
---

Solve the task below under these hard constraints (apply all that are relevant; ignore ones that don't fit the task):

- **No new dependencies.** Use stdlib + what's already in the project
- **No new files.** Edit existing ones only
- **Under 50 lines of net new code.** Counts additions minus deletions
- **No new abstractions.** No new classes, no new helper modules, no new generic utilities. Inline > extract until the third repetition
- **No config / env vars / feature flags added**
- **Backwards compatible at the API boundary**

If a constraint cannot be honoured, say which one and why BEFORE writing code. Don't silently violate.

After the solution, list what you'd ALSO have done without the constraints — so I can see what was sacrificed for minimalism.

Task: $ARGUMENTS
