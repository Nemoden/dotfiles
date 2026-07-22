# HTML tier — building an interactive explainer

The expensive, high-fidelity tier. Only build after ascii/mermaid was
considered (see `decision-rules.md`) and the subject earns it. Output opens in
a browser with no server/CDN.

## Table of contents
- The locked design system
- Build steps (data swap)
- The data contract
- Combining techniques
- Theming (architected for later)

## The locked design system

`assets/catalog/_shared.css` + `assets/catalog/_shared.js` ARE the design
system. Every technique file links them and calls their renderers. You do NOT
restyle per explainer — you swap DATA. This is what makes output reproducible
and consistent.

Renderers provided by `_shared.js` (use verbatim, never fork):
- `esc(s)` — HTML-escape.
- `renderDiff(unitId)` / `renderUnit(unitId)` — indentation-safe diff + why + file.
- `unitTitle(unitId)`.
- `renderAnnotatedSource(key, opts)` / `asToggle(...)` — literate code + line notes.
- `renderValueCodePane(codeBlock)` — born/used code pane for provenance.
- `topbar(num,name,good,bad)` / `legend()` — chrome.

Technique files in `assets/catalog/`: `01-lifecycle-spine.html` …
`14-focus-context-fisheye.html` (minus delisted 06/11), plus
`combined-examples/A–E`.

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
- **VALUE_CODE** — born/use code panes `{born:{station,file,lines:[{code,hi}]},use:{…}}`.
- **SOURCES** — annotated listings `{file,lines:[{code,note?}]}`.

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

## Theming (architected for later)

Theme = the CSS-variable values at the top of `_shared.css` (`--bg`, `--ink`,
`--read`, `--write`, `--inert`, `--result`, …). A second theme is a drop-in
alternate set of these vars; components reference vars only, never hardcoded
colours. One theme ships now; do not hardcode colours in technique files, so a
theme swap stays a single-file change. Multi-theme switching is deferred, not
walled off.
