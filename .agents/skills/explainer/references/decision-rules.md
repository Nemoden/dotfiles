# Decision rules — routing a request to technique + fidelity

The skill's brain. Read this to pick WHAT to build and at WHICH fidelity, so
choices are reproducible instead of guessed. Two independent decisions:
(1) fidelity tier, (2) technique(s).

## Table of contents
- Fidelity: which tier
- Technique: which one(s)
- Composition: when to combine, when to stop
- Quick routing table

## Fidelity: which tier (ascii / mermaid / html)

Default to the LIGHTEST tier that answers the question. Then always offer to
escalate. Override order (highest wins):

1. **User stated a tier** ("explain X as html/mermaid/ascii") → obey it.
2. **A caller skill passed a tier** (see SKILL.md "Invoked by other skills") → obey it.
3. **Otherwise auto-pick** by this heuristic, then offer the next tier up:

| Signal | Lean tier |
|---|---|
| Subject is a few functions / one small diff | ascii |
| Answer is a quick mental model, in-conversation | ascii |
| Output will be pasted into a PR / wiki / ticket | mermaid |
| Reader is not at this terminal (teammate, reviewer) | mermaid |
| Subject is a whole subsystem / large feature | mermaid → offer html |
| Must be explored from several angles interactively | html |
| User says "let me play with it" / "different angles" / "too big" | html |

Escalation offer is mandatory when auto-picked, e.g. end with:
"Want this as Mermaid for a PR, or an interactive HTML explorer?"

Do NOT auto-build html: it is expensive. Build ascii/mermaid, then offer html.

## Technique: which one(s)

Match the reader's QUESTION to a technique via `references/catalog.json`
(`techniques[].when` / `.weak`). The recurring mappings:

| Reader's question | Technique |
|---|---|
| "Where does this VALUE come from / go?" | value-provenance |
| "What happens when I RUN it?" (order) | runtime-step, or timeline-scrubber, or mermaid-sequence |
| "Who CALLS whom?" | collaborator-swimlanes / mermaid-sequence |
| "How is mode A different from mode B?" | dual-lens |
| "What STATES does it move through?" | state-machine / mermaid-state |
| "Where does this change SIT in the whole?" | lifecycle-spine |
| "Walk me through the actual CODE" | annotated-source |
| "I keep getting LOST in this big change" | minimap-detail / fisheye |
| "Let me choose my own DEPTH" | altitude-zoom |
| "Just give me a portable diagram" | mermaid-flowchart / data-flow-diagram |
| "'what calls what' as an outline" | call-tree |

Subject type also filters:
- **A code CHANGE** (diff/PR): spine, dual-lens, annotated-source, value-provenance, before/after shapes.
- **An existing SYSTEM** (no diff): spine, data-flow-diagram, mermaid-flowchart, swimlanes, state-machine.
- **A proposed DESIGN** (future): mermaid (portable, cheap to iterate), spine.
- **Personal understanding** (throwaway): ascii first; escalate only if it stays fuzzy.

## Composition: when to combine, when to stop

Combining primitives can beat a single view, but restraint matters. Rule:

- **Default: ONE primitive.** Most explanations want a single technique.
- **Add ONE side-car** only when a *second* question is ALWAYS asked alongside
  the first (e.g. step-through + state-machine: "what runs" and "what state").
  The side-car tracks the primary view; it never competes for the main glance.
- **Three is the practical ceiling** and only for the "never lose context"
  goal (minimap + focus + annotated). Justify each layer against a distinct question.
- **Five (the Workbench) is an anti-pattern.** Documented in
  `catalog.json.combined_examples.E` as a reference for where "integrated" tips
  into "cluttered". Do not ship it by default. The rails go stale relative to
  where the eye is; a 1–2 technique subset reads faster.

Annotated-source is a PRIMITIVE, not a standalone: prefer embedding it inside
whatever technique shows code, rather than as its own page.

## Quick routing table (subject × size × target → build)

| Subject | Size | Target | Build |
|---|---|---|---|
| change | small | chat | ascii before/after or spine |
| change | small | review comment | ascii swimlanes or before/after |
| change | big | PR description | mermaid flowchart/sequence |
| change | big | "view from angles" | html spine (+ annotated side-car) |
| system | any | doc/wiki | mermaid data-flow / flowchart |
| system | big | onboarding explorer | html spine or minimap+detail |
| design | any | RFC/plan | mermaid (iterate cheaply) |
| understand | small | self | ascii; escalate only if fuzzy |
