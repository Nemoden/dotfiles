---
description: Catch up on work done in a conversation branch + give a reproducible validation recipe to confirm it
argument-hint: [branch id or short note, optional]
---

Work was done in a separate branch of THIS conversation (forked via `/branch`). Bring the reader up to date on it and let them VERIFY it independently — not just trust it.

Start by printing the branch id ($ARGUMENTS if given, else say it's unknown).

Produce two sections:

### Work done in the branch

Terse bullets, grouped by artifact (commits, PRs/MRs, files, deploys, tickets, docs). Every claim carries a concrete identifier (commit sha, PR id, branch name, file path, ticket key) — never a vague "fixed the thing".

### How to verify it

For every verifiable claim, give a copy-pasteable check that re-derives ground truth WITHOUT trusting this summary. Principles:

- Point the check at the ground-truth source (version control, registry, running process, deployed artifact, API, file on disk) — not at whatever reported success.
- Prefer the strongest signal: "the artifact carries commit X" beats "the job went green".
- Re-derive, don't echo. A good check would catch the summary being WRONG.
- Name the output that confirms vs refutes.
- Use the reader's actual tooling (its README/CLAUDE.md, the commands already in this conversation, its CI/task runner). Don't assume gh/aws/kubectl/etc.

Split into **Verifiable now** (command + confirming output) and **Not independently verifiable** (intent, subjective choices, unreachable external state — flag, don't fake a check).

End with a one-line **Trust boundary**: which claims must be taken on faith.
