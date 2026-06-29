---
description: Summarize work done in a conversation branch + give the pre-branch session a reproducible validation recipe
argument-hint: [branch session id or short note, optional]
---

You are being run at the moment a conversation BRANCH is being folded back. The user is (or soon will be) back in the PRE-branch session and needs to trust what the branch did. Your job: produce a handoff that the pre-branch "past-you" can VERIFY independently, not just believe.

Output exactly two parts.

## Part 1 — What changed in this branch

Bullet list, terse. Group by artifact (PRs, commits, deploys, files, tickets, docs). For each item give the concrete identifier (PR number, commit sha, branch name, run id, file path, jira key) — never a vague "fixed the thing". $ARGUMENTS may name the branch/session; fold it in if given.

## Part 2 — Validation recipe (the important half)

For EVERY claim in Part 1 that is verifiable, emit a copy-pasteable check the resumed agent can run to re-derive ground truth WITHOUT trusting this summary. Split claims into:

- **VERIFIABLE NOW** — has a command that proves it. Give the command + what output confirms it.
- **NOT INDEPENDENTLY VERIFIABLE** — flag explicitly (e.g. "a reviewer's intent", "a design choice"). Don't pretend a check exists.

Use these check patterns (adapt to the actual claims; only emit checks for claims that were actually made):

**Commits / branch state**
```bash
git fetch origin -q
git log --oneline origin/<branch> -15          # commits claimed present
git show --stat <sha>                            # a specific change landed
git diff origin/main...origin/<branch> --stat    # net branch effect
```

**PR state / merge / review**
```bash
gh pr view <N> --repo <owner/repo> --json state,mergedAt,reviewDecision,mergeStateStatus
gh pr list --repo <owner/repo> --state all --search "<query>" --json number,state,mergedAt
```

**Deploy actually happened (ground truth = deployed code, NOT run-success)**
```bash
# live deployed commit per function — compare to claimed sha
aws lambda get-function-configuration --profile <prod-read|test-write> --region ap-southeast-2 \
  --function-name <fn> --query 'Environment.Variables.GIT_COMMIT_SHA' --output text
git merge-base --is-ancestor <claimed-sha> <deployed-sha> && echo included || echo NOT
# workflow run conclusion (weaker signal — deploy step can pass while tests fail)
gh run view <run-id> --repo <owner/repo> --json status,conclusion,displayTitle
```

**Runtime/import sanity (layer, packaging, module-load claims)**
```bash
# invoke with junk payload; business error = code ran past imports, import error = broken
aws lambda invoke --profile test-write --region ap-southeast-2 \
  --function-name <fn> --payload "$(printf '{}' | base64)" /tmp/out.json \
  --query 'FunctionError' --output text
head -c 300 /tmp/out.json   # ModuleNotFoundError/ImportModuleError = FAIL; KeyError/business = PASS
```
NOTE: prod-read CANNOT invoke (ReadOnly) — for prod, read post-deploy logs for import errors instead of invoking.

**File edits / removals**
```bash
git show origin/<branch>:<path>            # content is as claimed (or: fatal = removed)
git log --oneline -3 origin/<branch> -- <path>
```

**Jira**
```bash
jira issue view <KEY>                       # state/sprint/parent/label as claimed
```

End Part 2 with a one-line **"Trust boundary"**: which Part-1 claims the resumed agent must take on faith because nothing reproducibly proves them.

Keep it tight. The resumed agent should be able to paste the checks and confirm the branch's work in under a minute.
