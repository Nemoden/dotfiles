---
description: Before merge — name the ONE thing that would make you say no
---

Pre-merge gate. Before I merge the change below (or in current context), give me:

1. **The ONE thing** — if you had to pick a single reason to block this PR, what is it? Be concrete (file, line, scenario). "Looks fine to me" is not an answer — find something
2. **If forced to merge anyway** — what's the FIRST thing I should monitor in the first 24h post-deploy? (specific log pattern / metric / endpoint)
3. **The bet** — would you bet money this ships without an incident in 30 days? Yes/no + why

Rules:
- If the change is genuinely flawless, say so explicitly + explain why "the ONE thing" doesn't exist. Don't manufacture concerns
- But default to finding something. Code review fatalism ("LGTM") is the failure mode this command exists to break

Change: $ARGUMENTS
