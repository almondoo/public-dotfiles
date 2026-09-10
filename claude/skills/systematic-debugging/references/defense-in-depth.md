# Defense in Depth

## When to use this

You've traced a bug to its root cause and fixed it there. Before calling the bug closed, consider whether the same class of bad data could still reach the same failure through a different path. A single fix at the origin closes the one path you found; it does nothing for a second caller that produces the same kind of bad value a different way.

## The technique

Fixing the source is still the right first move — never skip it in favor of validation alone, or you're treating the symptom everywhere except where it started. Defense in depth is what you add *after* that fix, at the points where data crosses a trust boundary:

- where external input enters the system (API request bodies, CLI args, file reads, env vars)
- where one module hands data to another with a different set of assumptions
- immediately before and after a persistence layer (what you write, what you read back)

At each boundary, validate the shape you actually depend on and fail loudly with a specific message — "config.network.timeout is required but was undefined" beats a null-pointer exception two calls later. The next time this class of bug is introduced somewhere else, it's caught at the boundary closest to where it entered, instead of resurfacing as a confusing crash three layers downstream.

## Don't over-apply this

Validation at every function is not defense in depth — it's noise that slows the code and the reader without adding real protection. Reserve it for actual trust boundaries. Two different tools fit two different situations:

- **Internal consistency** — invariants your own code should never violate if correct — belongs behind an `assert`. It documents the assumption and fails fast without cluttering normal control flow. (Some runtimes strip asserts in optimized builds — Python's `-O` flag, for example — which is acceptable for true internal invariants but one more reason never to guard external input with them.)
- **External input** — anything from a user, network call, file, or another service — needs real validation with a recoverable error path, since it can be wrong through no bug of yours.

If you find yourself adding checks to a private helper only ever called with already-validated arguments three lines away, that check belongs at the boundary above it, not here.
