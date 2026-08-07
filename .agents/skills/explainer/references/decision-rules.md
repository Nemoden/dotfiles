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

## Model systems as a node-link diagram over swimlanes

When a flow spans several systems across trust domains, draw it as a
**node-link diagram**, not a grid of cards. `system-topology` implements this;
four rules make it legible instead of a wall:

1. **Swimlane by trust domain.** One horizontal band per domain (outside world,
   our backend, a vendor). Dataflow runs left-to-right ACROSS the bands. The
   band a node sits in IS its trust zone — that placement is load-bearing, not
   decoration.
2. **Arrows carry the data; payload is click-to-reveal.** The label on an arrow
   is what rides it (a short tag: "session token", "L2L"). The full field list
   lives in a click-open inspector — a few `main` fields, the rest behind
   "+N more on the wire". NEVER dump the payload onto the canvas; a diagram you
   have to read like prose has failed. The reader should SEE the shape and
   click for detail, the way an infographic shifts focus to what matters.
3. **Care is visual weight, not a word.** What you don't own is drawn faded +
   dashed (black-box a browser, a vendor, a pool — you care THAT data crosses
   it, not how it works inside). Low-care subsystems (rate-limiting, retry) hide
   in the inspector behind "+N more". Do not write the word "care" on the view;
   imply it. Scope is contextual — not too broad, not too narrow; when genuinely
   unclear which subsystems matter, ask.
4. **Follow one value end-to-end.** Each value that crosses ≥1 hop gets a chip;
   clicking it lights every system + arrow that value touches and fades the
   rest. A value that never crosses an auth check lights the WHOLE chain
   unbroken — that is the finding made visible, not asserted in prose.

What is on the wire is a security property. A password enqueued to SQS so an
email can echo it widens the blast radius of any queue/log leak to every reset;
a `{user_id, datetime}` event does not. Name what each edge carries (`carries`)
and flag the ones that widen blast radius (`wire_flag` + `wire_note`, drawn
red). You cannot see that from a call graph.

**Layout is a hybrid, and this is deliberate.** No free auto-layout engine does
swimlanes — they rank along one axis and never reserve perpendicular bands
(only paid tools like GoJS/yFiles do). So the renderer computes the bands +
dataflow ranks itself, and hands the one genuinely hard job — routing edges +
placing labels without collisions — to **ELK** (`elk.bundled.js`, vendored so
pages open offline from `file://`; a hand-rolled router is the fallback if ELK
is absent). If you build a new technique that needs graph layout, reuse this
hybrid rather than reaching for a full layout dependency or hand-rolling
collision math from scratch.

`io-boundary` is the flat one-box surface (every crossing of ONE box at once);
`system-topology` is the multi-system node-link view. Reach for topology when
the flow spans 3+ systems across 2+ trust domains and the composition — who
talks to whom, what rides each hop, what leaves us — is the question.

## Rank by boundary crossing — values are not peers

A system is a **box with a surface**, and subsystems nest. Before an explainer
can say anything true about safety or correctness, it must establish which side
of the surface each value came from and which way it crosses:

|  | stays inside | goes outside |
|---|---|---|
| **born outside** | **INPUT** — untrusted | **THROUGH** — relay |
| **born inside** | LOCAL — private | **OUTPUT** — our commitment |

Why this is a routing rule and not a footnote: a flat value list renders
`matter_id` (caller-supplied, selects the tenant) and `created_at` (a server
stamp) as equals. The reader gets no cue which one decides anything. Sort by
crossing and the trust story orders itself — inputs first, locals last.

Apply it whenever the subject has a trust or ownership edge (any HTTP handler,
any vendor integration, any multi-tenant path):

- **Reading one value's journey** → `value-provenance` + a `BOUNDARY` block.
- **Sizing the box / seeing every crossing at once** → `io-boundary`.
- **Both asked together** → `io-boundary` as the side-car: it is the frame,
  provenance is the zoom.

Three traps, each of which has already produced a wrong explainer:

1. **`born` is where a value is READ, not where it originates.** A querystring
   parsed at `load_input_data` looks locally-born and classifies as LOCAL when
   it is untrusted INPUT. Classify from where the data came from, not from where
   the code first touched it.
2. **The response crosses out.** A value assembled inside and returned to the
   caller is OUTPUT even when the "response" station sits inside the box.
3. **Direction of call says nothing about ownership.** A vendor API is outside
   even when WE call IT. Prove ownership from a base URL, a credential we
   present, or a vendored SDK — never from the arrow direction. Mark another
   company's system as `third_party`, distinct from merely `outside`: conflating
   the two is how a vendor gets explained as one of our subsystems.

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
