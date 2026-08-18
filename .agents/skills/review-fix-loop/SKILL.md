---
name: review-fix-loop
description: >
  Iterative review-and-fix loop. Runs distinct review "hats" over a diff or branch,
  fixes what each round finds, repeats until a round comes up dry or the round cap
  hits. Hat composition is proposed per-change, not fixed. Use when user says
  "review loop", "review-fix loop", "run the triplets", "loop reviewers", "review
  until clean", or invokes /review-fix-loop. After the correctness loop goes dry, a
  terminal quality pass runs two simplification lenses plus a typing lens.
  Args: rounds=N, hats=a,b,c, agents=N, mode=inline|fanout, model=NAME, quality=off.
---

Review AND fix in one loop. Each round: run hats, verify findings, fix, re-verify, commit. Stop when a round finds nothing major, or cap hit.

Then one **quality pass** over the settled code: two simplification lenses and a typing lens. Correctness loop asks "is this wrong?". Quality pass asks "is this harder to read than it needs to be?". Both are required.

## Defaults

| Setting | Default | Override |
|---|---|---|
| rounds | 3 | `rounds=N` |
| hats | proposed per-change (see below) | `hats=a,b,c` |
| agents | 3 | `agents=N` |
| mode | fanout | `mode=inline` |
| model | inherit | `model=NAME` |
| stop | first dry round | cap is backstop only |
| quality pass | on, after loop goes dry | `quality=off` |

**Default mode is fanout: one agent per hat, in parallel.** Hats are independent by construction, so they parallelise cleanly, and keeping each hat's file-reading in its own context leaves the main thread free to judge findings instead of drowning in greps and diffs. Context pollution is the main cost of running hats inline.

Use `mode=inline` when the diff is small enough that spawning costs more than it saves, or when a hat needs conversation context an agent cannot be handed.

Either way: **a silent agent is NO SIGNAL, not a clean bill.** If one returns nothing, say so and either re-run it or cover that hat yourself. Never record an empty return as "found nothing". Agents also die for reasons unrelated to the code (machine sleeps, session ends); treat that as a lost round for that hat, not as a result.

## Propose the hats first

**Do not default to a fixed trio.** Read the diff, then propose a hat composition and say why. One line each. Let the user adjust before starting.

> Diff touches auth middleware + token refresh. Proposing 4 hats:
> 1. **security**: authz bypass, token lifetime, privilege boundaries
> 2. **security-crypto**: signing, comparison, randomness (second security hat: this is the blast radius)
> 3. **breakage**: runtime/deploy failure
> 4. **correctness**: does it do what the diff claims
>
> Say `hats=...` or `agents=N` to change it.

Scale the count to risk, not to diff size. A 3-line change to a shared credential path earns more hats than a 300-line rename.

**Weight hats toward the blast radius.** Two security hats on an auth change is normal. Give them different angles (protocol vs. implementation) so they do not collide.

### Hat catalogue

Starting points, not a menu limit. Invent hats that fit.

| Hat | Question it answers |
|---|---|
| `correctness` | does edited code do what the diff claims? target the line that LOOKS fixed but is not |
| `breakage` | will this fail at runtime after deploy, having passed locally and in CI? packaging, imports, scope, undefined vars |
| `adversarial` | attack shared/load-bearing code by EXECUTING it. both directions: bad input slipping through, good input mangled |
| `security` | authz, injection, secret handling, trust boundaries, privilege escalation |
| `data-integrity` | migrations, key changes, backfills. does a changed value reach storage or customer-visible output? |
| `perf` | added latency/allocation on a hot path, with a baseline, never bare "adds Nms" |
| `api-contract` | breaking changes for existing callers, response-shape drift |
| `concurrency` | races, shared mutable state, warm-container reuse, idempotency |
| `test-quality` | do the new tests PIN behavior, or just happen to pass? would they catch the bug they claim to |

Rule: hats must be **disjoint**. Overlap wastes the round. Tell each hat what the others cover and to ignore it.

**Every hat here answers "is this wrong?"** Readability, naming, duplication and weak typing are NOT hats. They run in the terminal quality pass below, on their own gate. Do not propose a `simplify`, `readability`, `naming` or `typing` hat for the loop: its findings would be non-major, so they cannot extend the loop, and putting them here gets them dropped. Tell each hat to ignore style and type shape.

## Loop

```
propose hats -> user confirms or adjusts
context = {fixed: [], refuted: [], out_of_scope: [], gotchas: []}
round = 1
while round <= cap:
    findings = run hats (inline or fanout), injecting context
    verify each finding yourself      # never act on an unverified claim
    for f in findings:
        if false: context.refuted += (f, why)      # record the reason
        if deferred: context.out_of_scope += (f, boundary)
    if no major findings: stop        # dry round = done
    fix the real ones -> context.fixed += them
    context.gotchas += anything learned that is not in the code
    re-verify: tests + compile + baseline diff
    commit round with what it found
    round += 1
```

**Stop on the dry round, not the cap.** Cap only guards runaway.

"Major" = wrong behavior, a leak, or a runtime break. Style, naming and type shape do not extend the loop. They are the quality pass's job, and it runs once at the end.

**When the loop stops, run the quality pass.** A dry round means the code is correct, not that it is done.

## Never fabricate a finding or a verification

The loop's output is only worth what its weakest claim is worth. A confident wrong finding costs more than a missed one, because it gets acted on.

- **Report only what you observed.** A finding needs a file you read or a command you ran. "This pattern usually means X" is not a finding.
- **Never invent a round's results.** If a hat produced nothing, say it produced nothing. If a fan-out agent went silent, that is NO SIGNAL. Never write up what it "would have found", and never let silence stand in for clean.
- **Never claim a verification you did not run.** No "tests pass" without the run. No "no regressions" without the baseline. If you skipped it, say which check you skipped.
- **Separate observed from inferred.** State plainly which findings you confirmed by reading/executing and which are suspicions worth a look. Both are useful; conflating them is not.
- **Do not pad a dry round.** Downgrading style nits into "findings" to make a round look productive corrupts the stop condition: the loop exists to end when the code is clean.
- **Uncertainty is a real answer.** "I could not determine whether this path is reachable" beats a guess in either direction.

## Carry context forward between rounds

Each round starts fresh reviewers who lack everything the loop has learned. Without a handoff they re-report fixed bugs, re-raise findings you already refuted, and burn the round. **Maintain a running context block and inject it into every subsequent round** (into agent prompts in fan-out; into your own framing inline).

Keep four lists:

1. **Fixed**: what earlier rounds already fixed. "Do not re-report these."
2. **Refuted, with the reason**: findings that looked real and were not. The reason matters more than the verdict: *"`paralegal_name` is a firm brand persona, not a person"*, *"L2L calls inside the account are trusted"*. Without the why, the next round rediscovers it and you re-adjudicate.
3. **Out of scope, with the boundary**: deliberate deferrals and why. Stops re-litigation of a decision already made.
4. **Gotchas**: domain facts learned mid-loop that are not in the code: real record shapes from the live datastore, which fields are customer-visible, what a suite's pre-existing failures are.

You have context reviewers do not: ticket scope, prior rounds, live data, the user's decisions. **Refuting a finding on that basis is correct and expected.** But refute explicitly and record it; do not silently drop it. A finding you ignore without a reason comes back every round.

Feed the block forward verbatim rather than summarising it away. The reason for each refutation is the load-bearing part.

## Quality pass (terminal, runs once)

The hats above hunt for **wrong**. This pass hunts for **worse than it could be**. Different question, different placement: it runs **once, after the correctness loop goes dry**: not per round. Simplifying code that round 3 rewrites anyway is wasted work, and taste findings must never extend the loop.

```
loop: correctness hats until dry (or cap)
  -> ONE quality pass: simplify-A + simplify-B + typing, in parallel
  -> converge, fix, verify, commit
  -> done
```

Skip it only if the user passed `quality=off`, or the loop never went dry (cap hit with real bugs still open). Fix those first: quality on churning code is premature.

**Quality findings never extend the loop.** They are fixed in their own commit and the loop ends. If a quality fix breaks a test, revert that fix and report it as proposed-not-applied. Do not open a new round, and do not debug it. See the guard band below.

### Three agents, in parallel

| Agent | Angle |
|---|---|
| `simplify-A` | shape and readability, biased toward **removing**: nesting, indirection, derivable state, dead code |
| `simplify-B` | shape and readability, biased toward **naming and locality**: does the code say what it is? is behavior where a reader looks for it? |
| `typing` | contract strength: can a reader know the shape of a value without running the code? |

Two simplify agents on purpose. Simplification is taste-loaded, and one agent's taste is not evidence. Give them **different priors** (above) so they do not collide, and do not tell either what the other is biased toward.

### The convergence gate

| Flagged by | Action |
|---|---|
| both simplify agents, same site | **fix it** |
| one simplify agent only | **propose it, do not edit**: report as suggestion with the diff |
| `typing` agent, naming a boundary crossing | **fix it**: see below |
| `typing` agent, no boundary named | propose only |
| a simplify agent AND `typing` | fix it, cross-lens agreement counts as convergence |

"Same site" means the same mechanism, not the same line number. Two agents flagging one function for the same underlying reason converge even if they cite different lines. Two agents flagging the same line for unrelated reasons do **not**.

**Contested sites are a finding.** When the two simplify agents flag the same site and propose **opposite** fixes (A says extract, B says inline), do not pick and do not drop. Surface it: `contested: <site>, A wants X, B wants Y`. That disagreement is real information about the code, and the call is the user's.

### What simplification means

Not "less code". Usually less code, but that is a side effect, not the target.

The target: **a reader who must understand this code needs less time.** Everything below serves that.

- Code is less clever, more direct. The obvious reading is the correct reading.
- Names say what things are. A name that needs a comment to be understood is the finding.
- Class and function interfaces are graspable without reading the implementation.
- Locality of behavior is respected. Behavior lives where a reader looks for it, not three files away.
- Code is indicative: its shape tells you its purpose.

**Simplification is not free, and the cost is not always performance.** A finding must name what it trades away. Legitimate prices, all of them:

| Price paid | When it is worth paying |
|---|---|
| **CPU cycles / allocations** | the path is not hot, and the clear version is obviously clear. State the baseline. `/simplify`'s efficiency angle would flag this, and it is overruled on purpose |
| **Modularity** | two pieces are always read together and never reused apart. Merging them is locality, not coupling |
| **Duplication** | the two sites look alike by coincidence, not shared knowledge. Extracting would couple them and force the reader to leave the code |
| **Some other readability** | a longer function that reads top-to-bottom beats five small ones you must jump between. Rare, but real |

A finding that claims a free win is suspect. Re-read it. Genuinely free wins exist (dead code, redundant state) but most are trades.

**The reverse direction is also a finding.** Code that pays a price and gets nothing is complexity without purchase: an abstraction with one caller, a helper that only forwards, indirection with no second implementation. Flag it.

### What the typing angle means

The principle, any language: **a value that crosses a boundary with an untyped shape is a finding.** Boundary = function signature, module edge, service call, storage write, anything a reader must trace through.

An untyped bag is worse than it looks. `dict` in, `dict` out, nested three deep, and understanding the code means executing it in your head to learn what keys exist. No definition to open, no symbol to grep. The type is real but written nowhere.

Same defect at smaller scale: a primitive standing in for a value with a grammar. `dict` hides which keys exist; `str` hides which grammar the characters follow. Both are a real type written nowhere.

Flag, in rough order of severity:

1. **Untyped bag crossing a boundary**: dict/map/object with no named shape, passed between functions or across a module edge
2. **Nested untyped bags**: a bag whose values are bags. Severity compounds with depth
3. **Date or time carried as a bare `str`**: the annotation says `str`, so the grammar is unstated. Epoch seconds, epoch millis, ISO 8601, offset-aware or naive? Parse to a real `datetime`/`date` at the edge, or name the string type (see the ladder). This one buys correctness, not only clarity: string datetimes sort and compare wrong across formats, and `"2026-08-18"` vs `"2026-08-18T00:00:00Z"` orders by accident. Applies to any primitive standing in for a value with a grammar, dates being the common case: also durations, money as `float`, and IDs whose format is load-bearing
4. **Escape-hatch types where a concrete type is knowable**: `Any`, `any`, `interface{}`, `object`
5. **Unvalidated shape at a trust boundary**: external JSON, HTTP body, cross-service payload accepted without a validating parse
6. **Missing hints on a new signature**: only when the type is genuinely knowable
7. **A name that lies about its type**: `id` holding an object, `count` holding a list

Python ladder, strongest contract first. Pick by contract needed, not by habit:

| Reach for | When |
|---|---|
| pydantic `BaseModel` | untrusted input crossing a trust boundary: HTTP body, cross-service payload. Buys runtime validation and coercion. Costs a dependency and parse time |
| `@dataclass` | trusted internal value object. Attribute access, free `__eq__`/`__repr__`. `frozen=True` when it must not mutate |
| `t.NamedTuple` | small immutable value you would otherwise make a 2-3 element tuple. Unpacking is a feature |
| `t.TypedDict` | must stay a dict at runtime (forwarded to an API expecting dict, JSON-serialized, Lambda event). Static checks, zero runtime cost |
| `t.NewType` alias | the value must stay a primitive at runtime (DynamoDB sort key, wire format, byte-derived id) but its grammar is unstated. `IsoTimestamp = t.NewType("IsoTimestamp", str)`. Zero runtime change, and every use site becomes greppable. The safe rung for strings, as `TypedDict` is for dicts |
| `dict[str, Any]` + docstring | genuinely ad-hoc or heterogeneous shape |

Other languages: same principle, their own idiom. TypeScript: `interface`/`type` over inline object literals, `unknown` + narrowing over `any`, a validating parse (zod or equivalent) at the API edge over an `as` cast. Go: a struct over `map[string]interface{}`. For date and time in any language, prefer the standard library type over a string. Read what the file already does and match it.

**Document the fields that lie.** Non-obvious field knowledge goes in the **class docstring**, not a trailing `#` comment. Docstrings reach LSP hover, `help()`, and generated docs; comments reach none of them. Only document fields whose names hide something: an opaque ID behind a human-sounding name, a value mutated outside this code path, a field that doubles as a key seed. `share_id: str` needs nothing.

### Typing restraint

Types are a readability tool here, not a compliance target. The gate is the same question: **does a reader understand this faster?** Do not flag:

- A local variable whose type is obvious from the line above
- A file with no hints anywhere. Respect the existing style until the file is modernised on purpose
- Anything outside the diff. Untyped code the diff merely touches is pre-existing; note it, do not retrofit
- A dict that stays inside one short function and never crosses a boundary
- Introducing pydantic to a service that does not already depend on it. Propose that, do not do it. Same for `shared/`: CLAUDE.md forbids new deps there outright
- A datetime string the code only passes through and never compares, sorts or formats. Parsing a value nothing reasons about adds a failure mode and buys nothing
- A datetime string that must stay a string at the storage or wire edge. Do not fight the format, name it with a `NewType` alias instead

### Reuse and altitude

Two more angles, distributed across the simplify agents (`simplify-A` takes reuse, `simplify-B` takes altitude):

**Reuse**: flag new code that re-implements something the codebase already has. Grep shared and utility modules before calling it new. Weigh against the duplication line above: a real shared-knowledge duplicate is a finding, a coincidental look-alike is not.

**Altitude**: check each change sits at the right depth, not as a fragile bandaid. Special cases layered on shared infrastructure signal the fix is too shallow. Prefer generalizing the underlying mechanism over adding special cases.

### Applying quality fixes

- **Behavior must not change.** A quality fix that alters behavior is out of scope. Skip it and say so.
- **Verify against the same baseline** the correctness rounds used. Tests, compile, lint.
- **Read every line of a scripted rewrite.** Renames and reshapes over-reach. This is where quality passes cause outages.
- **Commit separately** from correctness rounds, so a revert is surgical.
- **Report what you proposed but did not apply**: single-agent findings and contested sites. That list is the pass's real output as much as the diff is.
- Skip any fix that reaches well outside the diff, and note the skip rather than arguing with it.

### Guard band (the pass checks its own work)

Quality fixes are behavior-preserving by construction. "By construction" is not a verification. Run **one** correctness check scoped to what this pass touched, not another loop.

Why not a loop: the correctness loop iterates because fixes to load-bearing code cause new bugs, an open-ended cycle. Quality fixes intend no behavior change, so any behavior change they cause lives in the lines they rewrote. Bounded risk, targeted check.

After applying, one agent (or you, inline) re-reads **only the lines this pass changed** and answers one question: **does anything here behave differently?** Not "is it simpler": that was the last pass's job.

Feed it the quality diff, the pre-quality state, and the trades each finding declared. It has one job and no licence to hunt for pre-existing bugs.

- Something behaves differently → **revert that fix**. Do not repair it. A quality fix that needs debugging has already failed its own premise. Report it as proposed-not-applied.
- Nothing differs → done. Report and stop.

**The typing angle carries almost all this risk, and it is not theoretical.** A `dict` → model swap, or a `str` → `datetime` parse, changes behavior in ways that read as a refactor:

| Rewrite | Silent behavior change |
|---|---|
| `d.get("x")` → `model.x` | missing key was `None`, now raises `AttributeError` |
| `dict` → pydantic `BaseModel` | pydantic **coerces**: `"5"` becomes `5`, `"true"` becomes `True`. Downstream `is`/type checks flip |
| `dict` → pydantic `BaseModel` | extra keys pass through a dict, get dropped or rejected by a model depending on config |
| `dict` → `@dataclass` | dict was mutated in place somewhere; the dataclass is a different object and the mutation is lost |
| adding a required field | a caller that omitted it worked before, raises now |
| `Any` → concrete type | tightens a static check only, but a checker error is a build break |
| `str` → `datetime` | a string that never raised now raises on any row whose format differs. Legacy rows rarely all match |
| `str` → `datetime` | naive/aware mismatch: comparing an aware value to a naive one raises `TypeError` at runtime, not at parse |
| `str` → `datetime` | a value written straight back to storage or a response body now serializes differently. `str(dt)` is not the input string |

Treat every dict-to-model swap and every string-to-datetime parse as **behavior-changing until proven otherwise**. Prove it by finding every construction site and every read site, or do not apply it. Propose it instead. `TypedDict` and `NewType` are the safe rungs of the ladder precisely because they are zero runtime change; prefer them when the only goal is naming the shape.

For a datetime parse specifically, proving it means three things: the parse handles every format present in real stored data, not only the format the happy path writes; nothing downstream compares the value against a naive datetime; and no write path or response body carries the value back out unchanged. Cannot show all three, propose it.

Same trap in the simplify angles, smaller: short-circuit order (`and`/`or` reordering changes what gets evaluated), truthiness (`if x` is not `if x is not None`: `0` and `""` diverge), and generator-to-list changes when the consumer iterates twice.

## Rules that make it work

- **Verify before acting.** Reviewer claims (bot, human, agent) are leads, not facts. Read the code. Where cheap, execute it.
- **Keep the fan-out's context benefit.** Ask hats for findings, not transcripts. A hat that pastes back the files it read defeats the point. Verify by re-reading the specific lines a finding names, not by re-running its whole search.
- **Execute over read.** For shared helpers, write throwaway scripts hitting edge cases. Most real bugs surface from inputs you were NOT targeting.
- **Check the blast radius before changing a value.** A field feeding a log may also be a dict key, a filename, or customer-visible text. Grep consumers before swapping it. A "log-only" change that alters an invoice is worse than the leak.
- **A log line must never raise.** Prefer `.get()` over subscript for anything newly referenced in logging.
- **Watch for fix-induced bugs.** A fix to load-bearing code frequently introduces a new bug its own test does not catch. Each round, re-attack what the previous round changed.
- **Test both directions.** Not just "is the bad thing caught" but "does the good thing survive". Over-correction is a real defect, just quieter.
- **Baseline before blaming.** Failing tests may predate the branch. Run the same suite on the base ref in a scratch worktree before calling it a regression.
- **Sweep, don't spot-fix.** A reviewer names 2 instances; find all N. The bug class usually recurs.
- **Bulk edits need a diff review.** After any scripted rewrite, read every changed line. Scripts over-reach.
- **Commit per round**, message saying what that round found.

## Reporting

Per round:
- what each hat found (or that it found nothing)
- what you verified by reading/executing vs. what is still a suspicion
- what you refuted and **why**: the reason is the useful part
- what you fixed, what you deferred and why
- test/compile state vs. baseline, naming any check you skipped

Quality pass:
- what each of the three agents found
- what converged (two agents, one site) and got fixed
- what one agent flagged alone, reported as a proposal, not applied
- contested sites, both proposals stated, left for the user
- guard-band result: whether any quality fix changed behavior, and what you reverted
- typing findings you proposed rather than applied, and why (new dependency, construction sites you could not enumerate)

At the end: rounds run, why you stopped (dry vs. cap), whether the quality pass ran, what remains open.

Be straight about a hat that produced nothing. "Round 3 dry" is a real result. Do not pad it.

Surface any hat that returned nothing, and say whether it found nothing or never reported. Those are different results. A hat that died mid-round leaves that angle uncovered. Re-run it or cover it yourself before calling the round dry, because an empty return reads as assurance when it is absence.
