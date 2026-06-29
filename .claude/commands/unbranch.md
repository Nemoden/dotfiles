---
description: Summarize work done in a conversation branch + give the pre-branch session a reproducible validation recipe
argument-hint: [branch session id or short note, optional]
---

You are being run at the moment a conversation BRANCH is being folded back. The user is (or soon will be) back in the PRE-branch session and needs to trust what the branch did. Your job: produce a handoff that the pre-branch "past-you" can VERIFY independently, not just believe.

Output exactly two parts.

## Part 1 — What changed in this branch

Bullet list, terse. Group by artifact (code changes, PRs/MRs, commits, deploys, files, tickets, docs — whatever this work produced). For each item give the concrete identifier (PR/MR id, commit sha, branch name, run id, file path, ticket key, container/service name) — never a vague "fixed the thing". $ARGUMENTS may name the branch/session; fold it in if given.

## Part 2 — Validation recipe (the important half)

For EVERY claim in Part 1 that is verifiable, emit a copy-pasteable check that re-derives ground truth WITHOUT trusting this summary.

**Do NOT assume a toolchain.** This repo may use gh, gitlab, aws, gcloud, kubectl, local docker, make, a bespoke script, or none of these. Before writing checks, look at how THIS project actually does things (its README/CLAUDE.md, the commands already run in this conversation, its CI config, its task runner) and phrase each check in THAT vocabulary. The examples below are illustrations of the THINKING, not a required tool list — translate them to whatever the project uses.

Build each check from the principle, not a fixed command:

- **A claim is verifiable when ground truth lives somewhere queryable** — version control, a registry, a running process, a deployed artifact, an API, a file on disk. Point the check at the ground-truth source, not at the thing that *reported* success.
- **Prefer the strongest signal.** "The deploy job went green" is weak (a step can pass while the result is wrong). "The deployed artifact carries commit X" / "the running thing answers correctly" is strong. Always reach for the artifact/runtime over the job log.
- **Re-derive, don't echo.** A good check would catch the summary being WRONG. If the check just restates the claim, it proves nothing.
- **Name the expected output.** Say what result confirms the claim vs refutes it.

Split Part 1's claims into:

- **VERIFIABLE NOW** — has a concrete check in this project's tooling. Give the command + the output that confirms.
- **NOT INDEPENDENTLY VERIFIABLE** — flag explicitly (a reviewer's intent, a subjective design choice, an external state you can't reach). Don't invent a check that doesn't really prove it.

Illustrative thinking (translate to the actual stack — these specific tools may not apply here):
- *code/commit landed* → ask version control what's on the branch and what a given change touched (e.g. `git log`/`git show`/`git diff` — near-universal).
- *PR/MR merged or reviewed* → query the forge's API/CLI for state, not your memory.
- *something deployed* → read the commit/version baked into the live artifact and compare to the claimed one; weaker fallback is the deploy job's conclusion.
- *code runs / imports resolve / no startup break* → exercise it with a harmless/malformed input; "it failed on business logic" proves it loaded, "it failed to start/import" proves it's broken. Use whatever invocation path the project supports (local run, container exec, test harness, remote invoke).
- *file added/removed/edited* → read it back from version control at the branch ref.
- *ticket/doc updated* → query the tracker/doc system for the field as claimed.

End Part 2 with a one-line **"Trust boundary"**: which Part-1 claims the resumed agent must take on faith because nothing reproducibly proves them.

Keep it tight. The resumed agent should be able to run the checks and confirm the branch's work quickly, using tools that actually exist in its environment.
