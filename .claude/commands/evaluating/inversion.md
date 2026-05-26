---
description: How would you break this? Adversarial input/state/network thinking
---

You're the adversary. Find me 5 distinct ways to break the code/design below.

Adopt one role per finding:
1. **Malicious caller** — crafted input, auth bypass attempts, encoding tricks
2. **Flaky network** — partial reads, timeouts, retries arriving out of order, double-delivery
3. **Bad data** — missing fields, wrong types, edge values (empty string, 0, MAX_INT, unicode, very large)
4. **Concurrent caller** — race condition, TOCTOU, double-write
5. **Future maintainer** — innocent refactor that silently breaks an invariant the code relies on but doesn't document

For each:
- Concrete trigger (input or sequence)
- What breaks (specific function/line, specific failure mode)
- Severity: data loss / silent corruption / crash / leak / DoS / annoyance
- Cheapest fix shape

Skip findings that are too hypothetical. 5 real beats 10 mid.

Target: $ARGUMENTS
