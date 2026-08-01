# Whitebox skill: design

Date: 2026-08-01. Status: approved pending final review.

Derived from Matt Pocock's `wayfinder` + `domain-modeling` skills, rebuilt standalone with systems-theory semantics.

## Problem

A loose idea arrives, too big for one agent session. The way from idea to actionable work isn't visible. Need a durable, session-independent process that decomposes one opaque idea into clarified, connected pieces, resumable at any point, with zero reliance on conversation context.

Original wayfinder solves this but: depends on sibling skills (`/grilling`, `/domain-modeling`, `/prototype`, `/research`, tracker setup), uses "ticket" semantics that mislead (these are decision records, not Jira work items), models the unknown as "fog of war" (a spatial metaphor needing a global orphan list), and hardwires an issue tracker.

## Concept

**Whiteboxing**: decompose one root black box into a DAG of boxes until every box is white and the way is clear. Systems framing: a system is a composition of subsystems; decomposition reveals them.

Two anchor fields, deliberately separate:

- **Mission**: product goal ("build a content creation system"). The why.
- **Destination**: what done looks like for *this map* (spec ready to hand off / decision locked / change made in place). Fixes scope; tells the process when to stop. Without it, plan-don't-do discipline dies.

**Plan, don't do**: each box resolves a decision. The pull to start building is the signal you've reached the map's edge.

## Box states

- **black**: boundary named, interior unexplored. Question maybe not yet sharply posed.
- **grey**: opened. Partially decided, decomposed, or drafted-and-under-review (ADR case).
- **white**: own decision final AND all children white. Parent colour always derived, never hand-asserted.

Interior fog: each box carries an "open unknowns" list, questions not yet sharp enough to be boxes. No global fog section; unattributable unknowns live in the root box. Test for unknown vs new box: can the question be stated precisely now? (Not: can it be answered now.)

## The map

Index, not store. One map per effort. A decision's detail lives in exactly one place (its box); the map gists and links.

```markdown
# <effort name>
## Mission          <1-2 lines>
## Destination      <1-2 lines>
## Notes            <domain, standing prefs, backend config, skills to consult>
## Map              <mermaid DAG>
## Decisions so far <one line per white box: gist + link>
## Out of scope     <gist + why + link. Never revisited on this map>
```

Mermaid block owns topology + state, nothing else: `classDef` per colour (black/grey/white), edges labelled `blocks` (hard dependency) / `informs` (soft), nodes click-link to box records. Content never lives in the diagram. **Frontier** = black/grey boxes with no open blockers = workable now.

## Boxes

One record per box: Question, Method, State, Decision (once made), Open unknowns, Links (research findings, prototypes, ADR/spec documents). Assets are linked, never pasted in.

Methods (how whitening happens):

| Method | Mode | Whitening means |
|---|---|---|
| dialogue | with human | question answered via Socratic questioning (default) |
| research | agent alone | fact surfaced from docs/APIs/codebase, findings linked |
| prototype | with human | cheap artifact built, reacted to, decision taken |
| task | either | prerequisite work done (provision access, move data), facts recorded |
| adr | with human | decision record drafted (grey) then accepted (white) |

Hard rule: human-in-loop boxes are never self-answered by the agent.

## Non-functional requirements (soft gate)

Agents habitually assume NFRs (scale, latency, availability, security, cost, compliance, operability) without asking. Rule: **never assume an NFR silently.**

- During charting, after destination is pinned: if the effort designs or changes a system, sweep NFR dimensions. Each *relevant* dimension becomes either an answered question, its own box, or an explicitly recorded assumption in map Notes. Irrelevant dimensions skipped (soft gate; a course-content map has none).
- During work: when a decision hinges on an unstated NFR, stop and ask, or box it. Never paper over.

Functional requirements need no gate: whiteboxing surfaces them naturally.

## Backend: model vs store

Skill defines the model + operations (create box, wire edge, flip state, record decision). The store is chosen by the operator at charting time, recorded in map Notes, never assumed. A whiteboxing session is WIP (RFC-like); it may deliberately live outside the repo to keep commits clean.

Reference store = markdown: `<chosen-dir>/<slug>/map.md` + `boxes/*.md`. Skill offers guidance, then asks: in-repo knowledge path, outside-repo dir (e.g. /tmp, ~/whitebox), or external tracker (map = epic/parent issue, boxes = child issues, native blocking, colour labels).

Resume: point any fresh session at the map (path or URL). Zero dependence on session context.

## Workflow

**Chart** (loose idea arrives):
1. Pin mission + destination via questioning.
2. NFR soft gate (above).
3. Breadth-first sweep: fan out across the whole space, surface boxes. If no fog surfaces, say so: no map needed, stop.
4. Ask operator for store; create map + boxes; wire edges in a second pass (records need identities before referencing each other).
5. Fire research subagents for research boxes, in parallel.

**Work** (map exists):
1. Load map only (low-res); zoom into box records on demand.
2. Pick a frontier box: operator's pick wins, else first unblocked.
3. Whiten via its method.
4. **Write-through-box**: persist the instant clarity lands or a new unknown appears. Decision → box record; gist → map; colour flip → mermaid; new boxes wired in; invalidated boxes updated or closed out of scope. Map never lags context.
5. No per-session quota. Stop anytime; resume anytime.

Out of scope handling: a box revealed to sit past the destination is closed and gisted under Out of scope (scope boundary, not a step on the route; stays out of Decisions so far).

## Embedded fallbacks (standalone-ness)

Pattern, used four times: "If a skill for X is registered, invoke it; otherwise follow the embedded guidance."

- **Domain modeling**: ubiquitous language; entities + relationships; domain vs application level; never implementation language. Challenge terms that conflict with established vocabulary. ADR three-criteria test: hard to reverse + surprising later + real trade-off.
- **Questioning**: Socratic, one question at a time (name-drop only, no rule catalogue).
- **Prototyping**: cheap throwaway artifact to react to (outline, stub, mock, script).
- **Research**: subagent reads docs/APIs/codebase, returns facts; findings linked from the box.

## Ending

Map done when every box is white or out of scope. An all-white map is raw material: slicing into specs/tickets, transfer to other systems, any reinterpretation is the operator's business, outside this skill. ADRs are the exception: they emerge continuously as adr boxes during the process.

## Packaging

Single `SKILL.md` at `~/.agents/skills/whitebox/`, no scripts. Relative symlink into `~/.claude/skills/whitebox`. `dot add -f` both paths. Description triggers: whitebox, whiteboxing, black box decomposition, "idea too big for one session", chart a map, loose idea shaping.

## Decisions log (from design interview)

- Name: **whitebox** (over gretchenfrage, kalman, minesweeper et al).
- Socratic method: named once, no operational rule catalogue.
- Map format: hybrid. Mermaid owns topology + colours; box files own content.
- Pacing: no per-session quota; **write-through-box** persistence is a MUST.
- Store: operator-chosen at charting, never assumed; markdown is the reference backend.
- Emission: none. ADR-as-box continuous; end-state slicing is out of scope for the skill.
- NFR soft gate: never assume NFRs silently; sweep at charting when the effort warrants it.
