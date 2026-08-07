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

/* VALUES — value provenance metadata. Needed by: value-provenance, io-boundary,
   + combos that trace values. born/reads/uses reference STATION ids.

   born may be null when the value genuinely does not exist in the system —
   that absence is often the finding, so record it rather than inventing a
   station for it. */
const VALUES = {
  // someValue: {
  //   label:"someValue", type:"str | None",
  //   born:"core", reads:["result"], uses:["result"],
  //   trail:[ ["core","BORN — where it is created"], ["result","USED — where it is read"] ],
  //   note:"The non-obvious thing about this value.",
  // },
};

/* BOUNDARY — the system's surface. Needed by: io-boundary. OPTIONAL but
   strongly recommended for value-provenance: supply it and values sort by
   boundary crossing and each gets a class badge; omit it and every value
   renders as a peer, which hides the only distinction that decides safety.
   See decision-rules.md "Rank by boundary crossing".

       born outside + stays inside  ->  INPUT     (untrusted)
       born outside + leaves again  ->  THROUGH   (relay)
       born inside  + leaves        ->  OUTPUT    (our commitment)
       born inside  + stays inside  ->  LOCAL     (private)

   inside      = code/storage WE own and deploy. In a monorepo, sibling services
                 reached by same-account L2L are INSIDE (same trust domain).
   outside     = a different party or trust domain: the HTTP caller, a browser,
                 an email recipient, a vendor API.
   third_party = the subset of `outside` that is another COMPANY. Rendered
                 distinctly, because "outside" and "someone else's company" are
                 different degrees of outside.
   classes     = AUTHORED class per value key, and it WINS over inference.
                 Prefer it: `born` marks the read site, not the origin, and a
                 value returned to the caller crosses out even though the
                 response station is inside — inference gets both wrong.
   trust_notes = per value key. Set for any value that is caller-controlled AND
                 used for an authorisation, tenant-selection or routing
                 decision. Usually the finding. Rendered in alert styling.

   PROVE ownership before classifying. A vendor is outside even when WE call IT.
   Look for a base URL in an env var, a credential we present, a vendored SDK. */
const BOUNDARY = {
  // box: "orders service (createOrder)",
  // inside: ["handler", "table"],
  // outside: ["caller", "vendorApi"],
  // third_party: ["vendorApi"],
  // classes: { orderId: "input", total: "output", apiKey: "output" },
  // trust_notes: { orderId: "Caller-supplied and selects the tenant; nothing binds it to the caller." },
  // note: "Where the boundary sits and why. Simple HTML allowed.",
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

/* TOPOLOGY — the systems as a NODE-LINK diagram over swimlanes.
   Needed by: system-topology. See decision-rules.md "Model systems as a
   node-link diagram over swimlanes".

   Renders as: one horizontal band per DOMAIN (kind:"ours" | "external");
   dataflow runs left-to-right ACROSS the bands. Each FLOW is a drawn arrow
   whose LABEL is what rides it; the arrow's payload lives in the click-open
   inspector, never on the canvas. Layout is hybrid — the renderer computes
   the swimlane bands + dataflow ranks, and ELK (vendored elk.bundled.js,
   offline) routes the edges + places labels collision-free. Requires
   elk.bundled.js on the page (falls back to a hand-rolled router if absent).

   SYSTEM fields:
     id, label            unique id + display name
     kind                 short tag: "our lambda" | "3rd-party API" | "datastore" | "email sender" …
     care: "high"|"low"   low-care systems render faded (weight, not the WORD "care")
     essence              ONE line shown on the node face (the node's job in 6 words)
     note                 longer prose shown in the inspector when the node is clicked (HTML ok)
     abstract:true        a black box we don't own — drawn dashed
     subsystems:[{name,role,why,care}]   opened in the inspector; care:"low" hidden behind "+N more"

   FLOW fields (an EDGE from → to, both system ids):
     label                short tag drawn ON the arrow ("session token", "L2L", "store row")
     kind                 wire type shown in inspector ("HTTPS POST", "L2L invoke", "SMTP")
     main:[...]           the few fields visible immediately in the inspector
     extra:[...]          further fields behind a "+N more on the wire" click
     carries:[...]        value names this hop transmits — powers the "follow a value" chips
     leaves:true          edge exits our trust domain (drawn dashed)
     transformed:"..."    a subsystem reshaped the payload ("stripped", "templated")
     wire_flag:true       something on the wire widens blast radius (drawn red)
     wire_note            the blast-radius sentence (shown red in the inspector)
     why                  why this edge exists (inspector prose)

   Trust rule: mark another COMPANY's system as an "external" domain, distinct
   from merely outside. Prove ownership (base URL, a credential we present, a
   vendored SDK) before classifying — a vendor is outside even when WE call IT. */
const TOPOLOGY = {
  // lead: "Follow <code>token</code>: enters public, stored, sent to a vendor. Click a hop / a system.",
  // domains: [
  //   { id:"world", label:"Outside world", kind:"external", systems:[
  //     { id:"caller", label:"HTTP caller", kind:"anyone", care:"high", essence:"FE — or anyone. No login checked.",
  //       note:"Route has no authorizer; treat every field as untrusted.",
  //       subsystems:[ {name:"token", role:"the only field", why:"attacker-controllable", care:"high"} ] } ] },
  //   { id:"ours", label:"Our backend", kind:"ours", systems:[
  //     { id:"handler", label:"handler", kind:"our lambda", care:"high", essence:"Validates presence, forwards.",
  //       subsystems:[ {name:"validate", role:"presence only", why:"no ownership check", care:"high"} ] } ] },
  //   { id:"vendor", label:"Third party", kind:"external", systems:[
  //     { id:"api", label:"Vendor API", kind:"3rd-party API", care:"high", abstract:true, essence:"Sees the token." } ] },
  // ],
  // flows: [
  //   { from:"caller", to:"handler", label:"token", kind:"HTTPS POST",
  //     main:["token"], carries:["token"], wire_flag:true,
  //     why:"public route, no auth", wire_note:"anyone with a token reaches this handler" },
  //   { from:"handler", to:"api", label:"token", kind:"HTTPS POST",
  //     main:["token","api_key"], carries:["token"], leaves:true, wire_flag:true,
  //     why:"forwarded to the vendor", wire_note:"the token leaves our trust domain" },
  // ],
  // kicker: "The one takeaway — follow the value chip; it never crosses an auth check.",
};
