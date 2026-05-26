---
description: Imagine this PR caused an incident 6 months from now — write the post-mortem
---

It is 6 months from now. The change described below (or in current context) caused a production incident. Write the post-mortem.

Required sections:
1. **What broke** — single sentence, customer-visible symptom
2. **Causal chain** — numbered steps from PR-line → incident. Must reference specific files/functions/inputs, not vibes
3. **Why it wasn't caught** — review gap, test gap, monitoring gap (be specific)
4. **The fix that should have been in the original PR** — concrete diff-shaped suggestion
5. **Confidence this incident is plausible** — % + what would raise it to 95%

If you cannot construct a plausible causal chain, say so explicitly. Do not invent.

Change: $ARGUMENTS
