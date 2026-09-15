---
name: python
description: Use when writing, editing, reviewing or debugging any Python code. Covers typing a value that crosses a function or module edge, choosing between pydantic, dataclass, NamedTuple, TypedDict and NewType, converting a dict to a model or a str to a datetime, deciding what check proves a Python change is done, and a Python test that misbehaves after a file was edited and restored.
---

# Python

Two principles run through everything below.

1. **A value that crosses a function signature or module edge with an untyped shape is a finding.** `dict` in, `dict` out, and a reader must execute the code in their head to learn which keys exist. The type is real but written nowhere, so there is nothing to open and nothing to grep. The same defect at smaller scale: a `str` that holds a date, a duration or an ID with a fixed grammar.
2. **A type change is a behaviour change until proven otherwise.** Swapping `dict` for a model, or `str` for `datetime`, reads as a refactor and is not one. The proof is enumerating every construction site and every read site. Cannot enumerate them, propose the change instead of applying it.

## Typing ladder

Strongest contract first. Pick by the contract needed, not by habit.

| Reach for | When |
|---|---|
| pydantic `BaseModel` | untrusted input at a trust edge: HTTP body, cross-service payload, queue message. Buys runtime validation and coercion. Costs a dependency and parse time |
| `@dataclass` | trusted internal value object. Attribute access, free `__eq__` and `__repr__`. `frozen=True` when it must not mutate |
| `t.NamedTuple` | small immutable value you would otherwise pass as a 2 or 3 element tuple. Unpacking is a feature |
| `t.TypedDict` | must stay a dict at runtime: forwarded to an API expecting dict, JSON-serialised, Lambda event. Static checks, zero runtime cost. One dict object filled in place gets one `TypedDict` with `NotRequired` on the late keys; two types only when two objects exist |
| `t.NewType` alias | must stay a primitive at runtime (a sort key, a wire format, an ID derived from exact bytes) but its grammar is unstated. `IsoTimestamp = t.NewType("IsoTimestamp", str)`. Zero runtime change, every use site greppable, and the checker rejects a bare `str` in the slot |
| `dict[str, Any]` + docstring | genuinely ad-hoc or heterogeneous shape |

`TypedDict` and `NewType` are the safe rungs: they change nothing at runtime. Prefer them when the only goal is naming the shape.

## What to flag

In rough order of severity:

1. Untyped `dict` crossing a signature or module edge.
2. Nested untyped dicts. Severity compounds with depth.
3. Date or time carried as a bare `str`. Epoch seconds, millis, ISO 8601, aware or naive: the annotation does not say. Parse to `datetime` at the edge, or name the string with `NewType`. This buys correctness: string datetimes compare wrong across formats, and `"2026-08-18"` sorts before `"2026-08-18T00:00:00Z"` by accident. Same rule for durations, money as `float`, and IDs whose format matters.
4. `Any` or `object` where a concrete type is knowable.
5. External JSON, HTTP body or cross-service payload accepted without a validating parse.
6. Missing hints on a new signature, when the type is knowable.
7. A name that lies about its type: `id` holding an object, `count` holding a list.

## What not to flag

- A local whose type is obvious from the line above.
- A file with no hints anywhere. Match the existing style until the file is modernised on purpose.
- Code outside the diff. Note it, do not retrofit it.
- A dict or datetime string that stays inside one short function and never crosses an edge. Once it crosses one, "nothing compares it today" is not a reason to skip: the next caller re-derives the grammar from a producer's docstring.
- Introducing pydantic to a package that does not already depend on it. Propose it, do not do it.

## Wire facts are not typing arguments

A serialisation layer that refuses `datetime` is a conversion point, not a blocker. Many database and RPC clients raise on `datetime` and return a string on read. That constrains the wire, not the domain. Serialise where you write, parse where you read.

| Objection | What it constrains |
|---|---|
| "the client raises on this type" | the write call. Convert there |
| "reads come back as a string" | the read call. Parse there |
| "it is a sort key, width must be constant" | the stored bytes. One canonical formatter |
| "another value is derived from its exact bytes" | the formatter's stability. One assertion tests it |

The format is forced only when the type IS the wire shape: a `TypedDict` fed straight into a storage call, or one describing a row exactly as read back. Typing `datetime` there is false at runtime in both directions. The honest move is a pair: `NewType` on the storage shape, plus a domain type carrying a real `datetime`, converted once. A `str` everywhere is what you get by skipping the pair.

**Semantics come from the producer.** A value's type is what it is, not what its readers need. A consumer that behaves the same on a hash, a counter or a timestamp tells you about the consumer, not the value. Counting call sites that compare or sort answers "what breaks if I change this?", not "what is this?".

## Document the fields that lie

Non-obvious field knowledge goes in the **class docstring**. A trailing `#` comment reaches nothing: LSP hover, `help()` and generated docs all read `__doc__` and none read comments. Document only fields whose names hide something: an opaque ID behind a human-sounding name, a value mutated outside this code path, a field that doubles as a key seed.

```python
class ShareRecord(t.TypedDict):
    """Row written to the shares table on create.

    created_by      Cognito sub, not a username or email.
    last_batch_ts   Equal to created_at at create, then moves on every
                    add-items call while created_at stays put.
    """
```

## Behaviour changes hiding in a "refactor"

| Rewrite | Silent change |
|---|---|
| `d.get("x")` to `model.x` | missing key was `None`, now raises `AttributeError` |
| `dict` to pydantic `BaseModel` | pydantic coerces: `"5"` becomes `5`, `"true"` becomes `True`. Downstream `is` and type checks flip |
| `dict` to pydantic `BaseModel` | extra keys pass through a dict, get dropped or rejected by a model depending on config |
| `dict` to `@dataclass` | the dict was mutated in place somewhere; the dataclass is a different object and the mutation is lost |
| adding a required field | a caller that omitted it worked before, raises now |
| `Any` to concrete type | static only, but a checker error is a build break |
| `str` to `datetime` | a string that never raised now raises on any row whose format differs. Legacy rows rarely all match |
| `str` to `datetime` | aware vs naive: comparing the two raises `TypeError` at runtime, not at parse |
| `str` to `datetime` | a value written back to storage or a response body now serialises differently. `str(dt)` is not the input string |
| `str` to `datetime` | lossy round trip wherever the format is narrower than `datetime`. Millisecond input, microsecond output, `parsed == original` is `False`. Cache keys and dedup checks flip |

A `str` to `datetime` parse is proven safe when three things hold: the parse handles every format present in real stored data, not only the format the happy path writes; nothing downstream compares the value to a naive datetime; and no write path or response body carries the value back out unchanged.

Smaller traps of the same kind: reordering `and` / `or` changes what gets evaluated; `if x` is not `if x is not None`, so `0` and `""` diverge; a generator handed to a consumer that iterates twice yields nothing the second time.

## Before calling a change done

- **Run the repo's real gate, not a generic pair.** Python has no compile step, and a green `pytest` says nothing about the type checker or linter CI requires. Read the CI workflow files and any per-directory allow-list a ratchet uses, then run exactly that. Note which directories the gate does not cover: an annotation in an ungated directory is documentation, and worth less than one a checker verifies. If the repo has no checker at all, say so in the report and do not install one to prove a point.
- **Clear stale bytecode after editing and restoring a file.** `__pycache__` can outlive the restore, so anything that imports the module keeps seeing the mutated version. Set `PYTHONDONTWRITEBYTECODE=1` or delete `__pycache__` before measuring.
- **A log line must never raise.** Use `.get()` rather than subscript for any key newly referenced in logging.
