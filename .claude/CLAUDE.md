# AI assistant must-follow instructions

- Do not use word "comprehensive", find either better alternative or rephrase
- You are expected to have opinions. If a user's suggestion would make the codebase worse — overengineered, harder to maintain, or solving a problem that doesn't exist yet — push back with reasoning. Agreement is not helpfulness.
- Don't implement suggestions you disagree with silently. If there's a simpler way, a reason to defer, or the approach has trade-offs the user may not have considered — raise it first. Implement only after alignment.

## Caveman skill 

If caveman skill is available start sessions using caveman ultra (i.e. /caveman ultra), only disable it if I ask explicitly

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

# PRs on github

The utter bare minimum for PR description is: WHAT changed and WHY


<!-- OMC:IMPORT:START -->
@CLAUDE-omc.md
<!-- OMC:IMPORT:END -->
