---
name: explainer
description: >-
  Explanation engine that turns a subject into the lightest visual explanation
  that answers the question, escalating fidelity on demand across three tiers:
  (1) ASCII/text diagram inline in chat, (2) Mermaid-in-Markdown
  (flowchart/sequence/stateDiagram/data-flow) that pastes into PRs, wikis, and
  tickets, (3) standalone interactive HTML explorers built on a locked shared
  design system with a catalog of techniques (lifecycle spine, value
  provenance, runtime step-through, collaborator swimlanes, state machine,
  annotated source, minimap, fisheye, altitude zoom, dual-lens, call-tree).
  Use when the user wants to understand, explain, visualize, diagram, or walk
  through: a code change/diff/PR ("explain this PR", "diagram this change",
  "what does this do"), an existing system or data flow ("how does X work",
  "draw the architecture", "trace where this value comes from"), a proposed
  design ("visualize this design", "diagram this plan"), or their own mental
  model ("help me understand", "let me see this", "explain it from different
  angles"). Also invoked BY other skills (PR creation, code review,
  hunk-review) to attach an explainer to a diff or PR description. Triggers on:
  "explain", "diagram", "visualize", "walk me through", "how does this work",
  "where does this come from", "make it interactive / html", "as mermaid",
  "ascii diagram".
---

# Explainer

Produce the **lightest explanation that answers the question**, then offer to
escalate. Three fidelity tiers; a technique catalog; a quality gate.

## Workflow

1. **Identify the subject + question.** Subject in {code change/diff, existing
   system, proposed design, personal understanding}. Question = what the reader
   actually needs (where does X flow? what runs? how do modes differ? etc.).
   If genuinely ambiguous, ask ONE clarifying question; otherwise proceed.

2. **Ground it in reality.** Read the actual code/diff/design. Never explain
   from assumption. Copy names verbatim. Non-negotiable: a confident wrong
   explainer is the worst output.

3. **Route** — read `references/decision-rules.md`:
   - Pick the **fidelity tier** (ascii -> mermaid -> html). Default to the
     lightest that fits; auto-pick unless the user or a caller skill specified
     one. **Never auto-build HTML** (expensive) — build ascii/mermaid, then offer it.
   - Pick the **technique(s)** by matching the question to
     `references/catalog.json` (`techniques[].when`/`.weak`).
   - Apply the **composition rule**: default one primitive; add at most one
     side-car when a second question is always asked alongside; three is the
     ceiling; the 5-way workbench is an anti-pattern.

4. **Build** at the chosen tier:
   - **ascii / mermaid** -> `references/mermaid.md` (templates + house style:
     colour-by-role, legend, altitude).
   - **html** -> `references/html-tier.md` (copy locked `_shared.css`/`.js` from
     `assets/catalog/`, swap the data blocks per `assets/catalog/_data.template.js`,
     copy the technique file, keep renderers untouched).

5. **Gate** — run the relevant items in `references/quality-gate.md` BEFORE
   delivering. Indentation preserved, claims trace to code, HTML opens offline,
   Mermaid parses.

5.5. **Reflect on the fit** (all tiers) — run the fit-check in
   `references/quality-gate.md`: was there a better *existing* technique
   (suboptimal-pick), or did NO technique's `.when` fit (catalog-gap)? Silent
   when clean; else append a **Fit note**. Log gaps to `references/catalog-gaps.md`.

6. **Offer escalation** when the tier was auto-picked, e.g. "Want this as
   Mermaid for a PR, or an interactive HTML explorer?"

## Fidelity tiers (summary)

| Tier | What | When |
|---|---|---|
| **ascii** | text diagram inline, no file | small subject, quick ask, review comment |
| **mermaid** | fenced block in Markdown | anything shipped into a PR/wiki/ticket |
| **html** | interactive explorer, locked design system | large/complex, or "view from angles" |

Full routing in `references/decision-rules.md`.

## Invoked by other skills

Callers (PR creation, code review, hunk-review) pass **subject** (what to
explain), optional **tier** (`ascii`|`mermaid`|`html` — obey it, skip auto-pick)
and optional **question/angle** (what to emphasize). No tier passed → `mermaid`
for doc/PR, `ascii` for inline review comments; note HTML available on request.

## Resources

- `references/decision-rules.md` — routing: tier + technique + composition.
- `references/catalog.json` — machine-readable technique index (when/weak/tiers/needs).
- `references/mermaid.md` — Mermaid + ASCII templates and house style.
- `references/html-tier.md` — building an HTML explainer (data-swap workflow).
- `references/quality-gate.md` — pre-delivery checklist + fit-check + anti-patterns.
- `references/catalog-gaps.md` — candidate techniques logged by the fit-check.
- `assets/catalog/` — locked `_shared.css`/`_shared.js`, `_data.template.js`,
  and one HTML template per technique (+ combined examples).
- `references/example-autoreply/` — golden reference: a full worked catalog on a
  fictional support auto-responder change. Open a file here when unsure how a
  technique renders.

## Non-negotiables

- Every claim traces to real code; names verbatim. A confident wrong explainer
  is the worst output.
- Indentation is load-bearing — never strip leading spaces in any code shown.
- Don't drop the reader mid-machine — give the entry->exit frame unless the ask
  is explicitly narrow.
- Never auto-build HTML (expensive); swap data, don't fork the design system.
