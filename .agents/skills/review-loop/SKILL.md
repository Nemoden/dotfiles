---
name: review-loop
description: >
  Iterative multi-hat code review loop. Runs distinct review "hats" over a diff or
  branch, fixes what each round finds, repeats until a round comes up dry or the
  round cap hits. Use when user says "review loop", "run the triplets", "loop
  reviewers", "review until clean", or invokes /review-loop. Args: rounds=N,
  mode=inline|fanout, model=NAME, hats=a,b,c.
---

Iterative review. Each round: run hats, fix findings, re-verify. Stop when round finds nothing major, or cap hit.

## Defaults

| Setting | Default | Override |
|---|---|---|
| rounds | 3 | `rounds=N` |
| mode | inline | `mode=fanout` |
| model | inherit | `model=NAME` |
| hats | correctness, breakage, adversarial | `hats=a,b,c` |
| stop | first dry round | cap is backstop only |

**Default mode is inline — you run each hat yourself, sequentially.** Fan-out is opt-in because subagent review has a poor track record: agents frequently idle without returning findings, and a silent agent reads as "clean" when it means "no signal". Inline costs wall-clock but always produces output.

Use `mode=fanout` when the surface is genuinely too big for one context (30+ files, or hats needing different repos). Then treat silence as NO SIGNAL, never as clean, and verify every returned claim before acting.

## The hats

Three by default. Each gets a narrow question and is told to ignore what the others cover — overlap wastes the round.

1. **correctness** — does edited code still do what the diff claims? Target the line that LOOKS fixed but is not. Trace runtime types, not names.
2. **breakage** — will this fail at runtime after deploy, having passed locally and in CI? Packaging, imports, scope, undefined vars, exceptions from new code.
3. **adversarial** — attack shared/load-bearing code by EXECUTING it, not reading it. Both directions: does bad input slip through, and does good input get mangled.

Swap hats to fit the work: `hats=security,perf,api-contract`. Keep them disjoint.

## Loop

```
round = 1
while round <= cap:
    findings = run hats (inline or fanout)
    verify each finding yourself      # never act on an unverified claim
    if no major findings: stop        # dry round = done
    fix them
    re-verify: tests + compile + baseline diff
    commit round
    round += 1
```

**Stop on the dry round, not the cap.** Cap only guards runaway.

A "major" finding = wrong behavior, a leak, or a runtime break. Style and naming do not extend the loop.

## Rules that make it work

- **Verify before acting.** Reviewer claims (bot, human, agent) are leads, not facts. Read the code. Where cheap, execute it.
- **Execute over read.** For shared helpers, write throwaway scripts hitting edge cases. In practice most real bugs surface from inputs you were NOT targeting.
- **Watch for fix-induced bugs.** A fix to load-bearing code frequently introduces a new bug its own test does not catch. Each round, re-attack what the previous round changed.
- **Test both directions.** Not just "does the bad thing get caught" but "does the good thing survive". Over-correction is a real defect, just quieter.
- **Baseline before blaming.** Failing tests may predate the branch. Check the same suite on the base ref in a scratch worktree before calling it a regression.
- **Sweep, don't spot-fix.** A reviewer names 2 instances; find all N. Same bug class usually recurs.
- **Widen after each fix.** Fixing one instance teaches the pattern — re-grep with what you just learned.
- **Commit per round** with a message saying what the round found. Keeps the trail readable.

## Reporting

Per round, tell the user:
- what each hat found (or that it found nothing)
- what you verified vs. took on trust
- what you fixed, what you deferred and why
- test/compile state vs. baseline

At the end: total rounds, why you stopped (dry vs. cap), what remains open.

Be straight about a hat that produced nothing. "Round 3 dry" is a real result. Do not pad it.
