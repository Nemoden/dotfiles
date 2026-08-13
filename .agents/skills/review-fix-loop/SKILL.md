---
name: review-fix-loop
description: >
  Iterative review-and-fix loop. Runs distinct review "hats" over a diff or branch,
  fixes what each round finds, repeats until a round comes up dry or the round cap
  hits. Hat composition is proposed per-change, not fixed. Use when user says
  "review loop", "review-fix loop", "run the triplets", "loop reviewers", "review
  until clean", or invokes /review-fix-loop. Args: rounds=N, hats=a,b,c, agents=N,
  mode=inline|fanout, model=NAME.
---

Review AND fix in one loop. Each round: run hats, verify findings, fix, re-verify, commit. Stop when a round finds nothing major, or cap hit.

## Defaults

| Setting | Default | Override |
|---|---|---|
| rounds | 3 | `rounds=N` |
| hats | proposed per-change (see below) | `hats=a,b,c` |
| agents | 3 | `agents=N` |
| mode | fanout | `mode=inline` |
| model | inherit | `model=NAME` |
| stop | first dry round | cap is backstop only |

**Default mode is fanout — one agent per hat, in parallel.** Hats are independent by construction, so they parallelise cleanly, and keeping each hat's file-reading in its own context leaves the main thread free to judge findings instead of drowning in greps and diffs. Context pollution is the main cost of running hats inline.

Use `mode=inline` when the diff is small enough that spawning costs more than it saves, or when a hat needs conversation context an agent cannot be handed.

Either way: **a silent agent is NO SIGNAL, not a clean bill.** If one returns nothing, say so and either re-run it or cover that hat yourself — never record an empty return as "found nothing". Agents also die for reasons unrelated to the code (machine sleeps, session ends); treat that as a lost round for that hat, not as a result.

## Propose the hats first

**Do not default to a fixed trio.** Read the diff, then propose a hat composition and say why. One line each. Let the user adjust before starting.

> Diff touches auth middleware + token refresh. Proposing 4 hats:
> 1. **security** — authz bypass, token lifetime, privilege boundaries
> 2. **security-crypto** — signing, comparison, randomness (second security hat: this is the blast radius)
> 3. **breakage** — runtime/deploy failure
> 4. **correctness** — does it do what the diff claims
>
> Say `hats=...` or `agents=N` to change it.

Scale the count to risk, not to diff size. A 3-line change to a shared credential path earns more hats than a 300-line rename.

**Weight hats toward the blast radius.** Two security hats on an auth change is normal — give them different angles (protocol vs. implementation) so they do not collide.

### Hat catalogue

Starting points, not a menu limit. Invent hats that fit.

| Hat | Question it answers |
|---|---|
| `correctness` | does edited code do what the diff claims? target the line that LOOKS fixed but is not |
| `breakage` | will this fail at runtime after deploy, having passed locally and in CI? packaging, imports, scope, undefined vars |
| `adversarial` | attack shared/load-bearing code by EXECUTING it. both directions: bad input slipping through, good input mangled |
| `security` | authz, injection, secret handling, trust boundaries, privilege escalation |
| `data-integrity` | migrations, key changes, backfills. does a changed value reach storage or customer-visible output? |
| `perf` | added latency/allocation on a hot path — with a baseline, never bare "adds Nms" |
| `api-contract` | breaking changes for existing callers, response-shape drift |
| `concurrency` | races, shared mutable state, warm-container reuse, idempotency |
| `test-quality` | do the new tests PIN behavior, or just happen to pass? would they catch the bug they claim to |

Rule: hats must be **disjoint**. Overlap wastes the round. Tell each hat what the others cover and to ignore it.

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

"Major" = wrong behavior, a leak, or a runtime break. Style and naming do not extend the loop.

## Never fabricate a finding or a verification

The loop's output is only worth what its weakest claim is worth. A confident wrong finding costs more than a missed one, because it gets acted on.

- **Report only what you observed.** A finding needs a file you read or a command you ran. "This pattern usually means X" is not a finding.
- **Never invent a round's results.** If a hat produced nothing, say it produced nothing. If a fan-out agent went silent, that is NO SIGNAL — never write up what it "would have found", and never let silence stand in for clean.
- **Never claim a verification you did not run.** No "tests pass" without the run. No "no regressions" without the baseline. If you skipped it, say which check you skipped.
- **Separate observed from inferred.** State plainly which findings you confirmed by reading/executing and which are suspicions worth a look. Both are useful; conflating them is not.
- **Do not pad a dry round.** Downgrading style nits into "findings" to make a round look productive corrupts the stop condition — the loop exists to end when the code is clean.
- **Uncertainty is a real answer.** "I could not determine whether this path is reachable" beats a guess in either direction.

## Carry context forward between rounds

Each round starts fresh reviewers who lack everything the loop has learned. Without a handoff they re-report fixed bugs, re-raise findings you already refuted, and burn the round. **Maintain a running context block and inject it into every subsequent round** (into agent prompts in fan-out; into your own framing inline).

Keep four lists:

1. **Fixed** — what earlier rounds already fixed. "Do not re-report these."
2. **Refuted, with the reason** — findings that looked real and were not. The reason matters more than the verdict: *"`paralegal_name` is a firm brand persona, not a person"*, *"L2L calls inside the account are trusted"*. Without the why, the next round rediscovers it and you re-adjudicate.
3. **Out of scope, with the boundary** — deliberate deferrals and why. Stops re-litigation of a decision already made.
4. **Gotchas** — domain facts learned mid-loop that are not in the code: real record shapes from the live datastore, which fields are customer-visible, what a suite's pre-existing failures are.

You have context reviewers do not — ticket scope, prior rounds, live data, the user's decisions. **Refuting a finding on that basis is correct and expected.** But refute explicitly and record it; do not silently drop it. A finding you ignore without a reason comes back every round.

Feed the block forward verbatim rather than summarising it away — the reason for each refutation is the load-bearing part.

## Rules that make it work

- **Verify before acting.** Reviewer claims (bot, human, agent) are leads, not facts. Read the code. Where cheap, execute it.
- **Keep the fan-out's context benefit.** Ask hats for findings, not transcripts — a hat that pastes back the files it read defeats the point. Verify by re-reading the specific lines a finding names, not by re-running its whole search.
- **Execute over read.** For shared helpers, write throwaway scripts hitting edge cases. Most real bugs surface from inputs you were NOT targeting.
- **Check the blast radius before changing a value.** A field feeding a log may also be a dict key, a filename, or customer-visible text. Grep consumers before swapping it — a "log-only" change that alters an invoice is worse than the leak.
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
- what you refuted and **why** — the reason is the useful part
- what you fixed, what you deferred and why
- test/compile state vs. baseline, naming any check you skipped

At the end: rounds run, why you stopped (dry vs. cap), what remains open.

Be straight about a hat that produced nothing. "Round 3 dry" is a real result. Do not pad it.

Surface any hat that returned nothing, and say whether it found nothing or never reported. Those are different results. A hat that died mid-round leaves that angle uncovered — re-run it or cover it yourself before calling the round dry, because an empty return reads as assurance when it is absence.
