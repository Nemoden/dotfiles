# Catalog gaps — candidate techniques

The explainer's fit-check (`references/quality-gate.md` → "Fit-check") appends
here whenever a reader's question had NO technique whose `.when` cleanly covered
it and a choice had to be stretched. Each entry is a **candidate** for
`catalog.json`, not a committed technique.

**How this grows the catalog:** review entries periodically; promote a
recurring gap into `catalog.json.techniques` (and build its template under
`assets/catalog/` if it earns an HTML tier). Delete an entry once promoted or
once judged not worth a technique.

## Entry format

```
## <candidate id> — surfaced <YYYY-MM-DD>
- **Subject/question that had no home:** <the reader's actual question>
- **What was stretched:** <technique shipped + the .when/.weak phrase that made it a stretch>
- **Candidate stub:**
  { id: "<id>", family: "<structure|flow|value|compare|reading|static>",
    when: "<question this would answer>",
    weak: "<questions it would NOT>" }
```

## Candidates

## interleaving-lanes — surfaced 2026-07-27

- **Subject/question that had no home:** PR fixing a lost-update race on
  `matter.cards` (two concurrent writers, full-body PUTs, loser's append
  silently erased). Reader's question: "how do two CONCURRENT writers
  interleave on shared state, and where exactly is the update lost?"
- **What was stretched:** shipped runtime-step (`.when`: "understand execution
  order and what happens on a run") with a before/after mode toggle. It models
  ONE program counter; two writers had to be flattened into a single merged
  timeline, actor identity carried in prose labels ("Writer A…", "Writer B…")
  instead of structure. No lanes, no per-actor cursor, no way to REARRANGE the
  interleaving to see which orderings lose and which are safe — the defining
  affordance of a race explainer.
- **Candidate stub:**
  { id: "interleaving-lanes", family: "flow",
    when: "two+ concurrent actors racing on shared state; lost-update / dirty-read / deadlock intuition; step or reorder an interleaving and watch the shared resource",
    weak: "single-threaded flow; static structure; value provenance; A/B mode compare" }
