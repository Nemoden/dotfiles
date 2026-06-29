---
description: Summarize work from a separate session + give a reproducible validation recipe to confirm it
argument-hint: [session id or short note, optional]
---

A separate Claude session did work this conversation was NOT part of. The user is pasting this into that other session (often an earlier one they've rewound to) so it can pick up — and TRUST — what was done elsewhere. The reader has none of that session's context and must be able to VERIFY the work, not just believe it.

Frame everything from the reader's standpoint: the work happened in ANOTHER session, not here. Never say "this branch" / "this session did X" — to the reader, it's external work. Say "the other session" / "was done" / name the session id ($ARGUMENTS) if given.

Produce two things, no "Part 1/Part 2" labels — just a short header for each.

### Work done elsewhere

Bullet list, terse. Group by artifact (code changes, PRs/MRs, commits, deploys, files, tickets, docs — whatever it produced). Every claim carries a concrete identifier (PR/MR id, commit sha, branch name, run id, file path, ticket key, container/service name) — never a vague "fixed the thing".

### How to verify it

For EVERY claim above that is verifiable, give a copy-pasteable check that re-derives ground truth WITHOUT trusting this summary.

**Do NOT assume a toolchain.** The reader's repo may use gh, gitlab, aws, gcloud, kubectl, local docker, make, a bespoke script, or none. Before writing checks, look at how the reader's project actually does things (its README/CLAUDE.md, the commands already used in its conversation, its CI config, its task runner) and phrase each check in THAT vocabulary. The notes below are the THINKING, not a required tool list — translate them.

Build each check from the principle, not a fixed command:

- **A claim is verifiable when ground truth lives somewhere queryable** — version control, a registry, a running process, a deployed artifact, an API, a file on disk. Point the check at the ground-truth source, not at whatever *reported* success.
- **Prefer the strongest signal.** "The deploy job went green" is weak (a step can pass while the result is wrong). "The deployed artifact carries commit X" / "the running thing answers correctly" is strong. Reach for the artifact/runtime over the job log.
- **Re-derive, don't echo.** A good check would catch the summary being WRONG. If it just restates the claim, it proves nothing.
- **Name the expected output.** Say what result confirms the claim vs refutes it.

Split the claims into:

- **Verifiable now** — has a concrete check in the reader's tooling. Give the command + the output that confirms.
- **Not independently verifiable** — flag explicitly (a reviewer's intent, a subjective design choice, an external state unreachable from the reader's repo). Don't invent a check that doesn't really prove it.

Illustrative thinking (translate to the actual stack — these specific tools may not apply):
- *code/commit landed* → ask version control what's on the branch and what a change touched (`git log`/`git show`/`git diff` — near-universal).
- *PR/MR merged or reviewed* → query the forge's API/CLI for state, not memory.
- *something deployed* → read the commit/version baked into the live artifact, compare to the claimed one; weaker fallback is the deploy job's conclusion.
- *code runs / imports resolve / no startup break* → exercise it with harmless/malformed input; "failed on business logic" = it loaded, "failed to start/import" = broken. Use whatever invocation path the project supports (local run, container exec, test harness, remote invoke).
- *file added/removed/edited* → read it back from version control at the ref.
- *ticket/doc updated* → query the tracker/doc system for the field as claimed.

End with a one-line **Trust boundary**: which claims the reader must take on faith because nothing reproducibly proves them.

Keep it tight — the reader should confirm the external work quickly, using tools that actually exist in its environment.
