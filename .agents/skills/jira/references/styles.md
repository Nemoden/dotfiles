# Ticket styles

Six body styles. Each is a fixed set of bold lead-in labels, in order. Pick one per ticket (rules in SKILL.md, "Ticket styles"). Titles follow "Title calibration" in SKILL.md whatever the style.

## Voice shared by every style

- Bold lead-in label, then the content on the same line: `**Why:** ...`. No headings inside short bodies.
- Terse. Drop articles and filler. One idea per sentence. Fragments fine.
- Define a term the first time it appears, before it carries weight (see **mechanics**: "Lost answer:" comes first).
- Name code by function or type, never by line number or local path.
- `Done when` is a check a reviewer can run or observe, never "works" or "is fixed".
- No section for its own sake. A label with nothing true to say is dropped.

## Pick by what the reader must do

| Style | Reader must... | Labels, in order | Size |
|---|---|---|---|
| **nano** | know what and why, nothing more | What, Why | 2 to 4 lines |
| **brief** | do a small, obvious fix | What, Why, Do, Done when | 5 to 10 lines |
| **mechanics** | fix a defect whose cause is a chain of events | (term), What happens, Why a plain fix fails, Fix, Done when | 10 to 25 lines |
| **options** | choose among fixes nobody has chosen yet | Problem, Why it hurts, Why it exists, Possible fixes, Done when | 12 to 25 lines |
| **audit** | check a set of places, fix the bad ones | What, Why, Do, Done when | 6 to 12 lines |
| **full** | pick up large or cross-team work cold | rich ADF: context, decisions, code excerpts, Sources, green acceptance panel | as needed |

Signals:
- User says "super concise", "really short", "just what and why" → **nano**.
- Known wish or escape hatch, scope obvious from the title → **nano**.
- A **nano** candidate with an open decision the assignee must not make alone → **brief**, the decision in `Do`.
- Small bug, chore, text fix, config line → **brief**.
- Race, retry, lost write, ordering, cache, "only happens when..." → **mechanics**.
- User lists possible approaches, or says "explain possible solutions" → **options**.
- "Check every X for Y", compliance sweep, PII in logs → **audit**.
- Epic-sized, needs evidence links or code excerpts, reader has no context → **full**.

## nano

```
**What:** <the change, one or two sentences, current behaviour named>

**Why:** <who hits what today, and what it costs them>
```

Example:

```
**What:** Cancel available while an export is copying files. Today the copying state goes only to done or failed.

**Why:** escape hatch. Person spots a mistake after Start, wants to cancel and start again. Today must wait for the copy to end, or up to the 2 h watchdog when the upstream stays slow.
```

## brief

```
**What:** <observed behaviour, where>

**Why:** <cost to the reader or user>

**Do:** <the fix, as a decision, not steps>

**Done when:** <observable check>
```

Example:

```
**What:** the order list shows "Reload to see your order" on a 500, also when no order was placed.

**Why:** the text sends the person looking for an order that does not exist.

**Do:** show that text only when an order create was sent; else a plain "could not load, try again" line.

**Done when:** a client test covers both cases.
```

## mechanics

Lead with the term the chain depends on, defined in plain words. Then the chain, cause to effect. Then why the obvious fix is wrong, when a reader would try it. Then the fix.

```
**<Term>:** <plain definition of the event the defect needs>

**What happens:** <step by step: action, what the code reads, wrong conclusion, lasting effect, the way out today>

**Why a plain fix is not enough:** <the naive fix and the new failure it causes>   (drop if no naive fix tempts)

**Fix:** <the pattern, and where the codebase already uses it>

**Done when:** <test that reproduces the event and shows the right end state>
```

Example:

```
**Lost answer:** storage applies a write, but its reply never reaches the caller (network drop, timeout). The SDK resends the same request. For a conditional write (If-None-Match), the resend meets the object the first send made, and storage answers 412. Code reads that 412 as someone else's write.

**What happens:** Start writes the plan with If-None-Match, then moves the job to running. On a lost answer the resend gets 412; `commit_plan` answers 409 and keeps the object. Only Start deletes the plan, so every later Start answers 409. Job never starts. Way out today: cancel and create a new job.

**Why a plain compare is not enough:** two parallel Starts build equal plans. Treat "equal plan" as own write, and the losing Start deletes the winner's plan.

**Fix:** put a Start token in the plan. On 412 read it back: own token means own write. State moves already use this pattern (`transition` carries a write token).

**Done when:** a test with a landed write and a dropped answer moves the job to running; two parallel Starts still end with one plan.
```

## options

```
**Problem:** <what happens, with the measured cost if you have it>

**Why it hurts:** <consequence, and when it gets worse>

**Why it exists:** <the root cause in one or two sentences>

**Possible fixes (pick one or combine):**
- <option>: <what it changes>
- <option>: <what it changes>

**Done when:** <the target property>; the choice between the options is recorded.
```

Example:

```
**Problem:** 8 worker threads share one token holder behind one lock. When the token expires while the vault answers busy, each thread in turn mints (two calls, 5 s wait) and fails. Probe: 16 vault calls, about 40 s, all under the lock.

**Why it hurts:** near the 900 s limit the save misses its deadline; the retry loses up to 30 s of work. Several jobs for one tenant share one vault, so pressure multiplies.

**Why it exists:** a failed mint records nothing, so the next thread tries again.

**Possible fixes (pick one or combine):**
- Latch: after one busy answer, later reads in the same worker fail at once.
- Limit concurrent jobs per tenant.
- Round robin over the tenant's other credentials instead of one token.

**Done when:** a busy vault costs one mint attempt per worker, not one per thread; the choice is recorded.
```

## audit

```
**What:** <the risk and the set of places it can live>

**Why:** <the rule it breaks, and why the risk is real here>

**Do:** <the sweep scope, and the fix for a bad place>

**Done when:** each place is listed with "<safe verdict>" or fixed; a test pins one fixed case.
```

## full

The skill's rich default: ADF body, context and decisions, code excerpts, a Sources section, a green success panel for acceptance criteria. Follow "Content rules", "Refs / Sources section", "Code excerpts" and "Ticket calibration" in SKILL.md, and the ADF patterns in `references/adf.md`.
