---
description: Explain code back to me line-by-line as if you don't trust the author
---

Walk through the code below (or in current context) explaining what each meaningful chunk does AND why it's written that way. Adopt a sceptical reader stance — you do NOT trust the author got it right.

For each chunk:
- **What** it does (literal mechanics)
- **Why** the author probably wrote it this way (intent)
- **Mismatch?** — does the what diverge from a plausible why? If yes, flag
- **Hidden assumption** — what does this chunk rely on that isn't visible here (env var set, table exists, claim present, caller already validated)

At the end, list:
- Assumptions that should be asserted/documented but aren't
- Lines where intent and mechanics drift
- Anything that "works by accident" — would break under a reasonable change elsewhere

Code/file: $ARGUMENTS
