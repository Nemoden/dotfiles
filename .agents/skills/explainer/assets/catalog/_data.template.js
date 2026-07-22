/* ============================================================
   DATA CONTRACT for the HTML explainer tier.

   HOW TO USE: copy _shared.js, then REPLACE the data blocks below with
   YOUR subject. The renderers + every technique file stay untouched — a
   new explainer is a DATA SWAP, not a rewrite. Fill only the blocks a
   chosen technique needs (see catalog.json → each technique's `needs`).

   Keep the RENDERERS from _shared.js verbatim (esc, renderDiff, renderUnit,
   unitTitle, topbar, legend, renderAnnotatedSource, asToggle,
   renderValueCodePane). Only the DATA below changes.

   INDENTATION RULE (do not violate): every code string keeps its REAL
   leading spaces. Renderers emit them on white-space:pre rows. Never strip
   or normalise indentation — flattened Python is the #1 failure mode.
   ============================================================ */

/* UNITS — changed code units. Needed by: most techniques.
   tag: 'add' | 'del' | 'ctx'. text: verbatim, leading spaces intact. */
const UNITS = {
  // exampleUnit: {
  //   title: "func_name(...)", file: "path.py", kind: "changed" | "new" | "before",
  //   diff: [
  //     ["ctx", "def func_name(arg):"],
  //     ["del", "    return old"],
  //     ["add", "    return new"],
  //   ],
  //   why: "One sentence: why this change / what it buys.",
  // },
};

/* STATIONS — the end-to-end lifecycle spine. Needed by: spine, provenance,
   step, dual-lens, minimap, fisheye, timeline, and the spine-based combos.
   role: input | read | core | result (maps to node color). touched: does
   the change affect this station? units: unit ids this station owns. */
const STATIONS = [
  // { id:"input",  label:"① Input",   role:"input",  sub:"what enters",       touched:false, detail:"...", units:[] },
  // { id:"core",   label:"② Core",    role:"core",   sub:"the work",          touched:true,  detail:"...", units:["exampleUnit"] },
  // { id:"result", label:"③ Result",  role:"result", sub:"what exits",        touched:true,  detail:"...", units:[] },
];

/* VALUES — value provenance metadata. Needed by: value-provenance + combos
   that trace values. born/reads/uses reference STATION ids. */
const VALUES = {
  // someValue: {
  //   label:"someValue", type:"str | None",
  //   born:"core", reads:["result"], uses:["result"],
  //   trail:[ ["core","BORN — where it is created"], ["result","USED — where it is read"] ],
  //   note:"The non-obvious thing about this value.",
  // },
};

/* VALUE_CODE — the ACTUAL code where a value is born / used (provenance
   ZOOM). Needed by: value-provenance (redesigned) + combos D/E.
   hi:true marks the highlighted line. */
const VALUE_CODE = {
  // someValue: {
  //   born:{ station:"core", file:"path.py · where born", lines:[
  //     {code:"x = compute()", hi:true},
  //   ]},
  //   use:{ station:"result", file:"path.py · where used", lines:[
  //     {code:"return package(x)", hi:true},
  //   ]},
  // },
};

/* SOURCES — annotated real source listings (line notes). Needed by:
   annotated-source + every combo that embeds it. code keeps leading spaces;
   note is optional per line (a ● gutter marker appears where present). */
const SOURCES = {
  // someFunc: {
  //   file:"path.py · func()",
  //   lines:[
  //     {code:"def func(x):"},
  //     {code:"    if x:", note:"Why this branch matters."},
  //     {code:"        return do(x)"},
  //   ],
  // },
};
