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
| mode | inline | `mode=fanout` |
| model | inherit | `model=NAME` |
| stop | first dry round | cap is backstop only |

**Default mode is inline — run each hat yourself, sequentially.** Fan-out is opt-in because subagent review has a poor track record: agents frequently idle without returning findings, and a silent agent reads as "clean" when it means "no signal". Inline costs wall-clock but always produces output.

Use `mode=fanout` when the surface genuinely exceeds one context (30+ files, or hats needing separate repos). Then treat silence as NO SIGNAL, never as clean, and verify every returned claim before acting.

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
round = 1
while round <= cap:
    findings = run hats (inline or fanout)
    verify each finding yourself      # never act on an unverified claim
    if no major findings: stop        # dry round = done
    fix them
    re-verify: tests + compile + baseline diff
    commit round with what it found
    round += 1
```

**Stop on the dry round, not the cap.** Cap only guards runaway.

"Major" = wrong behavior, a leak, or a runtime break. Style and naming do not extend the loop.

## Rules that make it work

- **Verify before acting.** Reviewer claims (bot, human, agent) are leads, not facts. Read the code. Where cheap, execute it.
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
- what you verified vs. took on trust
- what you fixed, what you deferred and why
- test/compile state vs. baseline

At the end: rounds run, why you stopped (dry vs. cap), what remains open.

Be straight about a hat that produced nothing. "Round 3 dry" is a real result. Do not pad it.
