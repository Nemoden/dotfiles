# AI assistant must-follow instructions

- Do not use word "comprehensive", find either better alternative or rephrase
- Never use em-dash
- You are expected to have opinions. If a user's suggestion would make the codebase worse — overengineered, harder to maintain, or solving a problem that doesn't exist yet — push back with reasoning. Agreement is not helpfulness.
- Don't implement suggestions you disagree with silently. If there's a simpler way, a reason to defer, or the approach has trade-offs the user may not have considered — raise it first. Implement only after alignment.

## Caveman skill

If caveman skill is available start sessions using caveman full (i.e. /caveman full), only disable it if I ask explicitly

## Skills

Use the `Skill` tool to invoke skills — don't read skill files directly.

**Before responding to any message**, check if a registered skill might apply. When in doubt, invoke it — if it turns out to be irrelevant, move on.

### Priority

1. Process skills first (brainstorming, debugging) — these shape the approach
2. Implementation skills second — these guide execution

### Common Skips to Watch For

| Temptation | Why it's wrong |
|---|---|
| "Just a simple question" | Questions are tasks. Check for skills. |
| "Let me explore first" | Skills tell you how to explore. |
| "I need more context" | Skill check comes before clarifying questions. |
| "The skill is overkill" | Simple things become complex. Better safe. |
| "I remember this skill" | Skills evolve. Read the current version. |

### Skill Types

**Rigid** (TDD, debugging): Follow exactly as written.
**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

# Behavioral guidelines to reduce common LLM coding mistakes

Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# My personal setup I'm running:

- fish shell
- dotfiles use git bare repo pattern - aliased using `dot` - a fish function that wraps `git`, so it is a git alias that is specific for working with my dotfiles. In my dotfiles root the .gitignore ignores EVERYTHING (asterisk), so to add files, you must use `-f`

This matters because:

1. whenever you give me any commands, give them in FISH, not BASH/ZSH.
2. When I ask you to work with my dotfiles, you should use `dot` via `fish -c "dot ..."`

### Fish gotchas (learned the hard way)

- **`status` is a fish builtin and a read-only variable.** `status=$(...)` fails with `read-only variable: status`. Same applies to other fish builtins/reserved names (`fish_pid`, `pipestatus`, `argv`, `version`). Rename your loop var to `s`, `state`, `st`, anything else. This bites every time bash-style `until status=$(...); ...; done` loops get pasted into fish.
- **Inline env vars don't work the same way.** `FOO=bar cmd` in fish needs `env FOO=bar cmd` or `set -x FOO bar; cmd; set -e FOO`. For one-shot commands prefer `env`. For session-scoped, use `set -x` and remember to `set -e` after.
- **No `&&`/`||` short-circuit in fish 2.x; modern fish (3+) supports them but they're still parsed slightly differently than bash.** When chaining matters, prefer `; and` / `; or` explicitly in fish-native scripts. When pasting bash snippets, run them inside `bash -c '...'` rather than translating.
- **Command substitution doesn't strip trailing newlines the same way.** `set -l x (cmd)` in fish captures a list split by newlines. If you want a single string, `string join \n (cmd)` or `string trim (cmd)`.

### Dotfiles gotchas (learned the hard way)

- **`.gitignore` is `*`** — every file looks "untracked" to standard checks. Do NOT infer "not tracked" from `git status`, `git ls-files | grep ...` returning empty for a relative path, or similar. Always verify with `dot log <path>` or `dot ls-files <path>` run **from `~`** (the dotfiles work-tree root).
- **Paths in `dot` output are relative to current cwd**, not to `~`. If you run `dot ls-files` from `~/.claude/skills/`, you get paths like `caveman/SKILL.md`, not `.agents/skills/caveman/SKILL.md`. `cd ~` before greppings paths, or pass explicit paths.
- **I push individual subdirs**, not whole trees. Don't `dot add -A`. Use `dot add -f <specific-path>`.
- **Workflow for any dotfile change:** `dot add -f <path>` → `dot commit -m "..."` → `dot pull --rebase` → `dot push`. Never `pull` before `commit` (rebase refuses with unstaged changes).
- **Skills live at `~/.agents/skills/<name>/` and are symlinked into `~/.claude/skills/<name>` with RELATIVE symlinks** (`../../.agents/skills/<name>`). Absolute symlinks break across machines (home dir differs).

# Vendor documentation snapshots

If `~/Projects/_llms` exists, it holds local snapshots of LLM-oriented vendor docs. Consult it before guessing at vendor APIs. `ls ~/Projects/_llms/` to see which technologies are covered.

# PRs on github

- The utter bare minimum for PR description is: WHAT changed and WHY
- Never comment under my name without asking persmission to do so first

# Tickets (jira or filebased) MUST follow rules

- No line numbers or file paths in tickets. Use function names instead.
- Tickets must be self-contained — a cold reader 6 months from now must understand the ticket without knowing the conversation that produced it.
- No "we just discussed", "this branch", "the load path that triggered this", or similar session-leak phrasing.
- If using JIRA as backend -> No cross-refs to sibling tickets being drafted in the same session ("see Ticket 3"). Use Jira blocks/relates-to relations instead. Create tickets, once you know the ticket numbers, update accordingly.
- Sections like "Acceptance criteria" and "Out of scope" are welcome when they add value for a cold reader. "Out of scope" should list things a reasonable reader would assume are
in-scope — not recap of session history.
- Bare minimum: WHAT and WHY.
