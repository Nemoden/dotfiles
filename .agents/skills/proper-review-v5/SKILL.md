---
name: proper-review-v5
description: Use when reviewing a PR, diff, branch, or any proposed code change. A staged review that mirrors how a senior engineer actually works — read the code COLD first (diff only, no ticket prose) and articulate what it does, understand the stated WHY, reconcile the two (HARD HALT on mismatch), calibrate rigor, solve the problem independently (blind, via a subagent that never sees the diff) so judgment isn't anchored on the author's approach, THEN compare, then sweep the reach (consumers + project conventions outside the diff, un-anchored), and only LAST read bot/other reviews so they can't anchor you. Criticism is expressed as diffs, not prose walls. Triggers on "review this PR", "proper review v5", "review the diff", "/proper-review-v5", a GitHub PR URL, or any code review request.
---

# Proper Review v5

A review that reads the bots first confirms the bots. A review that reads the ticket's stated reason before reading the code sees the code as confirming the ticket — and misses the case where the code quietly does something *else*. This skill enforces the order a good human reviewer uses naturally:

**read the code cold → understand the stated WHY → reconcile (halt on mismatch) → calibrate → solve it yourself → compare → only then read what others said.**

Order is the discipline. If you read the code before the ticket's prose, your reading of *what the code does* can't be primed by *what it's supposed to do* — so a code-says-X / ticket-says-Y divergence surfaces instead of getting rationalised away. If you solve the problem before critiquing the diff, you can't anchor on the author. If you read the bots last, you can't inherit their framing. The stages below enforce all three.

## The stages

| # | Stage | Gate |
|---|---|---|
| 1a | Context acquisition — fetch diff, enumerate refs/bots (don't read PR-body/ticket prose OR bot content yet) | hard |
| 0.5 | Cold code read (main thread, diff only) | hard |
| 1b | Context — now read the stated-WHY prose (PR body, ticket, docs) | hard |
| 1.5 | Stakes calibration | hard |
| 2 | WHY interrogation | hard |
| 2.7 | Code-vs-WHY reconciliation (HARD HALT on mismatch) | hard |
| 2.5 | Blind independent solve (subagent, no diff) | conditional |
| 3 | Fit & approach comparison | — |
| 3.5 | Adversarial + named-risk probes | — |
| 4 | Issues (diff-driven) | — |
| 5 | Read bots/others LAST | — |
| — | Verdict + What's good | — |

Run in order. **Do not read PR-body/ticket prose before Stage 1b** (it would prime the cold read) and **do not read bot comment content before Stage 5** (it would anchor your findings). These two are the load-bearing rules.

Skip the whole skill only for: trivial diffs (typo, dep bump with no behaviour change, generated code), an explicit "just lint this," or a live-incident hotfix where the incident *is* the WHY.

---

## Stage 1a — Context acquisition: fetch, don't read the WHY yet (hard gate)

Fetch everything reachable, but **defer reading the prose that states the WHY** — the PR description body, the linked ticket's description, the design docs. You'll read those at Stage 1b, *after* the cold code read. At 1a you fetch them and stash them UNREAD, and you enumerate references and bots.

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

**What you may look at NOW:** the diff, the file list, the commit *subjects* (short, mechanical — usually safe), the branch name, bot/comment metadata. **What you stash UNREAD until 1b:** the PR description body, the linked ticket's description/comments, linked design docs — anything that *argues the reason for the change*. Fetch them (so 1b is just a read, not another round-trip), but do not read their content yet. If a commit message body is a full rationale paragraph, treat it as WHY-prose and stash it too; one-line subjects are fine to read.

> Why: the cold read at 0.5 only works if you haven't yet absorbed "what this is supposed to achieve." Reading the PR body now defeats the entire point of v5.

**Chase references (one hop, breadth-first) — fetch, stash WHY-prose UNREAD:** Jira key (`[A-Z]+-\d+`) → `jira` skill (fetch, stash description unread). Confluence URL → `confluence` skill (fetch, stash unread). GitHub issue/PR link → `gh ... view` (stash body unread). Repo file → `Read` (code files are fine to read; design docs stash). External URL → `WebFetch` (stash unread). Auth-walled link → ask user to paste (defer the paste to 1b). Recurse a second hop only if a linked ticket/doc is clearly load-bearing for WHY; else note `unfetched: <url>` and stop.

**Load the repo's own written rules (for the Stage 3.5 convention probe).** Read the project's instruction/convention files — the agent-instructions file(s) (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` and equivalents, repo root AND the touched module's dir, since a nearer file overrides root), any `CONTRIBUTING`/style doc, and the linter/formatter config the changed files are subject to. Extract only **machine-checkable, project-specific hard rules** into a short checklist, quoted verbatim with source — bans and concrete thresholds (e.g. a ban on referencing ticket keys in code comments, banned words, a max line width, a branch-name pattern, a required wrapper/annotation on a given construct). Skip aspirational prose ("prefer clear names") — generic taste is a Stage-4 nit at most, not a convention check. If no convention doc is reachable, say so; never invent rules. (Reading convention files is fine — they're rules, not the change's WHY.)

Never fabricate. If you couldn't read it, say so.

**Bots: enumerate, do NOT read content.** Record *that* bots reviewed and how many comments each left — never what they said. Reading their findings now would anchor you. Stash deep-links; open them in Stage 5.

Fetch the comment metadata:
```bash
gh api repos/{owner}/{repo}/pulls/{n}/comments --paginate
gh api repos/{owner}/{repo}/issues/{n}/comments --paginate
gh pr view <url> --json reviews,comments
```
Capture each comment's `html_url` for the Stage 5 deep-link. **Bot detection** (generic, err toward tagging): `author.is_bot == true`; REST `User.type == "Bot"`; login matches `*bot` / `*-ai` / `*-reviewer` / `*-pull-request-reviewer`; well-known set (`claude`, `coderabbitai`, `copilot-pull-request-reviewer`, `bito-bot`, `codium-ai`, `sourcery-ai`, `qodo-merge-pro`, `github-actions`); or `authorAssociation == "NONE"` with review-shaped output. Record login + counts only.

If you accidentally read a bot finding (or the PR-body WHY) while skimming, name it — in Stage 5 for bots, in Stage 1b for the WHY-prose — rather than pretending you didn't.

**Output:**
```
## Context-1a (Stage 1a)
TL;DR: <what was fetched; WHY-prose stashed unread>
- Source / Diff scope (N files, +X/-Y) / Author + branch / Commit subjects (1-line each)
- WHY-prose stashed UNREAD: <PR body | ticket PROJ-123 desc | design doc url>
- Prior bot reviews: <login: N inline + M summary, latest YYYY-MM-DD — COUNTS ONLY> OR none
- Convention sources: <instruction file(s) + linter — N hard rules loaded> OR none reachable
- Unreachable / asked about: ...
```

---

## Stage 0.5 — Cold code read (hard gate)

Read the diff and articulate **what changed and what it achieves — from the code alone.** You have NOT yet read the PR description or ticket prose, so this reading can't be primed by the stated intent. This is the un-anchoring that makes Stage 2.7 meaningful.

This is the main thread reading the code — fast, no subagent. The blindness here is *temporal* (you haven't read the WHY-prose yet), not delegated. Describe, don't yet critique:

- **What changed** — files, functions, the mechanical delta. One or two sentences.
- **What it achieves** — the *behavioural* effect, inferred purely from the code. "Adds a `region` field to the event payload and routes events tagged `eu` to a second queue." Not "implements the multi-region ticket" — you don't know about the ticket yet.
- **Inferred intent** — your best read of *why* someone wrote this, from the code only. Lock it. This is the claim Stage 2.7 will test against the stated WHY.

Stay descriptive. No severity, no findings, no "this is wrong" — those come later and would be premature before WHY locks. If the code is genuinely unreadable in isolation (heavy domain context needed), say so and note which parts you're unsure of — that uncertainty itself feeds Stage 2.7.

**Output:**
```
## Cold read (Stage 0.5)
TL;DR: <what the code does, from code alone — one line>
- What changed / What it achieves (behavioural) / Inferred intent (locked) / Parts unclear from code alone
```

---

## Stage 1b — Context: now read the stated WHY (hard gate)

Now read the prose you stashed at 1a — the PR description body, the linked ticket's description and comments, the design docs, any pasted auth-walled content. This is the *stated* WHY: what the author and the ticket claim the change is for.

Read it straight. Don't yet reconcile (that's 2.7) and don't yet five-whys it (that's 2). Just absorb what's claimed, quoting the load-bearing lines.

**Output:**
```
## Context-1b (Stage 1b)
TL;DR: <stated purpose in one line, per the prose>
- Stated WHY (quote from PR body / ticket) / Linked ticket(s) / Linked docs / Referenced files
- Anything in the prose that surprised you vs the cold read (flag, don't resolve yet)
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
1. Extract WHY₁ — quote verbatim from PR/commits/ticket/comments (the prose you read at 1b). No paraphrase.
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

## Stage 2.7 — Code-vs-WHY reconciliation (HARD HALT on mismatch)

You now hold two independently-formed things: the **cold read** (Stage 0.5 — what the code does, formed before you knew the stated reason) and the **locked WHY** (Stage 2 — what the change is *for*, per the ticket/PR). Put them side by side and ask one question:

> **Does what the code actually does match what the ticket/PR says it's supposed to do?**

Because the cold read was formed *before* you read the WHY-prose, this comparison is honest — your reading of the code wasn't bent to fit the stated intent. A divergence here is the highest-value thing a review can surface: the code and its own ticket disagree.

**Compare on:**
- **Scope** — does the code do *less* than the WHY claims (under-delivers — a stated goal not actually implemented)? *more* than the WHY claims (scope creep — behaviour the ticket never asked for, possibly unreviewed elsewhere)?
- **Direction** — does the code achieve something *different from or contradictory to* the stated goal (the ticket says "rate-limit per user," the code rate-limits per IP)?
- **Silent behaviour** — does the code change behaviour the WHY never mentions (a side effect, a touched code path, an altered default) that a reviewer trusting the ticket would never look for?

**Verdict of this stage:**
- **MATCH** — code does what the WHY says, no unstated behaviour of consequence → state it, proceed to 2.5.
- **MISMATCH** — *any* divergence on scope, direction, or silent behaviour → **HARD HALT. Do not proceed.** Surface to the human with both readings shown, and ask which is right. Always flag; never rationalise the gap away or pick a side silently.

> This is a hard gate by the user's explicit rule: *any* code-vs-stated-WHY divergence stops the review and goes to the human. The reviewer's job here is to *detect and surface*, not to decide whether the code or the ticket is "more correct" — that's the human's call. A mismatch is not automatically a defect (the ticket may be stale, or the extra behaviour may be desired-but-undocumented), but it is *always* worth the human's eyes before the review continues.

**Halt output (when MISMATCH):**
```
## Reconciliation (Stage 2.7) — ⛔ HALT: code-vs-WHY mismatch
Cold read said the code does:   <from Stage 0.5>
Stated WHY says it should do:    <from Stage 2>
Divergence: <scope under | scope over | direction | silent behaviour> — <one sentence>

I'm halting the review here per the hard-gate rule. This is a divergence between what
the code does and what the ticket/PR claims, and it needs your eyes before I go on.
Which is right — is the code doing the intended thing and the ticket is stale/incomplete,
or does the code diverge from the intent? <assumption-voiced ask if you have a lean>
```

**Proceed output (when MATCH):**
```
## Reconciliation (Stage 2.7)
TL;DR: MATCH — code does what the WHY states; no unstated behaviour of consequence.
- Cold read vs stated WHY: aligned on <scope / direction / behaviour>
```

---

## Stage 2.5 — Blind independent solve (conditional gate)

Before critiquing the author's approach, solve the problem yourself — *blind*, so the diff doesn't anchor you. A reviewer who reads the implementation first evaluates *the author's solution*; one who solves it first evaluates *the problem*, then compares. (You read the diff at 0.5 — but to *describe* it, not to design against it. The subagent below has read nothing, which is the real blindness.)

You can't un-see a diff you've read. So delegate the blind solve to a **fresh subagent that never sees the diff and can't fetch it.**

**Fires when EITHER (be eager):**
- **Net-new logic** — new behaviour, algorithm, data flow, or contract. (Pure-mechanical — rename, config, dep bump, test-only, generated — does NOT fire on this axis at any size.)
- **Size** — changed-files ≥ 5 OR `additions + deletions` ≥ 150.

**Skips** when small AND mechanical — go to Stage 3. State it: `Blind-solve: skipped (3-file rename, mechanical).`

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

With WHY locked, code-vs-WHY reconciled, and an independent solution in hand, judge whether the author's approach is the right shape — by comparing to your blind solve, not in a vacuum.

- **Minimum solution.** Smallest change resolving the bedrock WHY, in one sentence. Compare actual diff to it; every line beyond demands a tie to WHY or it's speculative.
- **Approach comparison** (drives the Fit TL;DR):
  - **Matches** your blind solve → strong signal the shape is right.
  - **Better** than yours → say so specifically; praise-worthy (author saw what your solver didn't).
  - **Worse / differs** → highest-value finding a review produces. Name what your approach does that theirs doesn't; decide: real defect, or two valid ways? Worse on a Stage-3.5 risk axis (irreversible, corrupting, untimed) = blocker. Worse on taste only = nit.
  - Be honest when theirs is better. The blind solve un-anchors you; it isn't a claim your design is the standard.
- **Naming-honesty.** For each name implying a contract — `version`, `validator`, `serializer`, `cache`, `lock`, `transaction`, `idempotent`, `registry`, `retry` — verify the implementation delivers the contract. A `get_prompt_version` returning a content hash is mis-named: the name is the defect.
- **Entanglement audit.** When the PR bundles concerns, **don't default to "split it."** Ask per extra concern: cost to add now (lines, coupling, write-amplification, deploy blast)? cost to NOT add now (named harm, named correctness break, named follow-up made harder)? **Load-bearing** (feature unsafe without it — e.g. an endpoint returning privilege-sensitive payloads without its access-control check) → don't split; land the dependency in a prior PR or harden both together. **Accidental** (different blast radius, revert path, owner) → split.
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
3. **Untimed external calls.** Every 3rd-party HTTP call, RPC / cross-service call, external DB query — does it set a timeout? An unbounded wait hangs the caller and exhausts the request budget / connection pools. Missing timeout on a hot request path = 🔥.
4. **Performance / N+1.** Per-item queries in a loop, missing batch, O(n²) on a request path. 🔥 on a `prod-critical` request path; lifted for a one-time `throwaway-script` (state it: "N+1 acceptable — one-time backfill").
5. **Cohesion / coupling / LoB.** Is the logic where a reader would look for it, or scattered? New coupling between modules that shouldn't know each other? Respect locality of behaviour — coincidental duplication beats wrong coupling; don't flag DRY violations that are actually correct locality.
6. **Boy-scout / missed caveats.** A non-obvious constraint left uncommented, a WHY the next reader trips on, an easy leave-it-better skipped. 💭 nits, never blockers — but naming them is part of a real review.

**Test files** — distinguish *call-shape* assertions from *behaviour* assertions. Mocking a dependency then asserting how the code called the mock proves call shape, not that the real dependency does anything useful. If the change's whole point is the real dependency's behaviour (a logger migration whose value is structured output, a serialiser swap whose value is wire format), a fully-mocked test can't prove it works — coverage-illusion finding; stub a smoke test exercising the real dependency.

**Evidence beyond the diff** (run when triggered): **build/type gate** — if CI is stale/unknown on typed code, run `mypy`/`tsc --noEmit`/`cargo check`; if you can't run it, require green CI in the verdict. **Blast radius** — on any renamed/removed/signature-changed exported symbol, `grep -rn "<symbol>"` (or LSP) to count callers; outside-diff callers not updated = 🔥 with a stub diff; cite the command.

**Reach — what did this change OBLIGATE that's not in the diff?** Adversarial probes above ask "does the diff work?"; this asks "did the change *finish*?" Trust the happy-path correctness the author clearly handled — spend the budget here. Fires whenever the diff **adds a member to a closed set** (enum value, map/dict key, status constant, kind/type discriminator, schema enum entry, new `case`/branch) OR **changes a consumed surface** (response field, payload/event key, stored attribute, config key). The edited symbol keeps its name, so Blast-radius won't fire — yet every consumer that switches / looks-up / validates / whitelists over that set is now silently missing the new member, and those consumers are *outside the diff by construction* (the author didn't need to touch them, which is why they break).

You've read the diff, the WHY, and the author's justification — so judging Reach in the main thread inherits "the author said it's cosmetic." Like the Stage 2.5 blind solve, un-anchor it: **when the set has ≥ a handful of consumers OR is consumed across a language / package / service boundary, dispatch a fresh subagent that sees ONLY the consumer side** — give it the set's name, the new member's value, and the ban *you may NOT read the author's diff or its reasoning; grep every consumer of this set and report which mishandle the new member.* It judges each consumer cold, can't inherit the author's framing. For a trivially-scoped set (one or two in-module consumers) an inline `grep`/LSP-search is fine — state which path you took.

Either way: search the new member and its existing siblings across the **whole codebase — including other languages, packages, or services that consume the same set** (a back-end enum often drives a separate front-end map; cite the command); a consumer the diff didn't touch that mis-handles the new value = 🔥, that silently skips/defaults = ⚠️, cosmetic = 💭 — each written as a stub diff. **An in-diff "alignment" unit test does NOT discharge this** — a test inside the owning component can't observe a consumer in another. State the result even when clean: `Reach: <member> — N consumers searched (subagent | inline), all safe.`

**Convention compliance** (only if Stage 1a loaded ≥1 rule). Run the diff's *added* lines against the loaded checklist. Each hit is a Stage-4 Issue (usually ⚠️/💭) with the rule quoted verbatim + source, so the author sees it's the *project's* rule, not your taste. In scope = a rule the repo wrote down; out of scope = generic style with no rule behind it. This is not "lint the PR" — only the loaded hard rules, nothing aspirational.

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

Now, and only now, open the deep-links stashed in Stage 1a and read what bots and other humans said. Your findings are locked, so anything you adopt is genuinely cross-checked, not inherited.

Bot reviews are **leads, not facts** — two LLMs agreeing about a third LLM's code is one model talking to itself. For each comment, pick one:

- **Caught something I missed** → verify against the code yourself; if real, add a new Stage 4 issue marked 🤖 with a `Prior bot:` line.
- **Also found it** → add 🤖 + `Prior bot:` deep-link to your existing finding. Independence preserved — you found it first, blind.
- **Wrong, my findings refute it** → say so with reasoning. High value: *"CodeRabbit flags the N+1 in `backfill.py` — but per Stage 1.5 this is a one-time throwaway against test data, so it's fine. Bot lacks the stakes context."*

**Per-finding bot marker.** Every Issue header carries a second emoji after the severity: `🤖` (a bot flagged it) or `✨` (independent catch) — `### 🔥 ✨ 2. Title`. Header marker and the `Prior bot:` line must agree. Pick one line shape:
- `**Prior bot:** 🤖 already flagged by <login> ([inline](url)). Reinforced because <prod-safety / blocker / bot's diff insufficient>.`
- `**Prior bot:** 🤖 partially flagged by <login> ([inline](url)) — caught <X>, missed <Y> (added here).`
- `**Prior bot:** 🤖 flagged by multiple bots (<a>, <b>) ([a](url-a), [b](url-b)).`
- `**Prior bot:** ✨ not raised by any bot review.`

Use the exact login captured in Stage 1a (not a hardcoded "claude-bot"). Because every finding was formed before reading a bot, the ✨ markers are *true* independence, not a claim.

**Bot findings not promoted to Issues** (only when ≥1 dropped) — one line each, forces an explicit decision:
```
- 🤖 <login> on <file:line> — "<summary ≤80 chars>" — Dropped because: <already in Acknowledged trade-offs | verified, bot is wrong | out of scope/WHY-locked | duplicate of Issue N | bot misread the diff>.
```

---

## Verdict + What's good

**Verdict** — one of: `KILL` (premise broken) · `RESCOPE` (WHY real, wrong slice) · `TRIM` (right WHY+shape, overbuilt — name what to cut) · `SHIP-WITH-NITS` · `SHIP`. One-line reason, conditioned by stakes tier. Blockers listed separately from nice-to-haves (blockers = every 💀 and 🔥). **Decline (KILL/RESCOPE) when any named risk is true and unmitigated** at the tier: irreversible prod mutation with no rollback, possible data corruption, unbounded external wait on a request path. (A Stage-2.7 HALT supersedes all of this — if reconciliation halted, the review never reached a verdict; resolve the mismatch with the human first.)

`Bot overlap:` line after the reason: `N of M issues flagged by bots (🤖); K independent (✨).` If overlap = 100%, the text must say the review only confirms bots, no independent catches.

**What's good** — *after* the verdict (so praise doesn't soften the Issues pass). Specific, named, snippet-shown, severity-tagged (**🌟** exemplary steal-this-pattern · **✨** thoughtful non-obvious · *none* ordinary good). Praise non-obvious decisions and WHY-comments (a comment naming a real constraint — "library X isn't thread-safe here, so we serialize" — not one restating the code). Credit the author where their approach beat your blind solve. Show 2–8 lines of the actual snippet. If you can't find anything specific to praise, that's a verdict signal — don't fake it. Conformance to a generic style guide isn't praise; "mirrors existing pattern" isn't automatically praise — the pattern may be a workaround copied twice.

**Output shape:**
````
## Context-1a (Stage 1a)
TL;DR: <what fetched; WHY-prose stashed unread>
- Source / Diff scope / Author+branch / Commit subjects
- WHY-prose stashed UNREAD: ...
- Prior bot reviews: <login: counts, latest date — content unread> OR none
- Convention sources: <instruction file(s) + linter — N hard rules loaded> OR none reachable
- Unreachable / asked about: ...

## Cold read (Stage 0.5)
TL;DR: <what the code does, from code alone>
- What changed / What it achieves / Inferred intent (locked) / Parts unclear

## Context-1b (Stage 1b)
TL;DR: <stated purpose per the prose>
- Stated WHY (quote) / Linked ticket(s) / Linked docs / Surprises vs cold read

## Stakes (Stage 1.5)
TL;DR: <tier> — <what relaxes>
- Tier / Evidence / Relaxed / Still-enforced

## WHY (Stage 2)
TL;DR: Doing → <benefit>. Not doing → <cost>.
- WHY₁ (quote) / WHY₂ / WHY₃ / Bedrock type / Status
- <assumption-voiced ask if unclear>

## Reconciliation (Stage 2.7)
TL;DR: <MATCH | ⛔ HALT: mismatch>
- Cold read vs stated WHY: <aligned | divergence — show both readings>
  (if HALT, the review STOPS here pending human resolution)

## Blind solve (Stage 2.5)
TL;DR: <fired | skipped (reason)>
- Problem statement (confirmed) / Subagent approaches / Subagent's pick

## Fit (Stage 3)  -- only if LOCKED + reconciliation MATCH
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

- **Reading the PR-body/ticket WHY before the cold code read.** The whole point of v5 — read the stated reason first and your reading of *what the code does* bends to fit it, so a code-vs-ticket mismatch never surfaces. Fetch the prose at 1a, read it at 1b.
- **Rationalising away a Stage-2.7 mismatch.** Any code-vs-stated-WHY divergence is a HARD HALT to the human — don't pick a side, don't decide the ticket is "obviously stale," don't proceed. Surface both readings and ask.
- **Reading bots before Stage 5.** Read their content early and you inherit their framing.
- **Reading the diff to *design against it* before the blind solve** (when it fires). The 0.5 cold read *describes*; designing your own solution from the diff anchors you on the author. The blind solve is delegated to a subagent for exactly this reason.
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
- **Proving the happy path instead of sweeping the reach** — burning the review re-verifying math / guards / normalisation the author clearly handled, while never searching which consumers of a new enum value / map key / discriminator went unswept. The consumer the author couldn't see is the one the diff-bound reviewer also can't see — search it (across languages/packages), un-anchored, before the verdict.
- **Scoring a comment by your own taste when the repo wrote a rule** — praising or passing a comment without checking it against the project's loaded conventions. Convention compliance ≠ comment quality; run the Stage-1a-loaded rules.
- **Importing bot consensus** — "all bots green" is bot-to-bot conversation, not evidence. Derive findings yourself.
- **Silent bot overlap** — raising what a bot raised without the `Prior bot:` line; reader can't tell you read them.
- **Skipping praise** — every review ends with specific named What's good, even tough verdicts. Generic praise ("nice work") is worse than none.
- **Rubber-stamping unknown CI** — no SHIP without confirming CI green or running the build when CI is stale; if unknown, say so.

## Parallelism

One reviewer holds the whole diff — the stage gates require it; parallel reviewers on file-slices break the WHY lock, the cold-read/reconciliation, and the entanglement audit. When the diff is large (≥8 files OR ≥400 lines) or touches ≥2 of {access control, DB migrations, public API contract, infra/CI, payment/PII}, or the user opts in ("thorough", "deep review", "security review", "use agents"), you may spawn **dimension-agents that each hold the whole diff with a single lens** (security / performance / tests / migration / API-contract) feeding Stage 4 only — the main agent runs Stages 1a–3 + 5 and writes the verdict. Log the trigger in the Context TL;DR. **Do not confuse these with the Stage 2.5 blind-solve subagent** — dimension-agents read the whole diff; the blind solver reads none of it.
