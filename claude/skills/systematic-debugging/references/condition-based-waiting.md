# Condition-Based Waiting

## When to use this

A test or script waits for something async — a server to come up, a file to be written, a job to finish — and does it with `sleep(N)` or a fixed timeout. This costs you both ways: on a slow machine or a loaded CI runner, the fixed wait is sometimes too short and the test flakes; on a fast machine, it's needlessly long and every run pays the tax. No value of N is ever right, because the sleep is a proxy: the test needs to know whether the awaited state has been reached, and a timer never looks at that state at all.

## The technique

Replace the fixed wait with a loop that polls the actual condition you're waiting for, on a short interval, up to a deadline. If the deadline is exceeded, fail with diagnostic information about what state was actually observed — not just "timed out."

```python
import time

def wait_for_condition(check, timeout=10, interval=0.1, description="condition"):
    deadline = time.monotonic() + timeout
    last_state = None
    while time.monotonic() < deadline:
        last_state = check()
        if last_state:
            return last_state
        time.sleep(interval)
    raise TimeoutError(
        f"Timed out after {timeout}s waiting for {description}; "
        f"last observed state: {last_state!r}"
    )

# usage
wait_for_condition(
    lambda: server.is_ready(),
    timeout=15,
    description="server ready",
)
```

The same shape works in any language: loop on a short interval, bound the loop with a deadline, and report the last observed state when the deadline passes. This resolves as soon as the condition is true instead of always waiting the worst-case duration, and it still bounds the wait so a genuinely broken condition fails the test instead of hanging forever. The diagnostic on timeout matters as much as the polling — it's what turns the next flake into a two-minute diagnosis instead of another guessing session.

## Prefer signals over polling when they exist

Polling is the fallback, not the first choice. If the system you're waiting on can tell you directly — an event emitter, a callback, a promise/future that resolves on completion, a message queue ack — use that instead. A polling loop is guessing whether something happened by asking repeatedly; an explicit completion signal knows. Reach for condition-based waiting specifically when no such signal is exposed and probing observable state (a file's existence, an HTTP health check, a process's exit code) is the only option available.
