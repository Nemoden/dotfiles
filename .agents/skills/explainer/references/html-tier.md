# HTML tier — building an interactive explainer

The expensive, high-fidelity tier. Only build after ascii/mermaid was
considered (see `decision-rules.md`) and the subject earns it. Output opens in
a browser with no server/CDN.

## Table of contents
- The locked design system
- Build steps (data swap)
- The data contract
- Combining techniques
- Theming (dark + light, switchable)

## The locked design system

`assets/catalog/_shared.css` + `assets/catalog/_shared.js` ARE the design
system. Every technique file links them and calls their renderers. You do NOT
restyle per explainer — you swap DATA. This is what makes output reproducible
and consistent.

Renderers provided by `_shared.js` (use verbatim, never fork):
- `renderBoundary(elId)` / `classifyValue(v,key)` / `valueKeysByBoundary()` /
  `classBadge(key)` / `classNote(key)` — the boundary layer for provenance.
- `esc(s)` — HTML-escape.
- `richText(s)` — escape THEN render inline code from `` `backticks` `` and
  literal `<code>` tags. Use for PROSE fields that embed identifiers (notes,
  rationale, purpose); never for code panes (they show backticks verbatim).
- `noteSeverity(note)` — rank a line-note danger|warn|info|dim from its prose
  (no severity field needed); drives the annotated-source dot colour so the
  reader hits the highest-signal lines first.
- `renderDiff(unitId)` / `renderUnit(unitId)` — indentation-safe diff + why + file.
- `unitTitle(unitId)`.
- `renderAnnotatedSource(key, opts)` / `asToggle(...)` — literate code + line
  notes. Notes collapse by default (click a `●` line to reveal); the dot is
  coloured by `noteSeverity`.
- `renderValueCodePane(codeBlock)` — born/used code pane for provenance.
- `topbar(num,name,good,bad)` / `legend()` — chrome.

Technique files in `assets/catalog/`: `01-lifecycle-spine.html` …
`15-io-boundary.html` (minus delisted 06/11), plus `combined-examples/A–E`.

**Many pages in one directory:** the data blocks and the renderers must be
split. Put renderers in a shared `_renderers.js` with ZERO data, and give each
page its own `<slug>.data.js`. Copying `_shared.js` per page does not scale past
one subject, because its data blocks are top-level `const` and would collide.

## Build steps (data swap)

1. Pick technique(s) via `references/catalog.json` (`techniques[].needs` tells
   you which data blocks to fill).
2. Create an output dir. Copy `_shared.css` there verbatim.
3. Copy `_shared.js`, then REPLACE its data blocks (UNITS / STATIONS / VALUES /
   VALUE_CODE / SOURCES) with the subject's data. Use
   `assets/catalog/_data.template.js` as the contract skeleton. Keep all
   renderers unchanged.
4. Copy the chosen technique HTML file(s). They already link `./_shared.css`
   and `./_shared.js` and call the renderers — no edits needed beyond the data.
   **If you copy `16-system-topology.html`, also copy `elk.bundled.js` into the
   same dir** — that technique links `./elk.bundled.js` for edge routing and
   must find it as a sibling to open offline. No other technique needs it.
5. If multiple files, keep an `index.html` catalog-style launcher (see the
   golden `references/example-dryrun/index.html`).
6. Run the HTML section of `references/quality-gate.md`. Open it to confirm.

## The data contract

See `assets/catalog/_data.template.js` for the annotated skeleton. Summary:

- **UNITS** — changed code units `{title,file,kind,diff:[[tag,text]…],why}`.
  `tag` ∈ add|del|ctx; `text` keeps REAL leading spaces.
- **STATIONS** — lifecycle spine `{id,label,role,sub,touched,detail,units[]}`.
  `role` ∈ input|read|core|result.
- **VALUES** — provenance metadata `{label,type,born,reads[],uses[],trail[],note}`.
  `born` may be `null` when the value does not exist in the system at all —
  that absence is often the finding.
- **VALUE_CODE** — born/use code panes `{born:{station,file,lines:[{code,hi}]},use:{…}}`.
- **SOURCES** — annotated listings `{file,lines:[{code,note?}]}`.
- **BOUNDARY** — the system's surface
  `{box,inside[],outside[],third_party[],classes{},trust_notes{},note}`.
  Required by `io-boundary`; optional-but-recommended for `value-provenance`,
  where it sorts values by crossing and badges each IN/THROUGH/OUT/LOCAL.
  Prefer authored `classes` over inference — see `decision-rules.md` →
  "Rank by boundary crossing" for the three traps that make inference wrong.

INDENTATION is load-bearing: never strip leading spaces from any `code`/`text`.

## Combining techniques

Follow the composition rule in `decision-rules.md` (default 1, +1 side-car max
in most cases, 3 ceiling, 5 = anti-pattern). The combined examples in
`assets/catalog/combined-examples/` are working references:
- A: spine frame, annotated-source inside each station.
- B: step-through primary, state-machine side-car.
- C: minimap + fisheye + annotated (never-lose-context).
- D: altitude ladder, annotated + provenance at ground.
- E: workbench — anti-pattern reference; do not ship by default.

Annotated-source embeds cleanly anywhere code is shown — prefer it over a raw
diff when the reader benefits from line-level notes.

## Theming (dark + light, switchable)

Theme = the CSS-variable values in the blocks at the top of `_shared.css`. Two
ship: **dark** (GitHub Dark, the default) and **light** (GitHub Light). Every
component references vars only — there are zero hardcoded colours outside those
blocks, and the sweep that proves it is:

```bash
grep -rnE '#[0-9a-fA-F]{3,8}\b|rgba?\([0-9]' --include='*.html' --include='*.js' .
```

Anything it prints (other than `elk.bundled.js`) is a theming bug.

**Reader-facing switch.** `topbar()` injects a `◑ light` / `◐ dark` button, so
every technique gets it for free — no per-page wiring. The choice persists in
`localStorage` under `explainer-theme`.

**Resolution order** — CSS decides the first paint, so there is no dark flash
even though `_shared.js` loads at end-of-body:

1. `:root` → dark (default)
2. `@media (prefers-color-scheme: light)` → light, unless `data-theme="dark"`
3. `[data-theme="light"|"dark"]` on `<html>` → explicit choice wins

### Writing theme-safe CSS

- **Never a literal colour.** Reach for an existing var first.
- **Washes/tints use `color-mix()`, not `rgba()`.** A fixed
  `rgba(88,166,255,.1)` assumes a dark base and turns to mud on white. Write
  `color-mix(in srgb,var(--accent) 10%,var(--bg))` and it self-corrects per
  theme. Mix over `var(--code-bg)` instead when the wash sits on a code pane.
  (`color-mix` baseline: Chrome 111+ / Safari 16.4+ / Firefox 113+.)
- **Ink on a filled surface** uses `--on-accent` / `--on-write` / `--on-inert`.
  These flip from near-black (dark theme) to white (light theme); a hardcoded
  `#08111f` would go invisible.
- **Code panes** use `--code-bg`, which sits *below* `--bg` in dark and *level
  with* it in light. Never `#0a0e14`.
- **Shadows** use `--shadow` (includes its own alpha).
- **Direction-relative shades** — "one notch off the background" must mix
  toward `--ink`, not toward white: `color-mix(in srgb,var(--ink) 3%,var(--bg))`.
- **SVG colours set from JS**: assign `el.style.stroke = "var(--faint)"`. Inline
  style resolves vars and repaints on theme switch; a `setAttribute("stroke",…)`
  presentation attribute does not, and baking a resolved hex at layout time
  leaves edges stuck in the old theme.

A third theme = one more var block. Nothing else changes.
