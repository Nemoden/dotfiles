# Quality gate — run before delivering any explainer

A pre-delivery checklist. Every explainer, at every tier, must pass the
relevant items. If one fails, fix it before showing the user — a wrong or
broken explainer is worse than none.

## Universal (all tiers)

- [ ] **Every claim traces to real code.** No invented behavior. If unsure
      whether something is true, read the source; do not assert it. State
      uncertainty explicitly rather than guessing.
- [ ] **Names are exact.** Function/file/field names match the codebase
      verbatim (copy them, don't retype from memory).
- [ ] **The lightest tier that answers the question was chosen** (see
      `decision-rules.md`), and — if auto-picked — an escalation was offered.
- [ ] **Scope honesty.** If the explainer covers only part of the subject,
      say what it omits. No silent truncation.

## Code rendering (any tier showing code)

- [ ] **Indentation preserved.** Leading spaces on every code line are intact.
      This is the #1 failure mode. In HTML this means `white-space:pre` rows
      and real spaces in the data (the shared `renderDiff`/`renderAnnotatedSource`
      handle it — do NOT hand-build diff HTML). In ASCII/Mermaid, keep the
      spaces in the fenced block. Verify by eye: Python `def`/`return`/nested
      lines keep their indent.
- [ ] **add/del/context are visually distinct** where a diff is shown.

## Mermaid tier

- [ ] **The block parses.** Valid `mermaid` fenced syntax; node ids are
      alphanumeric; labels with special chars are quoted. See `mermaid.md`.
- [ ] **Legend/colour by ROLE**, not decoration (same colour = same function),
      with a one-line legend beneath when colour is used.
- [ ] **Altitude matches the ask** (super-high-level vs mid vs detailed).

## HTML tier

- [ ] **Opens offline.** No server, no CDN, no external fonts/libs. Only the
      two shared files (`_shared.css`, `_shared.js`) as siblings/relative links.
- [ ] **Shared assets linked, not inlined-and-diverged.** The design system is
      `_shared.css`/`_shared.js`; only the data blocks change
      (`STATIONS`/`UNITS`/`VALUES`/`SOURCES`/`VALUE_CODE`). Do not fork the theme.
- [ ] **Back-link / navigation works** if part of a multi-file set.
- [ ] **Zoomable affordances are obvious** (magnifier badge / cursor), not
      blended into static nodes. (Learned the hard way — see anti-patterns.)
- [ ] **Data-swap only.** A new subject reused the technique template by
      swapping data, not by rewriting the renderer.

## Fit-check — self-reflection (all tiers, after gate, before offering)

The gate above asks "is this explainer correct?". This asks "was this the right
explainer to build?". Run it every time. Silent when the fit is clean; append a
**Fit note** to the delivery only when imperfect.

Do NOT rubber-stamp your own choice. Re-derive from the reader's question and
the catalog's own words, not from what you already built. Every judgment must
quote a `.when` / `.weak` phrase from `catalog.json` — no vibes.

Two SEPARATE questions. Answer both; a clean pick-check does not excuse
skipping the gap-check.

**1. Pick-check — was there a better EXISTING technique?**

- Set aside what you built. Re-read the reader's actual question.
- Scan every technique's `.when` — which matches the question most directly?
- Scan `.weak` — does the technique you shipped list, in its OWN `.weak`, the
  very thing the reader asked about?
- Flag **suboptimal-pick** if a different technique's `.when` fits better, OR
  your shipped technique's `.weak` names the reader's question. Name both
  techniques and quote the deciding phrase. Over-composition counts too
  (shipped 3 rails where 1 answered the question).

**2. Gap-check — did ANY technique fit?**

- Different question. Run it even if pick-check passed.
- What did the reader's question need that NO technique's `.when` cleanly
  covers? What did you stretch, force, or leave unanswered to make a choice fit?
- "No gap" is valid ONLY if nothing was forced. If you stretched → flag
  **catalog-gap** and emit a paste-ready stub:
  `{ id, family, when, weak }` (family ∈ structure/flow/value/compare/reading/static).
- Append the stub to `references/catalog-gaps.md` (one entry per gap, dated by
  the subject that surfaced it) so the catalog grows from real usage. Do not
  edit `catalog.json` automatically — the log is a candidate queue for review.

**Fit note format** (only shown when imperfect):

```
Fit note: reader asked about execution ORDER; shipped value-provenance,
whose .weak is "control flow; timing" → suboptimal. runtime-step (.when:
"execution order and what happens on a run") fit better.
```

```
Fit note (catalog-gap): question was "how does throughput degrade as N
grows?" — no technique's .when covers quantitative/scaling behavior.
Candidate + logged to catalog-gaps.md:
  { id: "scaling-curve", family: "flow",
    when: "how a metric changes as an input grows; perf/scaling intuition",
    weak: "discrete states; provenance; code detail" }
```

## Anti-patterns (do not ship these)

- **Flattened indentation** — HTML collapsing leading spaces. Fixed by
  `white-space:pre` + real spaces in data.
- **Blended affordances** — clickable nodes that look identical to static
  ones; the reader can't tell what's interactive.
- **The 5-way Workbench by default** — too many rails competing for one
  glance. Reserve as an anti-pattern reference only.
- **Dropping the reader mid-machine** — starting at an inner function with no
  path to how input arrives. Always give the entry→exit frame (spine) unless
  the ask is explicitly narrow.
- **Redundant technique** — e.g. timeline-scrubber when runtime-step already
  answers it. Pick one.

## Regression anchor

The golden reference is `references/example-autoreply/` (a fictional support
auto-responder catalog). A fresh HTML explainer should look and behave consistent with it:
same theme, indentation-correct diffs, obvious affordances. When in doubt about
how a technique should render, open the matching file there.
