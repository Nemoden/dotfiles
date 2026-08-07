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

## guard-shortcircuit — surfaced 2026-07-28

- **Subject/question that had no home:** authz audit of ~60 API endpoints. The
  recurring question on a whole class of them was **"a protective check IS
  called — why doesn't it protect anything?"** Canonical case:
  `alex/balance-sheet` calls `assert_firm_access` downstream, but it early-
  returns because `_has_gateway_context(event)` is False for the synthetic L2L
  payload the caller builds (`shared/authz.py:241-242`). Nothing is missing; a
  guard runs and silently no-ops. Same shape recurred on every endpoint where a
  guard exists but is defeated by `AUTHZ_MODE=audit` (logs, never denies).
- **What was stretched:** shipped `value-provenance` (`.when`: "answer 'where
  does this value come from / go?' WITH the code at each point"). Its declared
  `.weak` is **"control flow; timing"** — and control flow is precisely the
  finding: which branch the guard takes and why. To fit, the page had to encode
  a branch *outcome* as a pseudo-value (`gateway_context: bool`) and trace its
  "provenance". Coherent, but it models a predicate as data because the catalog
  had no primitive for "the guard ran and chose the harmless branch".
  `state-machine` is closer but overweight (a 2-state machine per guard);
  `annotated-source` shows the early-return line but loses the caller-side cause
  sitting in a different file.
- **Why a technique, not a one-off:** this is the default shape of modern authz
  defects. Missing-check bugs are easy to see (no call site). Present-but-inert
  checks are the ones that survive review, because the grep for
  `assert_firm_access` succeeds. 22+ endpoints in one audit shared it.
- **Candidate stub:**
  { id: "guard-shortcircuit", family: "flow",
    when: "a protective check executes but does not protect: show the guard, every early-return/no-op branch, the caller-side condition that selects the harmless branch, and what would have to change for it to bite",
    weak: "missing checks (nothing to show); value provenance; big-picture structure" }

### guard-shortcircuit — implementation status (updated 2026-07-29)

**Built and validated as a renderer, NOT yet promoted to `catalog.json`.**
Promotion is the skill owner's call; this records that a working reference
implementation exists so a reviewer does not start from the stub.

- **Renderer:** `renderGuardShortcircuit(elId)` reading a `GUARD_PATHS` const.
  Lives in the authz audit's `_renderers.js`, not in the skill's locked
  `_shared.js`. Injects its own CSS once at runtime (`GSC_CSS`) — the locked
  design system was not touched, and it uses only existing CSS vars, so a theme
  swap still works.
- **Data contract:** `{subtitle, verdict_label, verdict, mode:{current,source},
  paths:[{when, ref, why, outcome}], kicker}` where `outcome` ∈
  `denies | conditional | bydesign | allows`.
- **The load-bearing design decision:** the four outcome values, not three.
  A first pass had every non-raising exit as `allows` (red). That painted the
  correct-by-design exits — L2L, firm match, superuser escape hatch — as
  defects, so the one real gap stopped standing out. `bydesign` (grey) vs
  `allows` (red) is what makes the view readable. Any promotion should keep the
  distinction.
- **What it renders:** the AUTHZ_MODE ladder (`audit → soft → enforce`) with the
  live value marked and its `serverless.yml` source; one row per exit path with
  `file:line`; a tally (`5 exit paths · 1 gap · 3 by design · 1 deny only
  outside audit · 0 always deny`); a kicker naming why provenance cannot show
  this.
- **Deployed on:** 27 of 53 endpoint pages in the APG-361 authz audit — every
  endpoint whose fix adds `assert_firm_access` into a service pinned to
  `AUTHZ_MODE=audit`. Index links each with a `logs only · does not deny` chip.
- **Verified:** 53/53 pages render with 0 JS errors and 0 overflow; the 26
  non-applicable pages correctly render nothing.
- **Reference artifact:** `~/tmp/auth-remaining-endpoints/explainer/` — see
  `matters-post-matters-reindex-id.html#guardpaths`.
- **If promoted:** needs an `assets/catalog/` template + a `tiers` entry. An
  ascii tier is viable (the path table degrades to text cleanly); mermaid is a
  poor fit, since the value is the per-path verdict column, not the topology.

## 2026-07-31 — subject: APG-1025 "add sourcing to Review Work" (proposed design)
Question was "what does adopting this design MEAN — what breaks, what to decide, in what order?"
No technique's `.when` covers a decision-ready proposal brief; the index/launcher page was
stretched to carry decisions/sequencing prose alongside two technique pages.
Candidate:
  { id: "decision-brief", family: "reading",
    when: "a proposed design needs a decision-ready brief: the change in one sentence, what breaks, decisions to settle, sequencing — techniques attach as evidence pages",
    weak: "explaining existing behavior; code detail; anything not a proposal" }

## 2026-08-04 — PR #876 deploy-freeze monoculture (svc-python)

Question was "why does one pinned SHA + dispatch-only deploys = latent
simultaneous breakage?" — a HYPOTHETICAL incident walked forward in time,
not an actual code run. runtime-step fit after stretching its "what happens
on a run" into "what happens as the scenario unfolds"; fact-vs-hypothesis
separation and the counterfactual world toggle had to be improvised on the
LIVE/PREVIEW affordance. Candidate:

  { id: "scenario-timeline", family: "flow",
    when: "walk a hypothetical failure/incident scenario forward in time (pre-mortem, risk explainer), separating fact from hypothesis, optionally toggling a counterfactual world",
    weak: "actual code execution order (use runtime-step); static structure; value provenance" }

## findings-ledger — surfaced 2026-08-04

- **Subject/question that had no home:** critique of Datadog dashboard
  `zdw-s28-xym` (AI Paralegal doc-analysis reliability). Reader's question was
  **"what's wrong here, and which ones matter?"** — 9 independent findings, each
  with its own evidence trail, ranked by the decisions they corrupt rather than
  by abstract severity. Four claims raised during review were withdrawn on
  evidence and had to stay visible.
- **What was stretched:** shipped `altitude-zoom` (`.when`: "let the reader
  choose depth; docs serving both skimmers and diggers"). Its index→detail shape
  fits, but depth is not the axis — **consequence** is. The technique has no
  notion of ranking, no per-item verdict/status, and nothing for withdrawn
  claims. The impact vocabulary (`IMPACT`/`STATUS` badge maps, impact-ordered
  index, "the decision this corrupts" pane) had to be built on top. `call-tree`
  and `minimap-detail` are both about ONE artifact's internal structure; here
  there are 9 unrelated defects sharing only a subject.
- **Why a technique, not a one-off:** this is the shape of every audit output —
  code review, security review, dashboard critique, dependency audit. The
  recurring hard parts are (a) ranking by decision-impact rather than severity,
  and (b) keeping retracted findings auditable instead of silently deleted. A
  findings list that hides its own false positives can't be trusted, and no
  current technique has anywhere to put them.
- **Candidate stub:**
  { id: "findings-ledger", family: "reading",
    when: "a set of independent findings ranked by the decisions they corrupt; each with evidence, blast radius, and fix; retains withdrawn claims for auditability",
    weak: "a single system's structure or flow; anything with one narrative thread; explaining how something works rather than what is wrong with it" }
- **Reference artifact:** `~/tmp/doc_analysis_dash/` — impact-ranked index +
  9 detail pages, annotated-source embedded per finding, withdrawn-claims
  section on the index.

## annotated-diff-with-groups (2026-08-05, PR #850 review adjudication)

Need: diff hunks where a CONTIGUOUS LINE RANGE is one logical change with ONE
shared note (e.g. a multi-line `return _EnsureResult(...)` swap). Stock
`renderAnnotatedSource` notes are per-line; `renderDiff` carries only a
per-hunk `why`. Neither can say "these 4 lines are whole".

Shape used (page-level `renderAnnotatedDiff`, reuses esc/richText/topbar):
  lines: [[tag, text]...]  tag ∈ add|del|ctx
  groups: [{from, to, sev, note}]  — inclusive 0-based indexes; left bracket
  spans the range, first line gets the ● marker, hover lights the whole range,
  click toggles one shared note under the range. sev ∈ danger|warn|info|dim.
Worked example: ~/tmp/disclosure-explainer/review/ (review.helpers.js + CSS in
index.html). Candidate for promotion into _shared.js + a catalog technique.
