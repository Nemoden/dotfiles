---
name: proper-review-v2
description: Use when reviewing a PR, diff, branch, or any proposed code change. First gathers context autonomously (fetches PR/commits via gh, follows Jira keys via the jira skill, follows Confluence links via the confluence skill, reads referenced files/URLs), then gates the review behind a WHY interrogation so you assess whether the work should exist before assessing how it's written. Criticism is expressed as diffs (not prose walls), entanglement claims get first-principles cost/benefit, and every review opens with specific praise. Triggers on "review this PR", "proper review", "review the diff", "/proper-review", a GitHub PR URL, or any code review request.
---

# Proper Review v2

A code review that skips WHY is theatre. You can polish syntax on code that should never have been written. This skill forces you to interrogate the premise *before* you touch the implementation — and to express criticism as diffs, not prose.

## Core principle

**Five-whys before line-by-line.** A PR's stated reason (WHY₁) is almost always a surface answer. Recurse: ask why WHY₁ is true. WHY₂ often debunks WHY₁ — the ticket was reactive, the problem isn't real, the metric isn't moving, no user is harmed. If you can't reach bedrock, **stop and ask**. Do not invent a plausible WHY to keep moving; that is the failure mode this skill prevents.

**Bedrock** = one of:
- Measurable user-observable harm (bug report, support volume, churn)
- Revenue / legal / compliance obligation with a citation
- Measured performance constraint (numbers, not vibes)
- A blocker for concrete upcoming work (named, scheduled)
- A correctness invariant the code currently violates

**Not bedrock** = "PM asked," "we always do it this way," "feels cleaner," "tech debt" (without measured pain), "for consistency" (without naming what breaks otherwise), "future flexibility" (without a named near-term caller).

## First-principles on every entanglement claim

When the PR bundles concerns ("X for the main feature, Y for a cross-cutting concern, Z for an adjacent fix"), **do not default to "split it"**. Default to a cost/benefit question: *what if we shipped without Y? what if we shipped without Z?* Force the answer to be a number, a failure mode, or a named caller — not a vibe.

For each "extra" concern in a diff, ask:
- **What does it cost to add now?** (lines, abstractions, coupling, write amplification, deploy blast)
- **What does it cost to NOT add now?** (named user harm, named correctness break, named follow-up work that becomes harder)
- **Is the bundling load-bearing or accidental?**
  - **Load-bearing** = the feature is unsafe to ship without it. Example: exposing an HTTP endpoint that returns privilege-sensitive payloads without an authz check on that endpoint. The two are inseparable; splitting produces an unsafe interim state.
  - **Accidental** = the concerns just happen to be in the same diff. Different rollout blast radius, different revert paths, different owners. Split.

If the bundling is load-bearing, **do not recommend splitting it**. Recommend either (a) landing the dependency in a *prior* PR so this PR adds the feature on top, or (b) hardening both together in this PR. Recommending splits on load-bearing entanglement creates unsafe interim deploys.

For any performance claim (denormalisation, caching, batching, parallelism, custom data structure, hand-rolled optimisation): demand the numbers. What is the measured cost being avoided, against what budget at the call site, and is that cost user-visible? If the saved cost is invisible (background job, async pipeline, off-critical-path), the optimisation pays for nothing and you pay its added complexity — extra state, new failure modes, harder reasoning, more code to maintain. Reject the optimisation; do the simple thing. "Performance" without a number is a vibe, not a justification.

Apply this reasoning when reading the code. **Do not narrate "applying first principles now."** The user sees the conclusions and the diffs; they don't need the meta-commentary.

## TL;DR per section

Every top-level section (Context, WHY, Fit, Issues) opens with a `TL;DR:` line. One line, scannable, sets reader expectation before the body.

| Section | TL;DR shape |
|---|---|
| Context | Sources in *importance order* (most → least authoritative). Typical: `PR description, JIRA ticket KEY-NNN, code, common sense`. If a source was unreachable, say so here. |
| WHY | Quick reasoning: *doing →* user benefit; *not doing →* concrete cost. One sentence each. |
| Fit | One of three patterns: `Great fit. No other solutions worth considering.` / `Good fit. Could also consider XXXX` / `Bad idea because YYYY. Better: ZZZZ`. |
| Issues | One line — e.g. `1 blocker, 2 nits, no system-killers.` |

TL;DR is not a substitute for the body. It is a pre-read so the user can decide depth.

## Severity indicators per finding

Each praise item in **What's good** and each issue in **Issues** carries a severity emoji as the first character of its header. This lets the reader scan for what matters without parsing prose.

**Praise scale (What's good):**

| Emoji | Meaning |
|---|---|
| 🌟 | Exemplary. Steal-this-pattern. The kind of decision other PRs in this codebase should copy. |
| ✨ | Thoughtful, non-obvious. A choice a less-careful author would have skipped. |
| *(none)* | Ordinary good. Worth naming, not worth a star. |

**Issue scale (Issues):**

| Emoji | Meaning |
|---|---|
| 💀 | System-killer. Ship this and prod burns / data corrupts / security gap opens. Hard merge block. |
| 🔥 | Blocker. Must fix before merge. Correctness, regression, or significant user-visible breakage. |
| ⚠️ | Should fix, not a merge blocker. Degraded UX, hardening, missing test for a real risk. |
| 💭 | Nit. Taste, micro-cleanup, optional. Author's call. |

Place the emoji at the start of the header (`### 💀 1. Title`). The verdict's blockers list MUST match every 💀 and 🔥 item — they cannot become nice-to-haves.

## Express criticism as diffs

Every concrete issue gets a `diff` block showing before → after. Prose explanations sit *above* the diff, not in place of it. Reasoning: a wall of "this is wrong because…" without a diff makes the reviewer the author's editor. A diff makes the change actionable in one paste.

**Format per issue:**

````
### <emoji> N. <Short problem statement>

<1–3 sentences: what's wrong, why it matters, what the fix is.>

```diff
--- a/path/to/file.ext
+++ b/path/to/file.ext
@@ <context>
- old line
+ new line
```

<Optional 1-line caveat or follow-up note.>
````

**Rules:**
- Diff must be minimal — only the lines that change, with enough context to locate them.
- Use unified diff syntax (`---` / `+++` / `@@` / `-` / `+`) so the reader can `git apply` or paste mentally.
- If the fix is "delete the file" / "revert the commit," show the deletion as `- <line>` with no `+` counterpart.
- If the issue has no clean diff (e.g. "this PR should be three PRs," "this needs a follow-up RFC"), say so explicitly and skip the diff block — don't fake one.
- For missing tests, show a stub `+` diff of the test to add, not just "needs a test."
- Prose without a diff is permitted ONLY for: architectural verdicts (Phase 3 fit), the WHY chain (Phase 2), and the section TL;DRs.
- **`No diff.` is a forbidden ending for any numbered Issue.** Every numbered finding in Phase 4 MUST end with a unified diff on real `file:line` (additions, deletions, or both). If you find yourself typing `No diff.`, the finding does not belong in Issues — move it to a one-line entry under **Acknowledged trade-offs** above What's good, or cut it entirely. Common cases that should NOT become Issues: "author already accepted the trade-off in PR comments," "out of scope per author," "follow-up ticket exists," "convention differs but both sides are correct." If the finding is real but the fix is "open a separate ticket," write the ticket title under Acknowledged trade-offs — don't dress it as an Issue.

**Example — the firmness test:**

BAD (vague, lets the finding survive without committing):

````
### 💭 Validator may reject some valid inputs
The narrowing in the last commit fixed one case but other inputs
matching similar patterns may still be rejected. Worth an audit.

No diff.
````

GOOD (concrete, diff or fallout):

````
### ⚠️ `src/validators/foo.py:42` — pattern accepts strings the
caller documents as invalid; narrow the alternation

```diff
-PATTERN = re.compile(r'\bfoo\b|\bbar\b')
+PATTERN = re.compile(r'\bfoo\s?bar\b')
```
````

If the BAD version is what you'd write, either firm it up to the GOOD shape (with a concrete location + diff) or cut it. Both outcomes beat the BAD version surviving into the review.

**Why this format:** the previous prose-heavy style made the reviewer the author's editor — the author had to translate "X is wrong because Y, consider Z" into a code change. Diffs collapse that step. The reviewer's judgment is encoded in the patch.

## Praise what works

Every review includes a **"What's good"** section, placed **after the Verdict, not before**. Rules:

1. **Be specific.** Not "good test coverage" — name the test, the invariant it locks, and the regression it prevents. Name the file, the function, the line, the decision.
2. **Praise non-obvious decisions.** A choice that aligns with an existing codebase convention (naming scheme, error-tagging pattern, module boundary) is praise-worthy; conformance to a generic style guide is not. Praise the choices a less-careful author would have skipped.
3. **Praise WHY-comments.** A comment that names a non-obvious constraint or invariant ("library X is not thread-safe here, so we serialize calls") is exemplary; a comment that restates what the code does ("loop over files") is not. WHY-comments are what good engineers leave behind; surface them.
4. **Show the code, not just the location.** When the praise is about a specific snippet (a guard, a comment, a deterministic-id pattern, a test assertion), include a small fenced code block of the actual lines. A reader scanning the review should see *what* you're praising without opening the file. Pure-prose praise is allowed only for structural decisions (file split, module boundary) where there is no single snippet to quote.
5. **Tag severity with an emoji** per the praise scale above (🌟 / ✨ / *none*).

**Format per praise item:**

````
### <emoji> <path/to/file.ext:LINE> — <short label>

<1–2 sentences: what the decision is and why it's good.>

```<lang>
<actual snippet, 2–8 lines>
```
````

Praise serves three purposes:
- The author keeps doing the good things in the next PR.
- The reviewer demonstrates they read the code rather than running a checklist.
- Future readers of the review see what "good" looks like in this codebase.

If you cannot find anything specific to praise after honest reading, the PR is in serious trouble — make that the verdict, don't fake the praise. But the bar is "specific," not "absent" — most PRs have *something* worth naming.

## Evidence beyond the diff

Static diff reading misses three classes of defect. Before locking verdict, run the checks below when their trigger applies. Skip when not triggered — don't pad reviews with green checkmarks.

**Build / type gate** — trigger: PR touches typed code (TS, Python with mypy, Rust, Go, etc.) and CI status is unknown or stale.
- Run the project's typecheck/build command (`tsc --noEmit`, `mypy`, `cargo check`, `go build ./...`).
- Reviewer is not a substitute for CI, but if CI is red or unreported, do not ship a verdict that ignores it.
- If you can't run it locally, say so and require green CI before merge in the verdict.

**Blast radius** — trigger: PR renames, removes, or changes signature of any exported symbol.
- Use `lsp_find_references` if available, else `grep -rn "<symbol>" -- <repo>` to enumerate callers.
- Count callers in PR vs callers outside PR. If outside > 0 and not updated, that's a 🔥 blocker with a diff stub of the missing updates.
- For deletions: confirm no caller remains; cite the search command in the finding.

**Runtime evidence** — trigger: PR claims perf win, fixes a reproducible bug, or changes test behavior.
- Perf claim: demand the number (see "First-principles on every entanglement claim"). If author didn't provide, that's a ⚠️ — require a benchmark before SHIP.
- Bug fix: confirm a test reproduces the bug pre-fix and passes post-fix. Missing → stub `+` diff of the test.
- Don't fabricate numbers. "Should be faster" is not evidence.

These checks feed Phase 4 findings, not Phase 2/3. WHY-gate runs first regardless.

## Workflow

Run the phases in order. Phase 1 and Phase 2 are **hard gates**. Do not proceed to Phase 3 until both produce a locked WHY (or an explicit user decision to proceed anyway).

### Phase 1 — Context acquisition (blocking gate)

You cannot interrogate a WHY you haven't read. Gather all reasonably-reachable context for the change. The user typically gives a GitHub PR/commit URL, a local branch reference, a file path, or "review my work." Normalize the input, fetch primary context, then chase references one hop deep.

**1. Identify input type and fetch primary context:**

| Input shape | Primary fetch |
|---|---|
| GitHub PR URL | `gh pr view <url> --json title,body,author,commits,files,comments,reviews,headRefName,baseRefName` + `gh pr diff <url>` |
| GitHub commit URL | `gh api repos/{owner}/{repo}/commits/{sha}` + diff |
| GitHub branch / compare URL | `gh api` for commits + diff |
| "this PR" / "my PR" with no URL | `gh pr view --json ...` from CWD |
| Local branch / "this diff" | `git status`, `git diff <base>...HEAD`, `git log <base>..HEAD` |
| File path | `Read` |
| Arbitrary URL | `WebFetch` |
| Nothing specified | Ask user what to review before doing anything |

**2. Chase references (one hop, breadth-first):**

| Reference pattern | How to fetch |
|---|---|
| Jira key (`[A-Z]+-\d+` in PR body, branch name, commit messages) | Invoke the `jira` skill |
| Confluence URL | Invoke the `confluence` skill |
| GitHub issue / PR link | `gh issue view` / `gh pr view` |
| Linked file in the repo | `Read` |
| External URL (docs, RFCs, support tickets) | `WebFetch` |
| Slack / private tool link with no auth | Ask user to paste the relevant content |

**Recursion rule:** one hop from primary. Only recurse further if a linked ticket/doc is clearly load-bearing for understanding WHY. Otherwise note as "unfetched: <url>" and stop.

**3. Handle missing access:** never fabricate. If you couldn't read it, say so and ask the user.

**4. Handle empty context:** if PR body + commit messages + linked ticket + branch name are all uninformative → STOP, ask user for the WHY before proceeding.

**5. Produce a context bundle:**

```
## Context (Phase 1)
TL;DR: <sources in importance order, e.g. "PR description, JIRA PROJ-123, code, common sense">

- Source: <PR URL / local branch / file>
- Primary: <title + 1-line body summary>
- Author / branch: <name> / <branch>
- Diff scope: <N files, +X/-Y lines>
- Linked ticket(s): <KEY-123: title — 1-line summary>  OR  none
- Linked docs: <Confluence/RFC/etc — 1-line summary>  OR  none
- Referenced files/URLs: <fetched or noted>
- Unreachable / asked user about: <list>
```

### Phase 2 — WHY (blocking gate)

1. **Extract WHY₁.** Read PR description, commit messages, linked ticket, code comments. Quote verbatim. No paraphrase.
2. **Recurse.** Ask: *why is WHY₁ true?* Produce WHY₂. Repeat for WHY₃ if WHY₂ is still abstract. Stop at bedrock or exhaustion.
3. **Adversarial check** on each WHY:
   - "If we shipped nothing, what measurable thing gets worse, for whom, by when?"
   - "If we deleted this PR and the ticket, who notices in 30 days?"
   - "Is this solving a problem, or performing solving-a-problem?"
4. **Classify outcome:**
   - **Bedrock found** → WHY locked. Record it. Proceed to Phase 3.
   - **Chain debunks itself** → STOP. Report `PREMISE BROKEN: [explain]. Recommend: kill / rescope.`
   - **No bedrock, only convention/feeling/authority** → STOP. Report `NO BEDROCK FOUND. Stated reason: [WHY₁]. Could not derive harm beneath it. Should this exist?` Ask user.
   - **Ambiguous / cannot derive** → STOP. Ask user. Do not guess.

5. **Refactor / cleanup PRs** require one of: (a) blocks a named upcoming change, (b) measured pain (numbers, not vibes), (c) fixes an actual correctness issue. Else treat as no-bedrock.

6. **Missing-ticket-prose-but-obvious-feature exception**: when the WHY is plausibly real from the feature shape + repo signals (PR labels, branch name, surrounding module, recent commits) but is not *written down*, you may proceed *with an explicit flag* in the verdict. The flag must call out that the ticket should be backfilled before merge so future devs know what this exists to solve. Do not silently invent a WHY and proceed as if it were stated.

### Phase 3 — Solution fit (only after Phase 2 passes)

With WHY locked, evaluate whether *this* solution is the right shape for *this* problem.

- **Minimum solution.** What is the smallest change that resolves the bedrock WHY? State it in one sentence.
- **Diff vs minimum.** Compare actual diff to minimum. For every line beyond the minimum, demand justification: tied to WHY, or speculative?
- **Entanglement audit.** Apply the first-principles cost/benefit above to every "extra" concern. Distinguish load-bearing (cannot split safely) from accidental (should split). Be explicit about which is which — splitting load-bearing concerns creates unsafe interim deploys; *not* splitting accidental ones creates revert pain.
- **Rejected alternatives.** Does the PR consider simpler approaches? If not, name one and ask the author to justify *against* it.
- **Abstraction tax.** New abstraction (class, interface, config flag, helper module)? Demand 3+ current callers OR a named concrete near-term caller. "Future flexibility" alone fails.
- **Test shape.** Tests assert behavior the WHY cares about, or lock implementation details? Over-tested impl is worse than under-tested behavior.

Possible Phase 3 verdicts:
- **Right size** → proceed to Phase 4.
- **Overbuilt** → call out specific lines/abstractions to trim, then proceed.
- **Wrong shape** → recommend rethink before line review is useful.

### Phase 3.5 — Adversarial probes (between Fit and Issues)

Static diff reading misses bugs that need adversarial input thinking. Before Phase 4, probe every new behaviour the diff introduces with hostile inputs. This phase feeds Phase 4 findings — it does not stand alone in the output.

**For every new regex / parser / validator / lexicon / state machine in the diff:**

1. List 3 inputs that *look correct* but should match WRONG — false positives where a broad pattern fires on inputs the author didn't intend (e.g. a keyword used in unrelated contexts that share the same word). Pick inputs the author probably did not test.
2. List 3 inputs that *look correct* but should match RIGHT — false negatives where the pattern misses cases the author intended (e.g. a token that survives the input-normaliser without the word-boundary the pattern still requires).
3. Run them mentally. If uncertain, run them against the actual compiled pattern via `Bash` / `python3 -c` / language-equivalent. Don't guess.
4. For each input where behaviour is wrong, that's a Phase 4 finding with a concrete diff.

**For every hardcoded constant in the diff (log levels, timeouts, batch sizes, retry counts, concurrency limits, page sizes, cache TTLs):**

- Ask: *what does this cost in prod at p99 traffic?* If you can't answer with a number or a named failure mode, that's a probe.
- **Short-circuit probe.** For each literal, ask: *is this value normally chosen per environment in this codebase?* If yes — the literal short-circuits that mechanism and ships one environment's value (usually dev's) to all of them. Finding by default. The fix is to remove the literal and let the existing per-environment mechanism decide; if no such mechanism exists yet, the finding is that one should.

**For every test file in the diff:**

- Distinguish *call-shape assertions* from *behaviour assertions*. Mocking a dependency then asserting how the code-under-test called the mock proves call shape — it does NOT prove the real dependency does anything useful with those calls. If the change's whole point is the *real* dependency's behaviour (e.g. a logger migration whose value is structured-output emission, a serialiser swap whose value is wire format), a fully-mocked test cannot prove the change works. That's a coverage-illusion finding: stub a smoke test that exercises the real dependency and asserts the externally-observable output.

Adversarial probes feed Phase 4 findings. They do not produce praise (praise is for what the author did, not for what the reviewer probed).

### Phase 4 — Standard review (diff-driven)

Each issue uses the diff format from "Express criticism as diffs" above. Cover:

- **Correctness.** Logic, off-by-ones, null/empty, concurrency, ordering, idempotency, race conditions, retry semantics.
- **Edges.** Inputs the author didn't think about. Failure modes. Partial failures. Adversarial inputs for security-sensitive paths.
- **Regressions.** Behavior changed that callers depend on. API/contract shifts. Migration shape.
- **Tests.** Adequate for the WHY's risk surface. Missing tests get a stub `+` diff of the test to add.
- **Coherence.** Matches codebase conventions, or breaks them with a stated reason.
- **Risk.** Blast radius if wrong. Reversibility. Rollout/rollback story. Need for feature flag / kill switch / DLQ.

### Verdict

End every review with one explicit verdict:

- `KILL` — premise broken, work shouldn't exist
- `RESCOPE` — WHY is real but this PR addresses the wrong slice
- `TRIM` — WHY and shape OK, but overbuilt; specify what to cut
- `SHIP-WITH-NITS` — substantively fine, minor cleanups
- `SHIP` — ready

One sentence reason. **List blockers separately from nice-to-haves** — blockers must be addressed before merge; nice-to-haves can be follow-up tickets. If you wrote a long review and can't commit to a verdict, you didn't review — you described.

## Prior bot reviews are leads, not facts

Bot reviews (Claude, CodeRabbit, Copilot, Bito, etc.) are *leads* — never ground truth. Two LLMs agreeing about a third LLM's code is one model talking to itself, not signal.

- **Verify before relaying.** Bot bug claim → read the code, decide independently, present as *your* finding.
- **Bot ✅ ≠ resolved.** Re-check the fix against the diff.
- **No bot flag ≠ safe.** Bots miss WHY, scope, entanglement — your job.
- **Don't quote bot praise or consensus** in your review. "All ten bots green" legitimises bot-to-bot derivation. Cut it.

Allowed: mine bot comments for *leads to investigate*; disagree explicitly when warranted.

User CLAUDE.md / project memory overrides this section.

## Anti-patterns to refuse

- **Sycophant WHY invention.** Filling in a plausible WHY because the PR didn't state one. Ask instead (with the missing-ticket-prose exception above for obviously-real features).
- **Nitpicking before WHY.** Style, naming, formatting — banned until Phase 2 is locked. They legitimize work that may not warrant existing.
- **"LGTM with minor suggestions"** without a verdict. Either commit or say what's missing.
- **Treating consistency as bedrock.** "For consistency with X" only counts if you can name what concretely breaks.
- **"Mirrors existing pattern" as praise.** An existing pattern in the codebase is not automatically good — it may be the same workaround copied twice. Before praising conformance, ask: is the underlying pattern *correct*, or does it paper over a deeper issue (missing packaging, ad-hoc imports, hand-rolled validation)? If the latter, downgrade praise to nit and flag the underlying debt.
- **Vibe verdicts.** "Feels overengineered" → name the abstraction and the missing caller. "Needs more tests" → name the uncovered risk surface AND provide a test stub diff.
- **Wall-of-text critique.** Prose without diffs is the failure mode this skill exists to prevent. If you find yourself writing 4+ sentences without a diff, stop and write the diff.
- **Default-to-split on entanglement.** Always run the cost/benefit first; some bundles are load-bearing and splitting them produces unsafe interim deploys.
- **Skipping praise.** Every review ends with "What's good" after the Verdict, with specific named items. Even tough verdicts. (Earlier versions of this skill placed praise *before* Issues; that anchored the reviewer toward a positive verdict before Phase 4 had finished critiquing. Praise goes last so it doesn't soften the Issues pass.)
- **Generic praise.** "Nice work" / "good tests" / "clean code" are worse than no praise — they signal the reviewer didn't read carefully.
- **Importing bot-review consensus.** Treating prior automated review ✅s, ❌s, or "all addressed" claims as evidence. They are bot-to-bot conversation. Read the diff; derive findings yourself. See "Prior bot reviews are leads, not facts."
- **Rubber-stamping unknown CI.** Issuing SHIP / SHIP-WITH-NITS without confirming CI green or running typecheck/build locally when CI is stale. If unknown, say so in the verdict.

## Output shape

````
## Context (Phase 1)
TL;DR: <sources in importance order — e.g. "PR description, JIRA PROJ-123, code, common sense">

- Source: ...
- Primary: ...
- Author / branch: ...
- Diff scope: ...
- Linked ticket(s): ...
- Linked docs: ...
- Referenced files/URLs: ...
- Unreachable / asked about: ...

## WHY (Phase 2)
TL;DR: Doing → <user benefit>. Not doing → <concrete cost>.

- WHY₁ (stated): "<quote>"
- WHY₂: ...
- WHY₃ (bedrock): ...
- Bedrock type: [user-harm | revenue | legal | perf | blocker | invariant]
- Status: [LOCKED | PREMISE-BROKEN | NO-BEDROCK | ASK-USER]

## Fit (Phase 3)  -- only if LOCKED
TL;DR: <one of: "Great fit. No other solutions worth considering." | "Good fit. Could also consider XXXX." | "Bad idea because YYYY. Better: ZZZZ.">

- Minimum solution: ...
- Actual diff vs minimum: [right-size | overbuilt | wrong-shape]
- Entanglement audit: <which extras are load-bearing vs accidental, with cost/benefit reasoning>

## Issues (Phase 4)
TL;DR: <e.g. "1 system-killer, 1 blocker, 3 nits.">

> Findings that rely on external evidence (caller count, benchmark, CI run, type error) cite the command and result inline. "grep -rn foo src/ → 12 callers, 3 not updated" beats "this breaks callers."

### 💀 1. <Short problem statement>
<1–3 sentences>
```diff
- ...
+ ...
```
<optional caveat>

### 🔥 2. <Short problem statement>
...

### ⚠️ 3. <Short problem statement>
...

### 💭 4. <Short problem statement>
...

## Verdict
[KILL | RESCOPE | TRIM | SHIP-WITH-NITS | SHIP] — <one-line reason>

**Blockers before merge** (must include every 💀 and 🔥):
1. ...
2. ...

**Nice-to-haves / follow-ups** (⚠️ and 💭):
- ...
- ...

**Acknowledged trade-offs** (findings that don't belong in Issues — author already accepted, out-of-scope, or covered by follow-up ticket):
- <one-line: trade-off — author's stated reason — follow-up ticket if any>

## What's good

### 🌟 <path/file.ext:LINE> — <short label>
<1–2 sentences naming the decision and why it's good.>
```<lang>
<actual snippet, 2–8 lines>
```

### ✨ <path/file.ext:LINE> — <short label>
...

### <path/file.ext:LINE> — <short label>
<ordinary good — no emoji prefix>
````

## Parallelism: don't slice the PR

proper-review is single-context by design. The phase gates (Phase 2 WHY → Phase 3 Fit → Phase 4 Issues) require one reviewer holding the whole diff. Parallel reviewers reviewing file-slices break the gates:

- Each slice does its own mini-WHY or skips it → no locked premise
- Entanglement audit (Phase 3) is impossible without seeing the whole diff
- Verdict becomes N stapled mini-reviews, not one coherent call
- Slice boundaries (infra/python/tests/frontend) are author-side concerns; review must judge them together, not in isolation

**Rule:** when running this skill, do NOT spawn parallel agents that each review a subset of files. One reviewer, whole diff, phases in order.

**Dimension parallelism — auto-trigger thresholds.** After Phase 1 produces the context bundle (so the diff scope is known), evaluate the following. Spawn dimension-agents *each holding the whole diff* with a single lens when ANY of the following is true:

- **Size:** changed-files ≥ 8 OR `additions + deletions` ≥ 400.
- **Risk surface:** the diff touches ≥ 2 of {auth/authz, DB migrations, public API contract, infra/CI config, payment/PII handling}.
- **User opt-in (always fires, regardless of size/risk):** ANY of the following — explicit phrases like "use teams" / "use parallel agents" / "use subagents" / "deploy agents" / "split this review" / "fan out" / "dimension agents"; depth phrases like "do a thorough review" / "deep review" / "exhaustive review" / "be paranoid" / "leave no stone unturned"; specialism callouts like "security review" / "perf review" / "test review" / "review for X and Y" (multiple lenses named). Interpret intent generously — if user signals "more than one pass" or "more eyes," that's opt-in.

Below those thresholds, default to single reviewer. Don't burn tokens on a 5-file logging PR.

When auto-triggered, log the trigger reason in the Context TL;DR (e.g. `Dimension parallelism: 14 files / 612 lines → triggered.`) so the reader knows why the review used more agents.

| Dimension | Agent / lens | Spawn when |
|---|---|---|
| Security | OWASP, secrets, authz, input handling | diff touches auth/authz, input parsing, or any user-facing endpoint |
| Performance | hot paths, N+1, allocations, complexity | diff has perf claim OR touches request-path / loop-heavy code |
| Tests | coverage of WHY-relevant risk, flakiness, over-mocking | always, when parallelism triggers |
| Migration / data | schema/migration safety, backfill, lock behaviour | diff contains `migrations/`, `*.sql`, or ORM schema changes |
| API / contract | callers outside the diff, breaking changes | diff renames/removes exported symbols, changes signatures, or modifies OpenAPI/protobuf |

Spawn only the dimensions whose "Spawn when" condition matches — don't fan out to all five reflexively.

Rules:
- Main agent runs Phases 1–3 and writes the final Verdict. Dimension-agents feed Phase 4 issues only.
- Each dimension-agent reads the whole diff, not a slice.
- Main agent dedupes findings (same defect from multiple lenses = one issue, highest severity wins).
- Dimension-agents do NOT write their own verdicts. They report findings in the same emoji/diff format and stop.

**Cross-model check (optional):** for high-stakes PRs (size ≥ 1000 lines OR touching payments/auth/PII), route the same diff through a second model (e.g. `/ccg`) and treat divergence as a flag — findings only one model raised get extra scrutiny. Convergence is weak signal (same blind spots); divergence is the value.

**Override:** user can downgrade ("just a quick review, no agents") or upgrade ("spawn all dimensions even though it's small") — user instruction wins over thresholds.

## When to skip this skill

- Trivial diffs (typo, dependency bump with no behavior change, generated code).
- User explicitly says "just check syntax" / "just lint this."
- Hotfix on a live incident where WHY is self-evident (the incident).

In all other cases, run Phase 2. The cost of asking "why" is one message. The cost of approving work that shouldn't exist compounds forever.
