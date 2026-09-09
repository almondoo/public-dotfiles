# Root Cause Tracing

## When to use this

An error surfaces deep in a call stack — a `TypeError` three functions below where the bad value originated, a null reference in a renderer fed by a pipeline built five steps earlier. The stack trace shows where the program noticed the problem, not where it was created. Fixing at the crash site patches one symptom and leaves the defect free to resurface through any other call path.

## The technique

1. **Identify what's wrong at the crash site.** Name the specific bad value — wrong type, missing field, unexpected null — not just "it crashed here."
2. **Look at the code that produced that value**, one step back. What returned it, assigned it, passed it in?
3. **Ask whether the input to that step was already bad.** If yes, the bug is further upstream — repeat from there. If the input was correct and this step corrupted it, that's the root cause: fix it here.
4. **Stop at the first point where good data goes in and bad data comes out.** That's the origin, and that's where the fix belongs — not at the crash site, and not one hop earlier than necessary.

When reading the code isn't enough to tell whether a hop's input was already corrupt, don't guess — add a log line or assert at that hop and run once. One execution with real instrumentation beats several rounds of speculation.

**Example**: a `TypeError: cannot read property 'timeout' of undefined` fires inside a request handler. It received `config.network`, which came from a config-merge function three layers up that silently drops any key missing from the base template. The crash site is the handler; the root cause is the merge function. A null check in the handler would suppress the symptom there, but any other consumer of the merged config still gets a silently truncated object.

## Applied to test suites

The same backward walk works when a test only fails as part of a suite, not in isolation — the "bad value" is shared state instead of a variable. Bisect the tests that ran before the failing one: run the first half, then the second half, narrowing until a single earlier test is implicated. That test leaves behind state (a global, a database row, a mocked module) the failing test depends on being absent. The fix goes in the test that leaks the state, not the one that observes it.
