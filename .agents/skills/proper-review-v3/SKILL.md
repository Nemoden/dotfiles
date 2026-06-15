---
name: proper-review-v3
description: Use when reviewing a PR, diff, branch, or any proposed code change. A staged review that mirrors how a senior engineer actually works — understand WHY first, calibrate how much rigor the change deserves, solve the problem independently (blind, via a subagent that never sees the diff) so judgment isn't anchored on the author's approach, THEN read the code and compare, and only LAST read bot/other reviews so they can't anchor you. Criticism is expressed as diffs, not prose walls. Triggers on "review this PR", "proper review v3", "review the diff", "/proper-review-v3", a GitHub PR URL, or any code review request.
---

# Proper Review v3

A review that reads the bots first confirms the bots. A review that reads the code before forming its own opinion is anchored on the author. This skill enforces the order a good human reviewer uses naturally:

**understand → calibrate → solve it yourself → read the code → compare → only then read what others said.**

Order is the discipline. If you solve the problem before reading the diff, you can't anchor on the author. If you read the bots last, you can't inherit their framing. The stages below enforce both.

## The stages

| # | Stage | Gate |
|---|---|---|
| 1 | Context acquisition (don't read bot *content* yet) | hard |
| 1.5 | Stakes calibration | hard |
| 2 | WHY interrogation | hard |
| 2.5 | Blind independent solve (subagent, no diff) | conditional |
| 3 | Fit & approach comparison | — |
| 3.5 | Adversarial + named-risk probes | — |
| 4 | Issues (diff-driven) | — |
| 5 | Read bots/others LAST | — |
| — | Verdict + What's good | — |

Run in order. **Do not read bot comment content before Stage 5** — this is the load-bearing rule.

Skip the whole skill only for: trivial diffs (typo, dep bump with no behaviour change, generated code), an explicit "just lint this," or a live-incident hotfix where the incident *is* the WHY.

---

## Stage 1 — Context acquisition (hard gate)

You cannot interrogate a WHY you haven't read. Gather all reachable context, then chase references one hop deep.

**Identify input, fetch primary:**

| Input | Fetch |
|---|---|
| GitHub PR URL | `gh pr view <url> --json title,body,author,commits,files,comments,reviews,headRefName,baseRefName` + `gh pr diff <url>` |
| GitHub commit URL | `gh api repos/{owner}/{repo}/commits/{sha}` + diff |
| Branch / compare URL | `gh api` for commits + diff |
| "this PR" (no URL) | `gh pr view --json ...` from CWD |
| Local branch / "this diff" | `git status`, `git diff <base>...HEAD`, `git log <base>..HEAD` |
| File path | `Read` |
| Arbitrary URL | `WebFetch` |
| Nothing specified | Ask what to review before doing anything |

**Chase references (one hop, breadth-first):** Jira key (`[A-Z]+-\d+`) → `jira` skill. Confluence URL → `confluence` skill. GitHub issue/PR link → `gh ... view`. Repo file → `Read`. External URL → `WebFetch`. Auth-walled link → ask user to paste. Recurse a second hop only if a linked ticket/doc is clearly load-bearing for WHY; else note `unfetched: <url>` and stop.

Never fabricate. If you couldn't read it, say so. If PR body + commits + ticket + branch name are all uninformative → STOP, ask for the WHY.

**Bots: enumerate, do NOT read content.** Record *that* bots reviewed and how many comments each left — never what they said. Reading their findings now would anchor you. Stash deep-links; open them in Stage 5.

Fetch the comment metadata:
```bash
gh api repos/{owner}/{repo}/pulls/{n}/comments --paginate
gh api repos/{owner}/{repo}/issues/{n}/comments --paginate
gh pr view <url> --json reviews,comments
```
Capture each comment's `html_url` for the Stage 5 deep-link. **Bot detection** (generic, err toward tagging): `author.is_bot == true`; REST `User.type == "Bot"`; login matches `*bot` / `*-ai` / `*-reviewer` / `*-pull-request-reviewer`; well-known set (`claude`, `coderabbitai`, `copilot-pull-request-reviewer`, `bito-bot`, `codium-ai`, `sourcery-ai`, `qodo-merge-pro`, `github-actions`); or `authorAssociation == "NONE"` with review-shaped output. Record login + counts only.

If you accidentally read a bot finding while skimming, name it in Stage 5 rather than pretending you didn't.

**Output:**
```
## Context (Stage 1)
TL;DR: <sources in importance order, e.g. "PR description, JIRA APG-123, code, common sense">
- Source / Primary (title + 1-line) / Author + branch / Diff scope (N files, +X/-Y)
- Linked ticket(s) / Linked docs / Referenced files
- Prior bot reviews: <login: N inline + M summary, latest YYYY-MM-DD — COUNTS ONLY> OR none
- Unreachable / asked about: ...
```

---

## Stage 1.5 — Stakes calibration (hard gate)

Not every change deserves prod-grade scrutiny. A one-time test-only backfill doing N+1 queries is *fine*; flagging it as a perf blocker is noise. Classify the change before interrogating WHY, and state which checks relax.

| Tier | What it is | Rigor |
|---|---|---|
| `prod-critical` | Runs against prod data/traffic, customer-visible, or mutates persistent state | Full. Every Stage 3.5 risk applies; irreversibility / corruption / missing-timeout are blockers. |
| `internal-tooling` | Internal dashboards, ops scripts, read-only prod tooling, BI | Correctness + reversibility matter; UX/polish relaxes; perf only if it blocks the operator. |
| `throwaway-script` | One-time migration/backfill/investigation, deleted after use | Correctness on data it touches matters; N+1, cohesion, coverage, abstraction mostly lifted. Reversibility still matters if it writes prod. |
| `test-only` | Only test code/fixtures, or runs only against non-prod data | Most prod checks lifted. Judge: tests the right behaviour, not flaky, doesn't give false confidence (over-mocking). |

**The tier is a claim — verify it.** "Throwaway script" with no self-delete that writes a prod table is `prod-critical` until proven otherwise. When ambiguous, **ask** — voice the assumption: *"I read this as throwaway test-only, so I'd lift the N+1 and coverage checks. But it writes `adieu-pool-matters-dev` — genuinely throwaway, or does it persist? If prod, I'd re-flag the N+1."*

This conditions every later severity. A finding that's 🔥 at `prod-critical` may be 💭 or dropped at `throwaway-script`. State the conditioning whenever it changes a verdict.

**Output:**
```
## Stakes (Stage 1.5)
TL;DR: <tier> — <what relaxes>
- Tier / Evidence (why this tier) / Relaxed checks / Still-enforced
```

---

## Stage 2 — WHY interrogation (hard gate)

**Five-whys before line-by-line.** A PR's stated reason (WHY₁) is almost always surface. Recurse: *why is WHY₁ true?* WHY₂ often debunks WHY₁ — the ticket was reactive, the problem isn't real, the metric isn't moving, no user is harmed.

**Bedrock** = measurable user harm (bug report, support volume, churn) / revenue-legal-compliance obligation with a citation / measured perf constraint (numbers, not vibes) / a blocker for named scheduled work / a correctness invariant the code violates.

**Not bedrock** = "PM asked," "we always do it this way," "feels cleaner," "tech debt" without measured pain, "for consistency" without naming what breaks, "future flexibility" without a named near-term caller.

**Steps:**
1. Extract WHY₁ — quote verbatim from PR/commits/ticket/comments. No paraphrase.
2. Recurse to WHY₂, WHY₃ until bedrock or exhaustion.
3. Adversarial check each: *if we shipped nothing, what measurable thing gets worse, for whom, by when? If we deleted this PR + ticket, who notices in 30 days? Is this solving a problem or performing solving-a-problem?*
4. Classify: **bedrock found** → LOCKED, proceed. **Chain debunks itself** → STOP, `PREMISE BROKEN: [explain]. Recommend kill/rescope.` **Only convention/feeling/authority** → STOP, `NO BEDROCK. Stated: [WHY₁]. Couldn't derive harm beneath it. Should this exist?` **Ambiguous** → STOP, ask.

Refactor/cleanup PRs need one of: blocks a named upcoming change, measured pain (numbers), or fixes a real correctness issue. Else no-bedrock.

**Missing-ticket exception:** when WHY is plausibly real from feature shape + repo signals (labels, branch, surrounding module, recent commits) but isn't written down, you may proceed *with an explicit verdict flag* that the ticket should be backfilled before merge. Never silently invent a WHY.

**Assumption-voiced ask.** When WHY is unclear or a claim can't be resolved from PR + code alone, don't guess and don't ask open-endedly. Voice the assumption *with evidence*, then ask:

> *"I think the author is trying to do **X**. But **A** in the diff suggests **THIS**, and **B** suggests **THAT** — so either X is only partially achieved, or I'm missing the mark. Which?"*

Showing the reasoning gives the user a sharp thing to confirm or correct. Filling an intent gap with the author's own framing is the failure this prevents.

**Output:**
```
## WHY (Stage 2)
TL;DR: Doing → <benefit>. Not doing → <concrete cost>.
- WHY₁ (quote) / WHY₂ / WHY₃ (bedrock) / Bedrock type / Status [LOCKED | PREMISE-BROKEN | NO-BEDROCK | ASK-USER]
- <assumption-voiced ask if anything unclear>
```

---

## Stage 2.5 — Blind independent solve (conditional gate)

Before critiquing the author's approach, solve the problem yourself — *blind*, so the diff doesn't anchor you. A reviewer who reads the implementation first evaluates *the author's solution*; one who solves it first evaluates *the problem*, then compares.

You can't un-see a diff you've read. So delegate the blind solve to a **fresh subagent that never sees the diff and can't fetch it.**

**Fires when EITHER (be eager):**
- **Net-new logic** — new behaviour, algorithm, data flow, or contract. (Pure-mechanical — rename, config, dep bump, test-only, generated — does NOT fire on this axis at any size.)
- **Size** — changed-files ≥ 5 OR `additions + deletions` ≥ 150.

**Skips** when small AND mechanical — read the code right away, go to Stage 3. State it: `Blind-solve: skipped (3-file rename, mechanical).`

**Run it:**
1. **Draft the problem statement** from the locked WHY + stakes tier + established constraints (owning service, its storage, the invariant it must hold). Describe the *problem*, never the author's solution — no file names that hint at the approach, no diff content.
2. **Show it to the user, get confirmation** — a checkpoint, because a misframed problem makes the subagent solve the wrong thing:
   > *"Here's the problem statement for the blind solver. It will NOT see the PR. Correct me before I dispatch:"* → [statement]
   Incorporate corrections, then dispatch.
3. **Dispatch a fresh subagent** (`Agent`, `general-purpose` or `Plan`) with the confirmed statement + minimal constraints (not the conversation history) and an explicit ban: *you may NOT fetch the PR, branch, or any diff; design from the problem alone.* Ask for 1–3 approaches and its pick, with reasoning.
4. **Receive its solution** — your independent baseline. You now hold the author's approach (diff you read) and an un-anchored designer's (subagent). Stage 3 compares.

A subagent gives *real* blindness; "try not to anchor" doesn't — you've already read the diff. Cost is one dispatch; payoff is an honest second design to compare against.

**Output:**
```
## Blind solve (Stage 2.5)
TL;DR: <fired | skipped (reason)>
- Problem statement (confirmed with user) / Subagent approaches (1–3) / Subagent's pick + why
```

---

## Stage 3 — Fit & approach comparison

With WHY locked and an independent solution in hand, judge whether the author's approach is the right shape — by comparing to your blind solve, not in a vacuum.

- **Minimum solution.** Smallest change resolving the bedrock WHY, in one sentence. Compare actual diff to it; every line beyond demands a tie to WHY or it's speculative.
- **Approach comparison** (drives the Fit TL;DR):
  - **Matches** your blind solve → strong signal the shape is right.
  - **Better** than yours → say so specifically; praise-worthy (author saw what your solver didn't).
  - **Worse / differs** → highest-value finding a review produces. Name what your approach does that theirs doesn't; decide: real defect, or two valid ways? Worse on a Stage-3.5 risk axis (irreversible, corrupting, untimed) = blocker. Worse on taste only = nit.
  - Be honest when theirs is better. The blind solve un-anchors you; it isn't a claim your design is the standard.
- **Naming-honesty.** For each name implying a contract — `version`, `validator`, `serializer`, `cache`, `lock`, `transaction`, `idempotent`, `registry`, `retry` — verify the implementation delivers the contract. A `get_prompt_version` returning a content hash is mis-named: the name is the defect.
- **Entanglement audit.** When the PR bundles concerns, **don't default to "split it."** Ask per extra concern: cost to add now (lines, coupling, write-amplification, deploy blast)? cost to NOT add now (named harm, named correctness break, named follow-up made harder)? **Load-bearing** (feature unsafe without it — e.g. an endpoint returning privilege-sensitive payloads without its authz check) → don't split; land the dependency in a prior PR or harden both together. **Accidental** (different blast radius, revert path, owner) → split.
- **Performance claims** demand a number: measured cost avoided, against what budget at the call site, user-visible? If the saved cost is invisible (background/async/off-critical-path), reject the optimisation — you pay complexity for nothing. "Performance" without a number is a vibe.
- **Abstraction tax.** New class/interface/flag/helper needs 3+ current callers OR a named near-term caller. "Future flexibility" alone fails.
- **Test shape.** Tests assert behaviour the WHY cares about, not implementation details.

Don't narrate "applying first principles now" — the user sees conclusions and diffs, not meta-commentary.

**Fit TL;DR shapes:** `Matches my solve. Right shape.` / `Better than mine — author <did X> I'd have missed.` / `Differs — mine <does Y>; theirs doesn't. <Real defect | valid alternative>.` / `Wrong shape — theirs solves a different problem than the WHY states.`

---

## Stage 3.5 — Adversarial + named-risk probes

Static diff reading misses bugs that need adversarial thinking and the risks a senior reviewer scans for explicitly. Run each probe; skip with a one-liner when the Stage-1.5 tier lifts it. Don't pad with green checkmarks.

**Adversarial inputs** — for every new regex / parser / validator / lexicon / state machine: list 3 inputs that look correct but should match WRONG (false positives the author didn't test) and 3 that look correct but should match RIGHT (false negatives the pattern misses). Run them mentally; if uncertain run them for real (`python3 -c`, language-equivalent) — don't guess. Each wrong result is a finding with a diff.

**Hardcoded constants** — log levels, timeouts, batch sizes, retry counts, concurrency limits, page sizes, TTLs: ask *what does this cost in prod at p99?* If no number or named failure mode, it's a probe. **Short-circuit probe:** if the value is normally chosen per-environment in this codebase, a literal ships one env's value (usually dev's) to all — finding by default; fix is to route through the existing per-env mechanism.

**Named risks** (each conditioned by tier):
1. **Irreversibility.** Mutates prod data, drops a column, rewrites records, takes an action with no rollback? Is there a dry-run / backup / reverse migration / kill switch? Irreversible + `prod-critical` = 💀 until a rollback path exists. (`throwaway-script` writing prod is still on the hook — this rarely lifts.)
2. **Data corruption.** Partial failure leaving inconsistent state? Non-atomic multi-write without a transaction or idempotency key? Half-applying migration? Corruption of persistent state = 💀/🔥 at `prod-critical`.
3. **Untimed external calls.** Every 3rd-party HTTP call, L2L invoke, external DB query — does it set a timeout? An unbounded wait hangs the caller and exhausts Lambda duration / connection pools. Missing timeout on a prod request path = 🔥.
4. **Performance / N+1.** Per-item queries in a loop, missing batch, O(n²) on a request path. 🔥 on a `prod-critical` request path; lifted for a one-time `throwaway-script` (state it: "N+1 acceptable — one-time backfill").
5. **Cohesion / coupling / LoB.** Is the logic where a reader would look for it, or scattered? New coupling between modules that shouldn't know each other? Respect locality of behaviour — coincidental duplication beats wrong coupling; don't flag DRY violations that are actually correct locality.
6. **Boy-scout / missed caveats.** A non-obvious constraint left uncommented, a WHY the next reader trips on, an easy leave-it-better skipped. 💭 nits, never blockers — but naming them is part of a real review.

**Test files** — distinguish *call-shape* assertions from *behaviour* assertions. Mocking a dependency then asserting how the code called the mock proves call shape, not that the real dependency does anything useful. If the change's whole point is the real dependency's behaviour (a logger migration whose value is structured output, a serialiser swap whose value is wire format), a fully-mocked test can't prove it works — coverage-illusion finding; stub a smoke test exercising the real dependency.

**Evidence beyond the diff** (run when triggered): **build/type gate** — if CI is stale/unknown on typed code, run `mypy`/`tsc --noEmit`/`cargo check`; if you can't run it, require green CI in the verdict. **Blast radius** — on any renamed/removed/signature-changed exported symbol, `grep -rn "<symbol>"` (or LSP) to count callers; outside-diff callers not updated = 🔥 with a stub diff; cite the command.

---

## Stage 4 — Issues (diff-driven)

Write every finding from your *own* reading — at this point you've still opened zero bot comments. Cover correctness (logic, off-by-one, null/empty, concurrency, ordering, idempotency, retries), edges/failure modes, regressions/contract shifts, tests, coherence, risk — all conditioned by the stakes tier.

**Every finding is a diff.** Prose sits *above* the diff, not instead of it. Format:

````
### <severity> N. <short problem statement>
<1–3 sentences: what's wrong, why it matters, the fix.>
```diff
--- a/path/file.ext
+++ b/path/file.ext
@@ <context>
- old
+ new
```
<optional 1-line caveat>
````

Severity (first char of header): **💀** system-killer (prod burns / data corrupts / security gap — hard block) · **🔥** blocker (correctness, regression, user-visible breakage) · **⚠️** should-fix (degraded UX, hardening, missing test for a real risk) · **💭** nit (taste, optional). The verdict's blocker list MUST include every 💀 and 🔥.

Rules: diff minimal, unified syntax so it pastes/applies. "Delete the file" → `-` lines with no `+`. Missing test → stub `+` diff of the test to add, not "needs a test." No clean diff possible (e.g. "this should be three PRs") → say so, skip the block, don't fake one. **`No diff.` is forbidden** for a numbered Issue — if you'd write it, the finding isn't an Issue: move it to `Acknowledged trade-offs` (author already accepted, out of scope, follow-up ticket exists, convention differs but both correct) or cut it.

Firmness test — BAD: `### 💭 Validator may reject some valid inputs … worth an audit. No diff.` GOOD: `### ⚠️ src/validators/foo.py:42 — pattern accepts strings the caller documents invalid` + a real diff narrowing the alternation. Firm it up or cut it.

(Bot markers are added in Stage 5 — not now.)

---

## Stage 5 — Read bots/others LAST

Now, and only now, open the deep-links stashed in Stage 1 and read what bots and other humans said. Your findings are locked, so anything you adopt is genuinely cross-checked, not inherited.

Bot reviews are **leads, not facts** — two LLMs agreeing about a third LLM's code is one model talking to itself. For each comment, pick one:

- **Caught something I missed** → verify against the code yourself; if real, add a new Stage 4 issue marked 🤖 with a `Prior bot:` line.
- **Also found it** → add 🤖 + `Prior bot:` deep-link to your existing finding. Independence preserved — you found it first, blind.
- **Wrong, my findings refute it** → say so with reasoning. High value: *"CodeRabbit flags the N+1 in `backfill.py` — but per Stage 1.5 this is a one-time throwaway against test data, so it's fine. Bot lacks the stakes context."*

**Per-finding bot marker.** Every Issue header carries a second emoji after the severity: `🤖` (a bot flagged it) or `✨` (independent catch) — `### 🔥 ✨ 2. Title`. Header marker and the `Prior bot:` line must agree. Pick one line shape:
- `**Prior bot:** 🤖 already flagged by <login> ([inline](url)). Reinforced because <prod-safety / blocker / bot's diff insufficient>.`
- `**Prior bot:** 🤖 partially flagged by <login> ([inline](url)) — caught <X>, missed <Y> (added here).`
- `**Prior bot:** 🤖 flagged by multiple bots (<a>, <b>) ([a](url-a), [b](url-b)).`
- `**Prior bot:** ✨ not raised by any bot review.`

Use the exact login captured in Stage 1 (not a hardcoded "claude-bot"). Because every finding was formed before reading a bot, the ✨ markers are *true* independence, not a claim.

**Bot findings not promoted to Issues** (only when ≥1 dropped) — one line each, forces an explicit decision:
```
- 🤖 <login> on <file:line> — "<summary ≤80 chars>" — Dropped because: <already in Acknowledged trade-offs | verified, bot is wrong | out of scope/WHY-locked | duplicate of Issue N | bot misread the diff>.
```

---

## Verdict + What's good

**Verdict** — one of: `KILL` (premise broken) · `RESCOPE` (WHY real, wrong slice) · `TRIM` (right WHY+shape, overbuilt — name what to cut) · `SHIP-WITH-NITS` · `SHIP`. One-line reason, conditioned by stakes tier. Blockers listed separately from nice-to-haves (blockers = every 💀 and 🔥). **Decline (KILL/RESCOPE) when any named risk is true and unmitigated** at the tier: irreversible prod mutation with no rollback, possible data corruption, unbounded external wait on a request path.

`Bot overlap:` line after the reason: `N of M issues flagged by bots (🤖); K independent (✨).` If overlap = 100%, the text must say the review only confirms bots, no independent catches.

**What's good** — *after* the verdict (so praise doesn't soften the Issues pass). Specific, named, snippet-shown, severity-tagged (**🌟** exemplary steal-this-pattern · **✨** thoughtful non-obvious · *none* ordinary good). Praise non-obvious decisions and WHY-comments (a comment naming a real constraint — "library X isn't thread-safe here, so we serialize" — not one restating the code). Credit the author where their approach beat your blind solve. Show 2–8 lines of the actual snippet. If you can't find anything specific to praise, that's a verdict signal — don't fake it. Conformance to a generic style guide isn't praise; "mirrors existing pattern" isn't automatically praise — the pattern may be a workaround copied twice.

**Output shape:**
````
## Context (Stage 1)
TL;DR: <sources, importance order>
- Source / Primary / Author+branch / Diff scope / Linked ticket(s) / Linked docs / Referenced files
- Prior bot reviews: <login: counts, latest date — content unread> OR none
- Unreachable / asked about: ...

## Stakes (Stage 1.5)
TL;DR: <tier> — <what relaxes>
- Tier / Evidence / Relaxed / Still-enforced

## WHY (Stage 2)
TL;DR: Doing → <benefit>. Not doing → <cost>.
- WHY₁ (quote) / WHY₂ / WHY₃ / Bedrock type / Status
- <assumption-voiced ask if unclear>

## Blind solve (Stage 2.5)
TL;DR: <fired | skipped (reason)>
- Problem statement (confirmed) / Subagent approaches / Subagent's pick

## Fit (Stage 3)  -- only if LOCKED
TL;DR: <Matches mine | Better than mine — ... | Differs — ... | Wrong shape>
- Minimum solution / Diff vs minimum / Approach comparison / Naming-honesty / Entanglement audit

## Issues (Stage 4 + bot markers from Stage 5)
TL;DR: <e.g. "1 blocker, 3 nits — throwaway tier lifts the N+1.">
### 🔥 ✨ 1. <problem>
<1–3 sentences>
```diff
- ...
+ ...
```
**Prior bot:** ✨ not raised by any bot review.

## Bot findings not promoted to Issues
- 🤖 <login> on <file:line> — "<summary>" — Dropped because: <reason>.

## Verdict
[KILL | RESCOPE | TRIM | SHIP-WITH-NITS | SHIP] — <reason, conditioned by tier>
**Bot overlap:** N of M flagged by bots (🤖); K independent (✨).
**Blockers before merge:** ...
**Nice-to-haves / follow-ups:** ...
**Acknowledged trade-offs:** ...

## What's good
### 🌟 <file:LINE> — <label>
<1–2 sentences; credit author where their approach beat the blind solve>
```<lang>
<snippet 2–8 lines>
```
````

---

## Anti-patterns to refuse

- **Reading bots before Stage 5.** The whole point — read their content early and you inherit their framing.
- **Reading the diff critically before the blind solve** (when it fires). Anchors you on the author's approach.
- **Sycophant WHY invention** — filling a plausible WHY because the PR didn't state one. Ask (missing-ticket exception aside).
- **Nitpicking before WHY** — style/naming/format banned until Stage 2 locks. Legitimizes work that may not warrant existing.
- **Trusting good prose as correct design.** A thorough PR description justifies the design *within its own frame* — it never challenges the frame.
- **A name as proof.** `get_x_version` isn't a version function because it's named one. Verify the contract.
- **Uniform rigor.** Flagging an N+1 in a one-time throwaway as a blocker is noise. Condition on the stakes tier.
- **"LGTM with minor suggestions"** without a verdict. Commit or say what's missing.
- **Consistency as bedrock** without naming what concretely breaks.
- **Vibe verdicts** — "feels overengineered" → name the abstraction + missing caller; "needs more tests" → name the uncovered risk + a stub diff.
- **Wall-of-text critique** — prose without a diff. 4+ sentences with no diff → stop and write the diff.
- **Default-to-split on entanglement** — run cost/benefit first; some bundles are load-bearing.
- **Importing bot consensus** — "all bots green" is bot-to-bot conversation, not evidence. Derive findings yourself.
- **Silent bot overlap** — raising what a bot raised without the `Prior bot:` line; reader can't tell you read them.
- **Skipping praise** — every review ends with specific named What's good, even tough verdicts. Generic praise ("nice work") is worse than none.
- **Rubber-stamping unknown CI** — no SHIP without confirming CI green or running the build when CI is stale; if unknown, say so.

## Parallelism

One reviewer holds the whole diff — the stage gates require it; parallel reviewers on file-slices break the WHY lock and the entanglement audit. When the diff is large (≥8 files OR ≥400 lines) or touches ≥2 of {auth/authz, DB migrations, public API contract, infra/CI, payment/PII}, or the user opts in ("thorough", "deep review", "security review", "use agents"), you may spawn **dimension-agents that each hold the whole diff with a single lens** (security / performance / tests / migration / API-contract) feeding Stage 4 only — the main agent runs Stages 1–3 + 5 and writes the verdict. Log the trigger in the Context TL;DR. **Do not confuse these with the Stage 2.5 blind-solve subagent** — dimension-agents read the whole diff; the blind solver reads none of it.
