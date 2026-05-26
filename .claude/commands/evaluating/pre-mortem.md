---
description: Pre-mortem on a change — assume it shipped and broke prod, find why
---

We deployed the change described below (or referenced in the current context) and it fucked prod. We had to revert.

Tell me WHY with 100% certainty. If you cannot reach 100%, type literally:

    I DO NOT KNOW

…then give your top 3 leads ranked by confidence (% each, must be honest, no inflation). Your best lead must clear 70% or you keep saying IDK.

Constraints:
- Reason from code + PR context alone.
- Do not read deploy logs, CloudWatch, revert commits, or PR review comments unless I tell you to.
- Static reasoning only. The point is to find what a careful reader could have caught BEFORE deploy.

For each lead include:
- Concrete failure path (which call, which input, which line)
- Why it fires in the current `AUTHZ_MODE` / feature-flag / env state
- What single piece of evidence would push it to 95%

Change to analyse: $ARGUMENTS
