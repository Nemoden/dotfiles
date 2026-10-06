# Ticket body: blocks, density, presets

A ticket body is a set of **blocks** written at one **density**. A **preset** is a named block set, so nobody picks blocks one by one. The skill proposes preset + density + changes in one line per ticket; the user edits or stays silent (silence = yes).

Titles follow "Title calibration" in SKILL.md whatever the body.

## Voice shared by every block

- Bold lead-in label, then the content on the same line: `**Why:** ...`. Labels exactly as in the catalogue.
- Terse. Drop articles and filler. One idea per sentence. Fragments fine.
- Name code by function or type, never by line number or local path.
- A block with nothing true to say is dropped, even when its preset lists it, unless its content is needed for the hard floor (SKILL.md). **What** and **Why** are never dropped, at any density.
- Every word that is neither plain English nor a searchable name in the repo is defined at first use, at any density: as a **Term** block, or as a clause inside the sentence that uses it.

## Block catalogue

Blocks always appear in this order, whichever are present. A reader finds **Workaround today** in the same place in every ticket.

| # | Label | Include when | Content |
|---|---|---|---|
| 1 | **\<Term\>:** | the story depends on a word the reader may not know | plain definition of that word, before it carries weight. The label is the term itself (`**Lost answer:**`) |
| 2 | **What:** | always | the target end state and the current behaviour, anchored: product area plus one searchable starting point (function, type, route, state or screen) |
| 3 | **Why:** | always | who hits what, and what it costs them |
| 4 | **Background:** | history explains the current shape | how it got this way, one or two facts, no session story |
| 5 | **What happens:** | the cause is a chain of events | cause to effect, step by step: action, what the code reads, wrong conclusion, lasting effect |
| 6 | **Root cause:** | the cause is known and the chain does not show it | one or two sentences |
| 7 | **If not done:** | the cost of waiting is not obvious | what gets worse, and when |
| 8 | **Workaround today:** | a person has a way out now | the way out, and its cost |
| 9 | **Tempting fix that fails:** | a reader would try an obvious fix that breaks | the fix, and the new failure it causes |
| 10 | **Options:** | the fix is not chosen yet | bullets, `<option>: <what it changes>`; say "pick one or combine" when both work |
| 11 | **Strategy:** | phase order matters | ordered phases: audit before delete, migrate before remove |
| 12 | **Fix:** | the fix is chosen | the decision and the pattern, where the codebase already uses it. Never steps an agent would find alone |
| 13 | **Out of scope:** | a reader would assume it is in scope | the item, and where it goes instead |
| 14 | **Risks:** | the change can break something or cannot be undone | the risk, and the rollback or guard |
| 15 | **Open questions:** | a decision the assignee must not make alone | the question, and who answers it |
| 16 | **Done when:** | always; at nano it folds into **What** as an observable end state | a check a reviewer can run or observe, never "works" |
| 17 | **Evidence:** | a probe, a log or a measurement backs a claim | what ran, and the output that matters; timestamp or request id if the source ages out |
| 18 | **Code:** | real code says it better than prose | one small real excerpt, original comments kept, cited by function name |
| 19 | **References:** | tickets, PRs, docs, dashboards support the body | one per line, each with what it shows |

## Density

| Density | Length per block | Format |
|---|---|---|
| **nano** | one line | markdown; no Done when label, the end state sits in What |
| **brief** | one to four lines | markdown |
| **full** | paragraphs where needed | rich ADF; Done when as the green success panel (`references/adf.md`); Evidence, Code and References follow "Refs / Sources section" and "Code excerpts" in SKILL.md |

Overload rule: **brief** with more than 7 blocks is really **full**. Say so, and propose **full** or a split into two tickets.

## Presets

| Preset | Blocks | Signals |
|---|---|---|
| **wish** | What, Why | feature wish, escape hatch, scope obvious from the title |
| **bug** | What, Why, Fix, Done when | small bug, chore, text fix, config line |
| **chain bug** | Term, What, What happens, Workaround today, Tempting fix that fails, Fix, Done when | race, retry, lost write, ordering, cache, "only happens when" |
| **decision** | What, Why, Root cause, If not done, Options, Done when | the user lists approaches, or says "explain possible solutions" |
| **audit** | What, Why, Strategy, Fix, Done when | "check every X for Y", compliance sweep, PII in logs |
| **epic** | every block whose "include when" holds | large or cross-team work, reader has no context |

Default density per preset: **wish** nano, **epic** full, the rest brief. The user's words win: "super concise" means nano, "full write-up" means full, whatever the preset.

## The proposal line

One line per ticket, before any create call:

```
<title or key>: <preset> · <density> · <+block> <-block>
```

- `+` adds a catalogue block whose "include when" holds for this ticket; `-` drops a preset block that has nothing true to say. A `-` never removes floor content: if the user drops a block that carries it, move that content into **What**.
- Several tickets: one line each, in the same pre-create summary as labels and sprint.
- The user answers in the same words: "nano, add What happens", "drop Options". Recompose and go on. Ask nothing per block.

## Examples

**wish · nano**

```
**What:** export jobs: Cancel shows in the `copying` state, and the copy worker stops at its next file. Today `copying` goes only to `done` or `failed`.

**Why:** escape hatch. Person spots a mistake after Start, wants to cancel and start again. Today must wait for the copy to end, or up to the 2 h watchdog when the upstream stays slow.
```

**wish · nano · +Open questions** (an open decision turns a silent wish into one the assignee cannot finish alone)

```
**What:** Admin can cancel a CSV import while it runs. Today a started import ends only as done or failed.

**Why:** admin spots a wrong file after start; today must wait for the end.

**Open questions:** rows already written on cancel: keep or roll back? Product owner answers.
```

**chain bug · brief · -Workaround today**

```
**Lost answer:** storage applies a write, but its reply never reaches the caller (timeout). The SDK resends the same request. For a conditional write (If-None-Match), the resend meets the object the first send made, and storage answers 412. Code reads that 412 as someone else's write.

**What:** every later Start of a job answers 409 after one lost answer on the plan write.

**What happens:** Start writes the plan with If-None-Match, then moves the job to running. The resend gets 412; `commit_plan` answers 409 and keeps the object. Only Start deletes the plan, so every later Start meets it. Job never starts.

**Tempting fix that fails:** treat "stored plan equals mine" as own write. Two parallel Starts build equal plans, and the loser deletes the winner's plan.

**Fix:** put a Start token in the plan. On 412 read it back: own token means own write. State moves already use this pattern (`transition` carries a write token).

**Done when:** a test with a landed write and a dropped answer moves the job to running; two parallel Starts still end with one plan.
```

**decision · brief**

```
**What:** 8 worker threads share one token holder behind one lock. When the token expires while the vault answers busy, each thread in turn mints (two calls, 5 s wait) and fails: 16 vault calls, about 40 s, all under the lock.

**Why:** 16 calls land on a vault already busy; several jobs for one tenant multiply it.

**Root cause:** a failed mint records nothing, so the next thread tries again.

**If not done:** near the 900 s limit the save misses its deadline; the retry loses up to 30 s of work.

**Options:** pick one or combine.
- Latch: after one busy answer, later reads in the same worker fail at once.
- Limit concurrent jobs per tenant.
- Round robin over the tenant's other credentials.

**Done when:** a busy vault costs one mint attempt per worker, not one per thread; the choice is recorded.
```

## Cold read

Dispatch one fresh subagent per batch of drafts, cheapest capable model, with repo access and nothing from the session. Paste the drafts after this prompt:

```
You read Jira ticket drafts as the agent who will pick them up. You have the repo
and these drafts only. Read each draft on its own; ignore the others.

Per ticket, return:
- Restate: where (area + starting point), what (end state), why, done, in your words.
- Guessed: each point where you chose between readings; name the readings.
- Not found: each point you could not settle from the draft plus a repo search.
- Derivable: each sentence you would have found yourself in the repo.

Do not suggest wording. Do not fix the draft. Report only.
```

Act on the reply as SKILL.md says ("Cold read"): fix a wrong restatement; settle a **Guessed** point only when its readings lead to different work; add a **Not found** point only when it is a decision the assignee must not make alone; cut **Derivable** unless pivotal.
