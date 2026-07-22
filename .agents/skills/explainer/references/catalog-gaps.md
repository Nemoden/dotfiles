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

_None yet._
