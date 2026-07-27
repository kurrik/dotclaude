# Don't lose what earlier rounds fixed

A rewrite is a fresh chance to drop a property the previous version got
right. When a fix restructures, relocates, or replaces code — especially code
this PR already fixed once — diff the new version against the old for
silently-dropped flags, ordering, scoping, and for the *rationale* of earlier
fixes in the same container.

## Check

- Before replacing a block, list the load-bearing properties of the current
  version (namespace flags, execution order, batch isolation, fail-open
  behavior). Confirm each survives the rewrite.
- Touching a component the PR already stabilized? Re-read *why* the earlier
  fix was made; don't reintroduce the class it closed.
- When trading failure modes (silent-wrong → fail-fast, fail-open →
  fail-closed), check the new mode one level up: does the throw now escape
  the per-item try/catch and kill the whole batch?

## From the history

**Violation — PR #353:** "Round 2 had `-n woodpecker` on the command that
actually talked to the API server. Round 3 moved the create to
`--dry-run=client`… and the write now has **no namespace flag**." The rewrite
relocated the operation and dropped the flag that made it correct.

**Violation — PR #341:** round 1 fixed layout reflow by mounting
`ReviewProgress` unconditionally; round 6 moved the row inside a conditional
block — "reintroduces the reflow the metrics change fixed — and now it fires
mid-review." Author: "the exact failure the unconditional-mount fix was for."

**Violation — PR #236:** the duplicate-slug fix threw at choice-build time —
*before* the per-post try/catch — so "one collision kills `--all` for every
story." The fix undid the batch-isolation work done the same round.

**Violation — PR #353:** a reorder placed `exit 1` ahead of the drift check,
so "the signal that persists is skipped on the *one* push where a rollout is
known to have failed" — inverting the design intent of the block it edited.
