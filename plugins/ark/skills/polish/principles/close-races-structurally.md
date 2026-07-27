# Close races structurally, not probabilistically

A guard that shrinks a race window has relocated the bug, not fixed it.
Timing bounds (drains, sleeps, `Promise.race`) bound *your wait*, not the
underlying work — the abandoned operation keeps running and can still commit
its side effect. Put the guarantee at the state transition itself: a guarded
write, a DB-level fence, cancellation, a single-flight slot, or one
reconciliation model with generation stamps.

## Check

- Does the fix make the bad interleaving *impossible*, or just *unlikely*?
  "Smaller gap" answers are the bug moved, and they draw the next round.
- `Promise.race` against a timer: is the losing operation cancelled, or does
  it leak one in-flight request per iteration and land its write later?
- Enumerate the interleaving matrix once — fail before A, between A and B,
  after B; start × callback × failure × shutdown — instead of patching the
  one interleaving the reviewer demonstrated.
- For optimistic UI state, patching individual races loses: keep a
  confirmed-state source of truth plus generation stamps.

## From the history

**Violation — PR #355 (the canonical four-round chain):** an unbounded log
sink → a bounded drain ("narrows the overwrite window; it doesn't close it —
and the comment claims it does") → `tryReadLog` racing a 10s sleep ("bounds
the *wait*, not the *request* — a stalled endpoint leaks one in-flight HTTP
request per poll") → a single in-flight slot with its own consequence. The
class only closed when the guarantee moved to the write: `updateMany where
status: "running"`. Author: "the drain was never going to be the answer… the
executor cannot unsend a query. The guarantee now lives at the write."

**Violation — PR #362:** a liveness check added before a read "narrowed the
window from the life of the connection to the gap between two queries, but a
gap is a gap."

**Violation — PR #320:** four rounds of optimistic-toggle races (queued
failures, rollback clobbers, stale `confirmedRef` across PR switches), each
fix patching the demonstrated interleaving. The eventual confirmed-ref +
generation-stamp design resolved all four at once.

**Violation — PR #283:** releasing a dedupe claim on failure fixed
at-most-once but created duplicate sends; the send-first refix made post-send
persistence unrecoverable. A claim/send/persist failure-matrix walk in round
1 covers all three windows.

**Done right — PR #355:** once the guard moved to the write, the reviewer
*confirmed* it "genuinely race-free" via `FOR UPDATE` serialization — the
class stayed closed.
