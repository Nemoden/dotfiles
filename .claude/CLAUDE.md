# AI assistant must-follow instructions

- Do not use word "comprehensive", find either better alternative or rephrase
- Do not use word "load-bearing", find either better alternative or rephrase
- HARD RULE: NEVER USE EM-DASH
- HARD RULE: Write technical prose in ASD-STE100: approved words, one idea per sentence, active voice, present tense, one term per concept. This covers chat replies, docs, tickets, PR descriptions and commit bodies. Code, identifiers, file paths, log lines and error text are quoted verbatim and never simplified. Code you write yourself stays plain and short, so a reader gets it without a second pass.
- **The `X is Y, not Z` construct earns its place or goes.** Keep it only when a reader would plausibly have picked Z: `service must be "matters", not "adieu-pool-matters-v001"` names a real wrong answer. Cut it when Z is nobody's guess (`the note is prose, not a schema`) or when the pair is an aphorism dressed as insight (`the asymmetry is about identity, not trust`). Test before writing it: name the reader who would have believed Z. If you cannot, state the positive claim and stop. One per section at most, and never two in a paragraph. This applies to the same shape spelled other ways: `not Z but Y`, `Y rather than Z`, `Z? No. Y.`
- You are expected to have opinions. If a user's suggestion would make the codebase worse — overengineered, harder to maintain, or solving a problem that doesn't exist yet — push back with reasoning. Agreement is not helpfulness.
- Don't implement suggestions you disagree with silently. If there's a simpler way, a reason to defer, or the approach has trade-offs the user may not have considered — raise it first. Implement only after alignment.
- **Never measure code quality in lines.** "File grew to 900 lines", "function is 275 lines", "+125 net lines" are not findings. Measure composability, flexibility, readability, maintainability: can a piece be tested alone, reused, replaced, understood without reading its callers? A 900-line module of independently testable functions beats a 300-line ball of mud. Report line counts only as neutral context when explicitly asked, never as evidence of a problem. Same rule applies when reviewing: a diff is not worse for being larger.

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

## 5. Name the shape — `dict` is worse for LLMs than for humans

**A bare `dict`/`map`/`object` annotation is a dead end for an agent. A named structure is a lookup.**

`record: dict` tells a reader nothing, and tells *me* less than that. I mostly infer a field's meaning by pattern-matching the surrounding code, not by reading a definition — so when the type is `dict`, there is no definition to find and nothing to grep. `record: ShareRecord` puts a symbol at every use site: one hop to the fields, their types, and whatever the docstring warns about. The gain is **retrieval**, not comprehension.

This asymmetry is why it matters more for me than for you: you read a definition once and hold it for the session; I re-derive from whatever is in context on this turn. A name in the signature is what survives that.

Prefer, in order: a real class/struct (`@dataclass`, pydantic model, `TypedDict`, `NamedTuple`, TS `interface`) → a type alias → `dict[str, Any]` + docstring → bare `dict`. Pick the flavour by contract strength (untrusted input → validating model; must-stay-a-dict at runtime → `TypedDict`).

**Docstrings travel; `#` comments don't.** Verified against `pyright-langserver` via `textDocument/hover`: a class documenting its fields in the **class docstring** hovers as the full text; the identical class using a trailing `# comment` hovers as bare `(class) Name`. At runtime, same split — `__doc__` holds the docstring, and is `None` for the comment version. Any tool that reads symbols (LSP hover, `help()`, generated API docs, an agent following a definition) sees one and not the other.

So put non-obvious field knowledge in the **class docstring**, not in trailing comments:

```python
class ShareRecord(t.TypedDict):
    """Row written to the shares table on create.

    Fields whose names don't carry their meaning:

    created_by      Cognito sub, NOT a username or email.
    last_batch_ts   Equal to created_at at create, then moves on every
                    add-items while created_at stays put.
    """
```

Document only the fields whose names lie or hide a constraint (an opaque ID behind a human-sounding name, a field mutated by something outside this code path, a value that doubles as a key seed). `share_id: str` needs nothing — a comment there is restating the code, which the no-comments rule already bans.

**One honest limit:** hovering a *field use* (`r["created_by"]`) returns nothing; the docstring surfaces when the **type name** is hovered — in the signature, the annotation, the import. Verified, same probe. So the payoff depends on the type name being visible near the use site, which is the argument for naming it in the first place.

With an LSP or treesitter in the loop this stops being decoration and becomes the mechanism: the docs arrive with the symbol instead of only when someone chooses to open the defining file. Don't bet on "a better model will just infer it" — a local convention like `created_by` = Cognito sub is not inferable at any capability level. Better inference makes a model better at *using* documented facts, not at guessing undocumented ones.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# My personal setup I'm running:

- fish shell
- dotfiles use git bare repo pattern, wrapped by fish functions that call `git` with an explicit `--git-dir`. In my dotfiles root the .gitignore ignores EVERYTHING (asterisk), so to add files, you must use `-f`
- **TWO dotfiles repos exist. Check both before concluding a file is untracked:**

  | Wrapper | Bare repo | Holds |
  |---|---|---|
  | `dot` | `~/.dot` | public dotfiles |
  | `dotp` | `~/.dotp` | private dotfiles |

  Both are `--work-tree=$HOME`, so the same relative path can live in either. `dot ls-files <path>` returning empty proves nothing on its own — run `dotp status <path>` too. A file staged in the wrong repo is a real mistake, not a cosmetic one.

  **Routing a NEW file: default to `dot`. Use `dotp` when the content is work-specific** — employer URLs, AWS account IDs, internal service or repo names, ticket-tracker projects, tokens, or a skill that only makes sense inside my job. When unsure, ask before the first commit. Moving a file after it reaches a public remote does not unpublish it.

  Both wrappers take the same subcommands, so every dotfiles command below works with either name. Pick the wrapper first, then run the sequence.

This matters because:

1. whenever you give me any commands, give them in FISH, not BASH/ZSH.
2. When I ask you to work with my dotfiles, use the wrapper for the repo the file belongs to, via `fish -c "dot ..."` or `fish -c "dotp ..."`

### Fish gotchas (learned the hard way)

- **`status` is a fish builtin and a read-only variable.** `status=$(...)` fails with `read-only variable: status`. Same applies to other fish builtins/reserved names (`fish_pid`, `pipestatus`, `argv`, `version`). Rename your loop var to `s`, `state`, `st`, anything else. This bites every time bash-style `until status=$(...); ...; done` loops get pasted into fish.
- **Inline env vars don't work the same way.** `FOO=bar cmd` in fish needs `env FOO=bar cmd` or `set -x FOO bar; cmd; set -e FOO`. For one-shot commands prefer `env`. For session-scoped, use `set -x` and remember to `set -e` after.
- **No `&&`/`||` short-circuit in fish 2.x; modern fish (3+) supports them but they're still parsed slightly differently than bash.** When chaining matters, prefer `; and` / `; or` explicitly in fish-native scripts. When pasting bash snippets, run them inside `bash -c '...'` rather than translating.
- **Command substitution doesn't strip trailing newlines the same way.** `set -l x (cmd)` in fish captures a list split by newlines. If you want a single string, `string join \n (cmd)` or `string trim (cmd)`.

### Dotfiles gotchas (learned the hard way)

Below, `<wrapper>` means `dot` or `dotp`. Both accept the same subcommands, so pick the repo first and keep the same wrapper for the whole sequence.

- **`.gitignore` is `*`** — every file looks "untracked" to standard checks. Do NOT infer "not tracked" from `git status`, `git ls-files | grep ...` returning empty for a relative path, or similar. Always verify with `<wrapper> log <path>` or `<wrapper> ls-files <path>` run **from `~`** (the shared work-tree root). Check BOTH wrappers before you call a file untracked.
- **`~/.gitignore` itself is untracked in both repos.** It is a work-tree file, not a committed one. Do not expect `<wrapper> show HEAD:.gitignore` to work, and do not "fix" it by committing it without asking.
- **Paths in `<wrapper>` output are relative to current cwd**, not to `~`. If you run `dot ls-files` from `~/.claude/skills/`, you get paths like `caveman/SKILL.md`, not `.agents/skills/caveman/SKILL.md`. `cd ~` before greppings paths, or pass explicit paths.
- **I push individual subdirs**, not whole trees. Don't `<wrapper> add -A`. Use `<wrapper> add -f <specific-path>`.
- **Workflow for any dotfile change:** `<wrapper> add -f <path>` → `<wrapper> commit -m "..."` → `<wrapper> pull --rebase` → `<wrapper> push`. Never `pull` before `commit` (rebase refuses with unstaged changes).
- **Skills live at `~/.agents/skills/<name>/` and are symlinked into `~/.claude/skills/<name>` with RELATIVE symlinks** (`../../.agents/skills/<name>`). Absolute symlinks break across machines (home dir differs).

# Reference

- My Slack voice model (how I write Slack messages: style rules, lexicon, registers) lives in Notion: page "Kirill's Slack voice model" under the top-level "Reference" page. If the notion skill is available, find it via title search (`query:"Kirill's Slack voice model"`). Use it whenever drafting Slack messages as me.

# Vendor documentation snapshots

If `~/Projects/_llms` exists, it holds local snapshots of LLM-oriented vendor docs. Consult it before guessing at vendor APIs. `ls ~/Projects/_llms/` to see which technologies are covered.

# PRs on github

- The utter bare minimum for PR description is: WHAT changed and WHY
- Never comment under my name without asking persmission to do so first
- **Review comments carry a ```suggestion block whenever the fix is applicable.** Prose says why, the block makes it one click. A comment that describes an edit without offering it makes the author retype what you already worked out.
  - The block replaces **exactly the anchored lines**, so the replacement must carry the file's real indentation, copied from the anchor - not re-typed.
  - Deletion = an **empty** suggestion block. Renders as an empty box; that is correct.
  - It can only edit the **file the comment is anchored to**, and only lines inside the anchor range. A fix spanning a second file (the matching call-site change, the covering test) goes in the same comment as a plain fenced block, and say which file it belongs to.
  - **Not possible on a file the PR does not touch** - GitHub has no diff line to attach to, so such a finding is a top-level PR comment, prose only. Do not fake it with a suggestion on an unrelated line.
  - Multi-line replacement is fine, but a change on a line outside the anchor gets named in prose rather than silently dropped.

# Tickets (jira or filebased) MUST follow rules

- No line numbers or file paths in tickets. Use function names instead.
- Tickets must be self-contained — a cold reader 6 months from now must understand the ticket without knowing the conversation that produced it.
- No "we just discussed", "this branch", "the load path that triggered this", or similar session-leak phrasing.
- If using JIRA as backend -> No cross-refs to sibling tickets being drafted in the same session ("see Ticket 3"). Use Jira blocks/relates-to relations instead. Create tickets, once you know the ticket numbers, update accordingly.
- Sections like "Acceptance criteria" and "Out of scope" are welcome when they add value for a cold reader. "Out of scope" should list things a reasonable reader would assume are
in-scope — not recap of session history.
- Bare minimum: WHAT and WHY.
