---
name: tdd
description: Test-driven development with red-green-refactor. Vertical-slice (tracer bullet) discipline — one test → one minimal impl → next. Bans horizontal slicing (all tests then all code). Use when implementing any feature or bug fix, or when user says "TDD this", "red-green-refactor", "write a failing test first".
---

# Test-Driven Development

## Philosophy

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Tests verify behavior through public interfaces, not implementation details.** Code can change entirely; tests shouldn't. Good tests survive refactors because they don't care about internal structure. Bad tests break when you rename a private function — that's the signal they're testing implementation.

## When to use

**Always:** new features, bug fixes, refactors with behavior changes.

**Exceptions (ask user):** throwaway prototypes, generated code, configuration files.

Thinking "skip TDD just this once"? That's rationalization. Stop.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before test? Delete it. Start over. Don't keep it as "reference," don't "adapt" it while writing tests, don't look at it. Implement fresh from tests.

## The Anti-Pattern: Horizontal Slicing

**DO NOT write all tests first, then all implementation.** "Horizontal slicing" treats RED as "write all tests" and GREEN as "write all code."

Produces crap tests:
- Tests written in bulk test *imagined* behavior, not *actual* behavior
- You end up testing data shapes / signatures, not user-facing behavior
- Tests become insensitive to real changes — pass when broken, fail when fine
- You outrun your headlights, committing to test structure before understanding implementation

**Correct: vertical slices via tracer bullets.** One test → one impl → repeat. Each test responds to what you learned from the previous cycle.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### Phase 0 — Plan (before any RED)

When exploring the codebase, use the project's domain glossary so test names and interface vocabulary match the project's language. Respect ADRs in the area you're touching.

Before writing test #1:
- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize — you can't test everything)
- [ ] Identify opportunities for deep modules (small interface, deep implementation)
- [ ] List behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors matter most?"

### Phase 1 — Tracer bullet

Write ONE test that confirms ONE thing end-to-end:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This proves the path works end-to-end. Now you have a working slice.

### Phase 2 — Incremental loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

Rules:
- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### Phase 3 — Refactor

**After all tests pass.** Never refactor while RED.

Look for:
- Extract duplication
- Deepen modules (move complexity behind simple interfaces)
- Apply SOLID where natural
- What new code reveals about existing code
- Run tests after each refactor step

## Red-Green-Refactor in detail

### RED — Write a failing test

One behavior, one test, clear name, real code (no mocks unless unavoidable).

<Good>
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing.
</Good>

<Bad>
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests mock not code.
</Bad>

### Verify RED — watch it fail

**Mandatory. Never skip.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test fails (not errors)
- Failure message matches what you expected
- Fails because feature is missing (not because of a typo)

**Test passes immediately?** You're testing existing behavior. Fix the test.
**Test errors out?** Fix the error, re-run until it fails *correctly*.

### GREEN — minimal code

Simplest code to pass the test. No options-bag, no extra params, no "while we're here" improvements.

<Good>
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
</Good>

<Bad>
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: { maxRetries?: number; backoff?: 'linear' | 'exponential'; onRetry?: (n: number) => void }
): Promise<T> { /* YAGNI */ }
```
Over-engineered.
</Bad>

### Verify GREEN

**Mandatory.**

Confirm:
- Test passes
- Other tests still pass
- Output is pristine (no warnings/errors)

**Test fails?** Fix code, not test.
**Other tests fail?** Fix now.

### REFACTOR

Only after GREEN. Remove duplication, improve names, extract helpers. Keep tests green. Don't add behavior.

## Good tests

| Quality | Good | Bad |
|---|---|---|
| **Minimal** | One thing per test. "and" in name → split. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes behavior | `test('test1')` |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |
| **Real code** | Exercises real implementation through public interface | Mocks internal collaborators |
| **Survives refactor** | Same test passes after rename/move | Breaks when internals change |

## Why order matters

**"I'll write tests after to verify it works."** Tests written after code pass immediately. Passing immediately proves nothing — might test wrong thing, might test implementation, might miss cases you forgot. You never saw it catch the bug. Test-first forces you to see it fail, proving it actually tests something.

**"I already manually tested edge cases."** Manual testing is ad-hoc — no record, can't re-run, easy to forget under pressure. Automated tests run the same way every time.

**"Deleting X hours is wasteful."** Sunk cost fallacy. Time's gone. Choice now: delete + rewrite with TDD (high confidence) vs keep + add tests after (low confidence, likely bugs). The waste is keeping code you can't trust.

**"Tests-after achieve the same goals — it's spirit not ritual."** No. Tests-after answer "what does this do?" Tests-first answer "what should this do?" Tests-after are biased by your implementation. Tests-first force edge-case discovery before implementing.

## Common rationalizations

| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost. Unverified code is tech debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to the test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests now. |
| "Just this once" | That's rationalization. Stop. |

## Red flags — STOP and start over

- Code before test
- Test written after implementation
- Test passes immediately
- Can't explain why test failed
- Tests added "later"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's spirit not ritual"
- "Keep as reference"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."
- **Wrote multiple tests before any implementation** (horizontal slicing)

All of these mean: delete code. Start over.

## Example — bug fix

Bug: empty email accepted.

**RED**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**GREEN**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) return { error: 'Email required' };
  // ...
}
```

**Verify GREEN**
```bash
$ npm test
PASS
```

**REFACTOR**
Extract validation if multiple fields need it.

## When stuck

| Problem | Solution |
|---|---|
| Don't know how to test | Write the wished-for API. Write the assertion first. Ask user. |
| Test too complicated | Design too complicated. Simplify interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify design. |
| Hard to test through public interface | Module is shallow — consider deepening (see `improve-codebase-architecture` skill) |

## Debugging integration

Bug found? Write a failing test reproducing it. Follow TDD cycle. The test proves the fix and prevents regression.

Never fix bugs without a test. See `diagnose` skill for hard-bug discipline (build feedback loop → hypothesise → instrument → fix).

## Verification checklist

Before marking work complete:
- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no warnings/errors)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases + error paths covered
- [ ] No horizontal slicing (wrote all tests before any impl)

Can't check all boxes? You skipped TDD. Start over.

## Final rule

```
Production code → test exists and failed first → vertical slice (one at a time)
Otherwise → not TDD
```

No exceptions without user permission.
