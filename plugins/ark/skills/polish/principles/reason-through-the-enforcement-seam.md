# Reason about authority at the enforcement seam, not the leaf check

A policy's effective behavior for a given actor is decided by the wrapper that
enforces it — `Repo.run`, a middleware, an interceptor, a query scope — which
typically branches per actor-type and layers several independent sub-checks.
The leaf predicate it sometimes calls (`can_view`, an `authorize/2`, one guard
clause) is not the whole story: the wrapper may skip it for some actors and add
checks the leaf never mentions. Decide reachability and safety by exercising the
wrapper with the exact actor, never by evaluating the leaf alone — the two
routinely disagree, in both directions.

## Check

- Does a claim ("this viewer can't see the row," "that actor bypasses the
  policy entirely") rest on the leaf predicate, or on the wrapper that actually
  runs in production? Trace the wrapper's per-actor branches.
- Does the wrapper short-circuit the leaf for privileged/cross-cutting actors
  (god-mode, service, cross-tenant)? Then leaf behavior does not predict wrapper
  behavior for them.
- Does the wrapper apply *additional* checks beyond the leaf, gated on a
  *different* attribute (a tenant/sandbox scope gated on "is a developer," not
  on "is privileged")? An actor can clear the leaf and still trip those.
- Before writing a comment asserting framework behavior, confirm the exact
  gating condition in the wrapper's source, not the one you assume.

## From the history

**Violation — ArchAstro/firstlanding#8910:** a routing lookup was judged
unusable under a single-app privileged viewer because calling the row's
`can_view` directly returned forbidden. But the real path runs through
`Repo.run`, which skips schema policy entirely for cross-app viewers — the
cross-app viewer was in fact the correct, documented choice. Reasoning at the
leaf gave the opposite answer and took a human correction to unwind.

**Violation — ArchAstro/firstlanding#8910:** the inverse, same PR. A list path
skipped its sandbox predicate for all cross-app viewers under a comment claiming
they "bypass the policy entirely." But `Repo.run` runs a *separate* sandbox-scope
check for every developer viewer regardless of cross-app status, so a cross-app
developer raised on the first out-of-scope row. A reviewer re-flagged the latent
raise a round later; the fix filtered those viewers directly instead of bypassing
them.
