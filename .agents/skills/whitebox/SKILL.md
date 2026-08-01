---
name: whitebox
description: Use when an idea or system is too big or fuzzy to clarify in one sitting and needs decomposing into a durable, resumable map of decisions. Triggers: "whitebox", "whiteboxing", "black box", "chart a map", "resume the map", an effort that will span many sessions, or a loose idea arriving with unknowns nobody has enumerated yet.
---

# Whitebox

Whiteboxing turns one opaque idea into a graph of small, decidable pieces. Systems view: every system is a composition of subsystems, each with inputs and outputs. A fresh idea is a system nobody has decomposed yet: a single black box. The process opens it box by box until every box is white and the route from idea to action is visible.

The output is decisions, not deliverables. The moment you feel the pull to start building, you have reached the edge of the map: box what remains, do not build.

## When to use

- The effort cannot fit in one session, or must survive interruption at any point.
- Unknowns outnumber knowns and nobody has enumerated them.
- Several sessions (or people) need to share one picture of what is decided so far.

When the whole journey fits comfortably in a single session, say so and skip the map.

## Vocabulary

- **Mission**: the product goal, why the effort exists. "Build a content creation system."
- **Destination**: what ends this map: a spec ready to hand off, a decision locked, a change made in place. The stop condition. Without it the process cannot tell planning from building.
- **Box**: one record holding one question whose resolution is a decision or a fact.
- **States**: **black** = boundary named, interior unexplored. **grey** = opened: partly decided, decomposed, or drafted and under review. **white** = own decision final AND every child white. A parent's colour is computed from its children, never set by hand.
- **Edges**: plain arrow = decomposition (parent contains child). `blocks` = hard dependency: target cannot be decided until source is white. `informs` (dotted) = source's answer shapes the target without gating it.
- **Frontier**: boxes that are not white and not blocked. What can be worked right now.
- **Open unknowns**: questions you can feel but cannot yet state precisely. They live inside the box they belong to, worst case the root box, never in a global list. Test: can the question be phrased sharply right now? Sharp = its own box, even if blocked. Vague = open unknown.
- **Out of scope**: ruled past the destination. Closed with a one-line reason, never worked on this map.

## The map

One map per effort. The map is a low-resolution index: it names boxes, shows states and edges, and gists finished decisions. Detail lives in exactly one place, the box record; the map links, never restates.

```markdown
# <effort name>

## Mission
<1-2 lines>

## Destination
<1-2 lines: the artifact or decision that ends this map>

## Notes
<domain vocabulary, standing preferences, store config, recorded assumptions>

## Map
<mermaid DAG, see below>

## Decisions so far
- [<box name>](<link>): <one-line gist of the decision>

## Heading
<1-2 lines: where the effort points next; sharpest open unknowns gisted from their boxes, links only>

## Out of scope
- [<box name>](<link>): <gist + why it is past the destination>
```

The mermaid block is the single source of truth for topology and state. Box records never restate their colour or their edges.

```mermaid
flowchart TD
    root["Content creation system"]:::grey
    fmt["Post format"]:::white
    editor["Editor choice"]:::black
    pipe["Publish pipeline"]:::black
    root --> fmt
    root --> editor
    root --> pipe
    editor -->|blocks| pipe
    fmt -.->|informs| pipe
    classDef black fill:#1a1a1a,color:#fff,stroke:#000
    classDef grey fill:#9e9e9e,color:#111,stroke:#555
    classDef white fill:#ffffff,color:#111,stroke:#111
    click editor "boxes/editor-choice.md"
```

Every node carries exactly one classDef (`black`/`grey`/`white`) and a `click` link to its record. Colour flips are edits to this block and nothing else.

## Box records

One record per box. Name it after the question's subject, kebab-case for files.

```markdown
# <box name>

Method: dialogue | research | prototype | task | adr

## Question
<the one decision or investigation this box holds>

## Decision
<empty until made; then the answer and the why>

## Open unknowns
<felt-but-not-sharp questions living inside this box>

## Links
<assets: research notes, prototypes, ADR/spec documents. Link, never paste>
```

Methods say what whitening means for this box:

| Method | Mode | White when |
|---|---|---|
| dialogue | with operator | question answered through Socratic questioning, one question at a time (default) |
| research | agent alone | fact surfaced from docs, APIs, or code; findings linked |
| prototype | with operator | throwaway artifact built, reacted to, decision taken |
| task | either | prerequisite work done (access provisioned, data moved); resulting facts recorded |
| adr | with operator | decision record accepted. Grey while drafted or under review |

## Hard rules

1. **Write-through-box.** Persist at the moment clarity lands or a new unknown appears, not at session end. Decision goes to the box record, gist to the map, colour flip to the diagram, new boxes wired in, invalidated boxes rewritten or ruled out. The map never lags the conversation.
2. **Operator-side boxes wait for the operator.** dialogue, prototype, and adr boxes resolve only through the live exchange. Never answer for them; if the operator is away, the box stays open with the pending question recorded.
3. **Never assume a non-functional requirement silently.** Scale, latency, availability, security, cost, compliance, operability: each dimension the effort touches becomes an answered question, its own box, or an assumption written in Notes where the operator will see it. Dimensions the effort does not touch are skipped, not padded.
4. **Decide, don't build.** Wanting to implement is the signal the map has reached its edge.
5. **Parent colour is computed.** A parent goes white only when its own decision is final and every child is white.
6. **The map points, never duplicates.** Full answers live in box records and linked assets.

## Charting: loose idea to first map

Charting touches the disk only at step 5. No map, no boxes, no provisional skeletons before the operator picks the store; until then, pending state lives in the conversation.

1. Pin **Mission** and **Destination** through questioning, one question at a time. Destination first defines scope; everything else hangs on it.
2. Fix the domain language as terms come up (see Fallbacks: domain modeling). Entities, relationships, and levels in the domain's own words, never in implementation terms.
3. If the effort designs or changes a system, sweep the non-functional dimensions (hard rule 3). A map for prose or curriculum may have none; skip freely.
4. Sweep the space **breadth-first** for boxes: fan wide, do not dive deep on any thread. If no unknowns surface, the way is already clear: say so and skip the map.
5. Ask the operator where the map should live (see Choosing the store). Create the map and its box records, then wire edges in a second pass, since boxes need identities before they can reference each other.
6. Dispatch research boxes to subagents in parallel; link findings as they return.

Charting ends with a persisted map. Continue into Working in the same session only if the operator wants to.

## Working: whiten box by box

1. The operator points at a map (path or URL). Load the map alone; open box records only as the work needs them. The map plus its boxes are the entire state; the previous conversation is not needed.
2. Pick a frontier box. The operator's pick wins; otherwise take the topmost unblocked box.
3. Whiten it through its method. Zoom into related records on demand.
4. Apply write-through-box after every increment of clarity (hard rule 1).
5. A box revealed to sit past the destination gets closed and gisted under Out of scope with the reason. It is a scope boundary, not a decision, so it stays out of Decisions so far.
6. Repeat or stop. Any point is a clean break: the next session resumes from the map alone.

## Choosing the store

The model above is store-agnostic. Ask the operator where records live before creating anything, and write the choice into Notes. A whitebox map is work-in-progress material, like an RFC draft: it may deliberately not belong in the repo it concerns.

| Store | Map | Boxes | Fits when |
|---|---|---|---|
| markdown directory (reference store) | `<dir>/<slug>/map.md` | `<dir>/<slug>/boxes/*.md` | default. `<dir>` may be an in-repo knowledge path, or outside the repo entirely (`~/whitebox/`, `/tmp/`) when WIP must not touch version control |
| issue tracker | parent issue or epic, mermaid block in its body | child issues, one per box | the team already lives in the tracker; native blocking shows the frontier in the tracker UI; colours become labels |

Never assume the store, and never scatter files into a repo uninvited. Real outputs the boxes point at (ADRs, specs, tickets) go wherever the operator's systems keep them; the map only links.

## Fallbacks

The skill is self-sufficient. For each capability below: if a matching skill is registered, invoke it; otherwise the embedded guidance is enough.

- **Domain modeling**: keep one name per concept and challenge collisions the moment they appear. Separate domain-level language (what the business means) from application-level language (what the software does). Model entities and their relationships, never implementation details. When a decision is hard to reverse, surprising to a future reader, and the product of a real trade-off, record it as an ADR; all three or it is not one.
- **Questioning**: Socratic, one question at a time.
- **Prototyping**: build the cheapest throwaway artifact that makes the question concrete (outline, stub, mock, script), react to it, decide, discard.
- **Research**: dispatch a subagent to read the docs, APIs, or code and return facts; link findings from the box.

## Common mistakes

| Mistake | Fix |
|---|---|
| Building the thing mid-map | Edge of the map reached: box what remains, stop building |
| Assuming scale, latency, security, budget silently | Ask, box it, or write the assumption in Notes |
| Updating the map at session end | Write-through-box: persist at the moment of clarity |
| Answering a dialogue box for the operator | Record the pending question; the box waits |
| Pasting research or full decisions into the map | Map gists and links; content lives in the box record |
| Hand-flipping a parent white | Parents whiten themselves when children do |
| Boxing a vague hunch | Cannot state it sharply = open unknown inside the nearest box |
| Depth-diving one thread while charting | Charting is breadth; depth belongs to Working |
| Choosing where files go by yourself | The operator picks the store, always; nothing is written before that choice, not even in a scratch dir |
