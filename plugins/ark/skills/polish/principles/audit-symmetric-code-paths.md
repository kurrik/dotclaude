# Audit symmetric code paths together

Defects rarely live in exactly one arm of a paired construct. When a fix
touches one side of a pair — success/failure, read/write, caller/callee,
start/stop, API/UI — the mirror side almost always has the same defect, and
it draws the next round.

## Check

- Fixed a `.then`? Read the `.catch`. Fixed the failure path? Diff it against
  the success path for guards only one of them has.
- Hardened a callee? Check whether the caller still does what the callee used
  to do wrong.
- Fixed `start()`? Walk `stop()` with the same failure in mind.
- Enforced something in the API? Check the UI still advertises the thing the
  API now rejects (and vice versa).
- Bounded a write path? Check the read path for the same hazard "in the
  opposite direction."

## From the history

**Violation — PR #362:** round 2 flagged a version-clobber in `fetchRecipe`'s
success path; the fix reconciled only `.then`. Round 3: "the *failure* path of
the same `fetchRecipe` still applies by arrival order — and it's unconditional,
so it's the stronger clobber." Author: "Both of you flagged this and I only
fixed the success path."

**Violation — PR #356:** the "commit ETags only after both reads succeed" fix
hardened `checks.ts`; the next round found `pr-stream.ts` — "the same
'validator without its rows' failure `checks.ts` was just hardened against,
one level up." Author: "I hardened the reader and left the caller doing
exactly what the reader used to do."

**Violation — PR #355:** the unbounded advisory log *sink* was fixed; the pod
log *read* had the same hazard. Author: "Same bug class as the sink, opposite
direction, and I only fixed one side."

**Done right — PR #356:** the `request.raw.destroyed` disconnect fix was
placed in shared `lib-sse` "since ingest-service and terraform-runner can hit
the same race" — one fix, three services, class closed.
