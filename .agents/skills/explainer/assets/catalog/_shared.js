/* ============================================================
   SHARED DATA + RENDERERS for the explainer-technique catalog.

   WHY THIS FILE EXISTS
   Techniques differ in INTERACTION SHAPE, not content. So the content
   (a fictional "preview" change on a support auto-responder: lifecycle
   stations, changed code units, value provenance) lives here ONCE, and
   every technique demo renders it its own way. When the skill generalises a
   technique, THIS is the part you swap: replace STATIONS / UNITS / VALUES
   with your own change.

   NOTE: the subject below (auto-responder, preview mode, no-op doubles) is
   entirely fictional — a stand-in to demonstrate the techniques. It mirrors a
   common shape: one code path, driven by real reads + neutralised writes, so a
   "preview" needn't be a second path.

   INDENTATION FIX
   Diff lines are stored as arrays of {tag, text} where `text` keeps its
   REAL leading spaces. renderDiff() emits each on a `white-space:pre` row,
   so Python indentation survives (HTML would otherwise collapse it).
   ============================================================ */

/* ---------- CHANGED CODE UNITS (indentation preserved) ----------
   tag: 'add' | 'del' | 'ctx'. text: verbatim, leading spaces intact. */
const UNITS = {
  process: {
    title: "process_ticket(...)", file: "responder.py", kind:"changed",
    diff: [
      ["ctx", "def process_ticket(body, *, store, classify_fn, reply_fn,"],
      ["ctx", "                   status, draft_writer, ...):"],
      ["del", ") -> str | None"],
      ["add", ") -> RunReport"],
      ["ctx", "    ..."],
      ["del", "    return \"AUTO_REPLIED\""],
      ["add", "    return RunReport(\"AUTO_REPLIED\", verdict=v,"],
      ["add", "                     evidence=evidence, draft_key=draft_key,"],
      ["add", "                     reply_text=reply)"],
    ],
    why: "Every exit packs what it computed into a RunReport. The body is otherwise unchanged — side effects already went through injected collaborators.",
  },
  runresult: {
    title: "RunReport (new dataclass)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "@dataclasses.dataclass"],
      ["add", "class RunReport:"],
      ["add", "    outcome: str | None"],
      ["add", "    verdict: Verdict | None = None"],
      ["add", "    evidence: list[Evidence] = field(default_factory=list)"],
      ["add", "    would_queue: bool = False"],
      ["add", "    queue_cause: str | None = None"],
      ["add", "    draft_key: str | None = None"],
      ["add", "    reply_text: str | None = None"],
      ["add", ""],
      ["add", "    @property"],
      ["add", "    def missing_fields(self) -> list[tuple[str, str]]:"],
      ["add", "        return _missing_fields(self.evidence)"],
    ],
    why: "Lets a caller INSPECT a run without re-deriving it from side effects. reply_text is None on early stop or the human-queue fork (an agent owns it).",
  },
  drdeps: {
    title: "preview_deps(real) → Deps (new)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "def preview_deps(real: Deps) -> Deps:"],
      ["add", "    return dataclasses.replace("],
      ["add", "        real,"],
      ["add", "        store=_NoopStore(real.store),   # reads real"],
      ["add", "        status=_NoopStatus(),"],
      ["add", "        draft_writer=_NoopDraft(),"],
      ["add", "        reply_fn=_NoopReply(),"],
      ["add", "        audit=None,                     # no log write"],
      ["add", "    )"],
    ],
    why: "Keep the reasoning collaborators (classify/draft_brief) and the real store for READS; swap every WRITE for a no-op double. process_ticket never learns it is a preview.",
  },
  inertstore: {
    title: "_NoopStore (new)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "class _NoopStore:"],
      ["add", "    def __init__(self, real: TicketStore) -> None:"],
      ["add", "        self._real = real"],
      ["add", ""],
      ["add", "    def get(self, ref):            # reads pass through"],
      ["add", "        return self._real.get(ref)"],
      ["add", ""],
      ["add", "    def claim(self, ref, **_):"],
      ["add", "        print(f\"[preview] would claim {ref.ticket_id}\")"],
      ["add", "        return True               # gate: `if not store.claim(...)`"],
    ],
    why: "Reads are real (real row / channel / creds). claim/transition return True so process_ticket's control-flow gates pass and the ONE path runs end-to-end, persisting nothing.",
  },
  inertwrite: {
    title: "_NoopReply / _NoopStatus / _NoopDraft (new)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "class _NoopReply:"],
      ["add", "    def __call__(self, text: str) -> str:"],
      ["add", "        return \"PREVIEW-send\""],
      ["add", ""],
      ["add", "class _NoopDraft:"],
      ["add", "    def create(self, content) -> str:"],
      ["add", "        return \"DRAFT-9999-PREVIEW\"   # illustrative key"],
    ],
    why: "No Zendesk write, no reply sent, no draft filed. The fake key DRAFT-9999-PREVIEW still lets the reply render in the right SHAPE; the payload flags it illustrative.",
  },
  handler: {
    title: "handler(event, context)", file: "responder.py", kind:"changed",
    diff: [
      ["del", "def handler(event, context) -> None:"],
      ["add", "def handler(event, context):          # may return a payload"],
      ["ctx", "    ..."],
      ["add", "    if event.get(\"preview\"):          # DIRECT invoke, not queue"],
      ["add", "        ticket_id = parse_ticket_arg(event[\"ticket_id\"])"],
      ["add", "        body = Event(kind=\"NEW_TICKET\", ...).model_dump_json()"],
      ["add", "        result = _run(preview_deps(deps), body, ...)"],
      ["add", "        return preview_payload(result)"],
      ["ctx", ""],
      ["ctx", "    for rec in event.get(\"Records\", []):   # queue path"],
      ["del", "        process_ticket(rec[\"body\"], store=..., reply_fn=..., ...)"],
      ["add", "        _run(deps, rec[\"body\"], ...)         # shared helper"],
    ],
    why: "Preview forks at the top on a direct invoke; the queue loop is refactored to call the shared _run helper. Both converge on process_ticket.",
  },
  runhelper: {
    title: "_run(deps, body, …) → RunReport (new)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "def _run(deps, body, *, now_iso, lease_expiry_ts) -> RunReport:"],
      ["add", "    return process_ticket("],
      ["add", "        body, store=deps.store, classify_fn=deps.classify_fn,"],
      ["add", "        reply_fn=deps.reply_fn, status=deps.status, ...)"],
    ],
    why: "The ONE place a Deps is unpacked into process_ticket's params. Queue path passes deps; preview passes preview_deps(deps). No duplication to drift.",
  },
  payload: {
    title: "PreviewPayload + preview_payload (new)", file: "responder.py · NEW", kind:"new",
    diff: [
      ["add", "class PreviewPayload(pydantic.BaseModel):"],
      ["add", "    preview: bool = True"],
      ["add", "    outcome: str | None"],
      ["add", "    would_queue: bool"],
      ["add", "    verdict: dict | None"],
      ["add", "    missing_fields: list[list[str]]"],
      ["add", "    reply_text: str | None"],
      ["add", "    note: str"],
    ],
    why: "Fixed-shape external payload → a Pydantic model, not a bare dict (boundary payloads are Pydantic). handler returns .model_dump().",
  },
  just: {
    title: "just preview TICKET (new recipe)", file: "justfile · NEW", kind:"new",
    diff: [
      ["add", "preview TICKET:"],
      ["add", "    id=$(echo \"{{TICKET}}\" | grep -oE '<uuid>' | head -1)"],
      ["add", "    fn=$(aws cloudformation ... ResponderFn PhysicalResourceId)"],
      ["add", "    aws lambda invoke --function-name \"$fn\" \\"],
      ["add", "      --payload '{\"preview\":true,\"ticket_id\":\"'$id'\"}' \"$out\""],
    ],
    why: "Human entry point: DIRECT invoke of the deployed ResponderFn (its real IAM identity), pretty-print the payload. Writes nothing on the live instance.",
  },
  oldret: {
    title: "return value (before)", file: "responder.py", kind:"before",
    diff: [ ["del", "return \"AUTO_REPLIED\"   # or \"HUMAN_QUEUE\" or None"] ],
    why: "Caller learned only the terminal state. verdict / reply / evidence lived only in side effects and logs — no way to inspect a run without doing its writes.",
  },
};

/* ---------- LIFECYCLE SPINE: the full request path, entry → exit ----------
   Each station: id, label, role, what it reads/writes, the unit ids it owns,
   and whether the preview change touches it. This is the "whole data flow"
   the earlier views were missing. */
const STATIONS = [
  { id:"ddissue", label:"① Zendesk ticket", role:"input",
    sub:"a support ticket arrives (id = uuid)", touched:false,
    detail:"The raw input. A Zendesk webhook surfaces a new ticket. Identified by a uuid. This is what `just handle <id>` / `just preview <id>` name.",
    units:[] },
  { id:"monitor", label:"② Intake (ingress adapter)", role:"read",
    sub:"fetch ticket, seen_if_new → row (channel/lang)", touched:false,
    detail:"Translates the producer-specific Zendesk ticket into the canonical envelope. Writes the ticket ROW (state=RECEIVED) carrying channel + lang. NOTE: channel is set HERE, on the row — this is where process_ticket later reads it from, NOT the event.",
    units:[] },
  { id:"envelope", label:"③ Event envelope (JSON)", role:"input",
    sub:"kind=NEW_TICKET, subject.ticket_id, payload", touched:true,
    detail:"The canonical inbox envelope. process_ticket validates this with Event.model_validate_json. The preview handler CONSTRUCTS one of these synthetically instead of receiving it from the queue.",
    units:["handler"] },
  { id:"sqs", label:"④ Queue → handler", role:"core",
    sub:"live: queue Records · preview: direct invoke", touched:true,
    detail:"The Responder Lambda entry. Live path: the queue delivers Records, handler loops. Preview path (NEW): a direct `aws lambda invoke` with {preview:true} forks at the top of handler — no Records.",
    units:["handler","runhelper","just"] },
  { id:"deps", label:"⑤ Deps", role:"core",
    sub:"live: real · preview: no-op writes", touched:true,
    detail:"The collaborators process_ticket uses. THE change lives here: preview_deps swaps every WRITE collaborator for a no-op double while keeping reads + reasoning real. process_ticket itself never changes.",
    units:["drdeps","inertstore","inertwrite"] },
  { id:"runworker", label:"⑥ process_ticket", role:"core",
    sub:"claim → classify → verdict → fork", touched:true,
    detail:"The one code path. Validates the envelope, claims the lease, reads channel from the ROW, classifies (LLM), then forks on the verdict: send an auto-reply, or queue for a human. Every side effect is via an injected collaborator.",
    units:["process"] },
  { id:"fork", label:"⑦ Fork: reply | queue", role:"core",
    sub:"confident → auto-reply · else → human", touched:false,
    detail:"Pure function of the Verdict. Confident + answerable → draft the reply and send. Low-confidence / needs-human → queue: file a draft, route to an agent, NO reply sent.",
    units:[] },
  { id:"result", label:"⑧ RunReport / side effects", role:"result",
    sub:"live: writes fire · preview: RunReport only", touched:true,
    detail:"Live: the collaborators performed real writes (store/status/reply/draft/log) and process_ticket returns a RunReport. Preview: writes were no-ops, the RunReport (verdict + reply_text + missing_fields) is rendered to a PreviewPayload and returned. Nothing persisted.",
    units:["runresult","payload","oldret"] },
];

/* ---------- VALUE PROVENANCE: where each value is born / read / used ----------
   Each value maps to station ids for born/reads/uses + a note. Powers the
   "where does this come from?" technique. */
const VALUES = {
  env: {
    label:"channel", type:"str | None",
    born:"monitor", reads:["runworker"], uses:["runworker","result"],
    trail:[
      ["monitor","BORN — Intake sets channel on the ticket row at seen_if_new"],
      ["runworker","READ — process_ticket reads row.get('channel'), NOT event.payload"],
      ["result","USED — scopes classifier reads + stamps the draft's tags"],
    ],
    note:"Common gotcha: the preview handler puts channel on the constructed Event, but process_ticket ignores that and reads channel from the real row (via _NoopStore.get pass-through). So channel is correct in a preview because the READ is real."
  },
  ticket_key: {
    label:"draft_key", type:"str | None",
    born:"fork", reads:["result"], uses:["result"],
    trail:[
      ["fork","BORN — draft_writer.create() returns a key on both post-classify forks"],
      ["result","CARRIED — packed into RunReport.draft_key"],
      ["result","PREVIEW — _NoopDraft.create returns fake DRAFT-9999-PREVIEW"],
    ],
    note:"On a preview the key is illustrative (DRAFT-9999-PREVIEW) so the reply template renders in a real SHAPE with no Zendesk write."
  },
  hands_prompt: {
    label:"reply_text", type:"str | None",
    born:"fork", reads:["result"], uses:["result"],
    trail:[
      ["fork","BORN — _compose_reply(brief, draft_key) on the AUTO-REPLY fork only"],
      ["result","CARRIED — RunReport.reply_text; None on queue/early-stop"],
      ["result","PREVIEW — surfaced in PreviewPayload for inspection (no send)"],
    ],
    note:"None whenever no reply was composed: early stop, or the human-queue fork (an agent owns it)."
  },
  verdict: {
    label:"verdict", type:"Verdict | None",
    born:"runworker", reads:["fork","result"], uses:["fork","result"],
    trail:[
      ["runworker","BORN — classify_fn(ticket_id, channel) returns (Verdict, evidence)"],
      ["fork","READ — the fork is a pure function of the Verdict"],
      ["result","CARRIED — RunReport.verdict, rendered into PreviewPayload"],
    ],
    note:"Real in a preview: classify_fn is a reasoning collaborator, kept real by preview_deps. The preview's whole point is to see this without writing."
  },
  outcome: {
    label:"outcome", type:"str | None",
    born:"result", reads:["result"], uses:["result"],
    trail:[
      ["result","BORN — the terminal state process_ticket drove the Ticket to"],
      ["result","AUTO_REPLIED / HUMAN_QUEUE, or None on early stop / lost transition"],
    ],
    note:"Distinct from would_queue: outcome is None if the queue transition was lost, but would_queue still records the fork DECISION."
  },
};

/* ---------- RENDERERS ---------- */
function esc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}

/* indentation-safe diff: each line on its own white-space:pre row */
function renderDiff(unitId){
  const u = UNITS[unitId]; if(!u) return "";
  const gut = {add:"+", del:"-", ctx:" "};
  const rows = u.diff.map(([tag,text]) =>
    `<span class="row ${tag}"><span class="gut">${gut[tag]}</span>${esc(text)}</span>`
  ).join("");
  return `<div class="diff">${rows}</div>`;
}
/* full detail block: diff + why + file */
function renderUnit(unitId){
  const u = UNITS[unitId]; if(!u) return "";
  return renderDiff(unitId) +
    `<div class="why"><b>Why:</b> ${u.why}</div>` +
    `<div class="filetag">${u.file}</div>`;
}
function unitTitle(unitId){ return UNITS[unitId] ? UNITS[unitId].title : unitId; }

/* topbar every demo includes */
function topbar(num, name, good, bad){
  return `<div class="topbar">
    <a href="../index.html">◀ catalog</a>
    <span class="tnum">${num}</span>
    <span class="tname">${name}</span>
    <span class="spacer"></span>
    <span class="goodbad"><b>good for:</b> ${good} &nbsp;·&nbsp; <b>weak for:</b> ${bad}</span>
  </div>`;
}
function legend(){
  return `<div class="legend">
    <span class="k"><span class="dot" style="background:var(--read)"></span>real read</span>
    <span class="k"><span class="dot" style="background:var(--write)"></span>real write</span>
    <span class="k"><span class="dot" style="background:var(--inert)"></span>no-op double</span>
    <span class="k"><span class="dot" style="background:var(--result)"></span>RunReport</span>
  </div>`;
}

/* ============================================================
   PRIMITIVE: ANNOTATED SOURCE (reusable across techniques)
   A real code listing with line numbers, correct indentation, and
   expandable gutter notes on specific lines. Techniques EMBED this
   wherever they show code, so annotated-source becomes a building
   block, not a standalone page. Data model: SOURCES[key] = { file,
   lines:[ {code, note?} ] }. code keeps real leading spaces.
   ============================================================ */
const SOURCES = {
  handler_dryrun: {
    file:"responder.py · handler()",
    lines:[
      {code:"def handler(event, context):          # may return a payload"},
      {code:"    ..."},
      {code:"    # Preview: a DIRECT invoke {\"preview\":true,\"ticket_id\":<id>}"},
      {code:"    # — NOT a queue event (no Records)."},
      {code:"    if event.get(\"preview\"):",
       note:"THE fork. A direct `aws lambda invoke` sets this; queue deliveries never do. Everything indented below is the new preview path."},
      {code:"        ticket_id = parse_ticket_arg(event[\"ticket_id\"])"},
      {code:"        body = Event("},
      {code:"            kind=\"NEW_TICKET\", subject=Subject(ticket_id=ticket_id),"},
      {code:"            source=SOURCE, occurred_at=now.isoformat(),"},
      {code:"            payload=NewTicketPayload(lang=event.get(\"lang\"),",
       note:"GOTCHA: channel/lang here are essentially dead — process_ticket reads channel from the real ROW (row.get('channel')), not this payload. Set for shape parity only."},
      {code:"                                     first_seen_ms=0, channel=event.get(\"channel\")),"},
      {code:"            raw={\"id\": ticket_id},"},
      {code:"        ).model_dump_json()"},
      {code:"        result = _run(preview_deps(deps), body,",
       note:"The whole trick: same _run/process_ticket, handed preview_deps(deps) — no-op write collaborators. lease_expiry_ts=now (never-expired) is a deliberate no-op since claim is a no-op."},
      {code:"                      now_iso=now.isoformat(), lease_expiry_ts=now.isoformat())"},
      {code:"        return preview_payload(result)",
       note:"Only the preview path returns a value; the queue loop returns None. handler's return type widened to allow this."},
      {code:""},
      {code:"    for rec in event.get(\"Records\", []):   # the unchanged live path",
       note:"Live path, now calling the shared _run helper instead of inlining process_ticket."},
      {code:"        _run(deps, rec[\"body\"],"},
      {code:"             now_iso=now.isoformat(), lease_expiry_ts=lease_expiry.isoformat())"},
    ],
  },
  dry_run_deps: {
    file:"responder.py · preview_deps()",
    lines:[
      {code:"def preview_deps(real: Deps) -> Deps:",
       note:"Turns real deps into preview deps. process_ticket is handed these and never learns it is a preview — that is the ONE-code-path guarantee."},
      {code:"    return dataclasses.replace("},
      {code:"        real,"},
      {code:"        store=_NoopStore(real.store),   # reads real, writes no-op",
       note:"Reads pass through to the real store (real row/channel/creds); only writes are neutralised."},
      {code:"        status=_NoopStatus(),"},
      {code:"        draft_writer=_NoopDraft(),"},
      {code:"        reply_fn=_NoopReply(),"},
      {code:"        audit=None,                     # no log trail",
       note:"audit=None means the whole log-write path is simply skipped — no no-op double needed, the code already guards `if audit is not None`."},
      {code:"    )"},
    ],
  },
  inertstore: {
    file:"responder.py · _NoopStore",
    lines:[
      {code:"class _NoopStore:"},
      {code:"    def __init__(self, real: TicketStore) -> None:"},
      {code:"        self._real = real"},
      {code:"    def get(self, ref):            # reads pass through",
       note:"The read is REAL. This is why a preview gets channel/lang right — it reads the actual row the Intake wrote."},
      {code:"        return self._real.get(ref)"},
      {code:"    def claim(self, ref, **_):"},
      {code:"        print(f\"[preview] would claim {ref.ticket_id}\")"},
      {code:"        return True               # gate: `if not store.claim(...)`",
       note:"Returns the truthy value the control-flow gate expects, so process_ticket runs to the end instead of bailing — persisting nothing."},
    ],
  },
};

/* render an annotated source listing (line numbers + gutter note markers) */
function renderAnnotatedSource(key, opts){
  const s = SOURCES[key]; if(!s) return "";
  const idp = (opts && opts.idPrefix) || ("as_" + key);
  const rows = s.lines.map((ln,i) => {
    const hasNote = !!ln.note;
    const marker = hasNote ? `<span class="as-mark">●</span>` : `<span class="as-mark as-empty"></span>`;
    const noteRow = hasNote
      ? `<div class="as-note" id="${idp}_n${i}"><b>note:</b> ${esc(ln.note)}</div>` : "";
    const cls = hasNote ? "as-line has-note" : "as-line";
    const onclick = hasNote ? `onclick="asToggle('${idp}_n${i}',this)"` : "";
    return `<div class="${cls}" ${onclick}>
      <span class="as-gutter">${marker}<span class="as-num">${i+1}</span></span>
      <span class="as-code">${esc(ln.code) || "&nbsp;"}</span>
    </div>${noteRow}`;
  }).join("");
  return `<div class="as-file">${s.file}</div><div class="as-listing">${rows}</div>`;
}
/* toggle helper for annotated-source notes (technique pages can override) */
function asToggle(noteId, lineEl){
  const n = document.getElementById(noteId);
  if(!n) return;
  const open = n.classList.toggle("open");
  if(lineEl) lineEl.classList.toggle("active", open);
}

/* ============================================================
   PROVENANCE ZOOM DATA (redesign of technique 02)
   Each value gains bornCode / useCode: the ACTUAL code where it is
   born and where it is used, so the reader zooms into context instead
   of reading a bare trail. {station, file, lines:[{code, hi?}]} — hi
   marks the line to highlight.
   ============================================================ */
const VALUE_CODE = {
  env: {
    born:{ station:"monitor", file:"intake / store.seen_if_new", lines:[
      {code:"# Intake translates the Zendesk ticket and writes the row:"},
      {code:"store.seen_if_new(ref, lang=lang,"},
      {code:"                  first_seen_ms=ms, ts=now, channel=channel)", hi:true},
      {code:"# channel is persisted ON THE ROW here — its point of birth."},
    ]},
    use:{ station:"runworker", file:"responder.py · process_ticket", lines:[
      {code:"row = store.get(ref)"},
      {code:"channel = row.get(\"channel\") if row else None", hi:true},
      {code:"# read from the ROW, NOT event.payload — this is the gotcha."},
      {code:"v, evidence = classify_fn(ticket_id, channel)   # scopes reads"},
    ]},
  },
  hands_prompt: {
    born:{ station:"fork", file:"responder.py · auto-reply fork", lines:[
      {code:"draft_key = draft_writer.create(content)"},
      {code:"reply = _compose_reply(brief, draft_key=draft_key,", hi:true},
      {code:"                       channel=channel)"},
      {code:"# built ONLY on the auto-reply fork; queue builds none."},
    ]},
    use:{ station:"result", file:"responder.py · RunReport / payload", lines:[
      {code:"return RunReport(\"AUTO_REPLIED\", verdict=v,"},
      {code:"                 reply_text=reply)", hi:true},
      {code:"# preview surfaces this in PreviewPayload for inspection —"},
      {code:"# you SEE the reply without sending it."},
    ]},
  },
  ticket_key: {
    born:{ station:"fork", file:"responder.py · _ensure_draft", lines:[
      {code:"key = draft_writer.create(content)", hi:true},
      {code:"# live: real Zendesk draft key. preview: _NoopDraft"},
      {code:"# returns \"DRAFT-9999-PREVIEW\" (illustrative)."},
    ]},
    use:{ station:"result", file:"responder.py · reply template", lines:[
      {code:"subject = reply_subject(draft_key, slug)", hi:true},
      {code:"# → \"[DRAFT-9999-PREVIEW] Re: <slug>\" on a preview"},
      {code:"lines.append(f\"Reference: {draft_key}\")"},
    ]},
  },
  verdict: {
    born:{ station:"runworker", file:"responder.py · classify", lines:[
      {code:"v, evidence = classify_fn(ticket_id, channel)", hi:true},
      {code:"# classify_fn is a REASONING collaborator, kept real by"},
      {code:"# preview_deps — so the verdict is real in a preview."},
    ]},
    use:{ station:"fork", file:"responder.py · fork", lines:[
      {code:"if _needs_human(v, confidence_threshold):", hi:true},
      {code:"    ... queue ...                 # pure fn of the Verdict"},
      {code:"else:"},
      {code:"    ... send the auto-reply ..."},
    ]},
  },
};

/* render a born/use code pane for provenance zoom */
function renderValueCodePane(codeBlock){
  if(!codeBlock) return "";
  const rows = codeBlock.lines.map(l =>
    `<span class="row ${l.hi?"hi":""}">${esc(l.code) || "&nbsp;"}</span>`
  ).join("");
  return `<div class="pz-file">${codeBlock.file}</div><div class="pz-pane">${rows}</div>`;
}
