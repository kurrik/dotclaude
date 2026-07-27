# Review-fix code is new code

Fixes written while addressing feedback skip the scrutiny the original code
got — and they're written under exactly the conditions that produced the
original bug. Across the history this corpus was mined from, the round-N fix
being the round-N+1 bug is one of the most reliable patterns. Before pushing
a fix commit, review its diff as skeptically as a stranger's.

## Check

- Walk the fix's own failure branches. Does the fallback it adds actually
  execute under `set -euo pipefail`? Does its error handling mask the original
  error?
- Re-test the fix against every class *already flagged on this branch* — new
  code inherits every constraint the review has established, and code added
  mid-PR is the likeliest place to violate one.
- Did the fix turn a previously-latent or speculative concern into a real
  break (a field that was harmless before now overflows; an env var that was
  unused now collides)?
- Does the regression test actually exercise the branch the finding was
  about, or does it dodge it?

## From the history

**Violation — PR #353:** the failure-reporting message added by round 4's fix
contained `${FAIL_REASON:-unknown}` — a fresh instance of the EnvVarSubst
class flagged two rounds earlier, "in the error message whose entire purpose
was better diagnosis."

**Violation — PR #148:** the secret-upsert fix captured stderr via command
substitution — making the add→update fallback "unreachable under
`set -euo pipefail`." The fix's own mechanism broke it.

**Violation — PR #236:** the shared timeout helper created as a round-3 fix
used `init.signal ?? controller.signal`, so any caller-supplied signal
silently defeated the timeout — and the author then found "the identical
pattern" in the round-2 fix too.

**Violation — PR #359:** "adding `NPM_CONFIG_REGISTRY` made the `http_proxy`
collision real… I introduced the break while addressing your earlier note."
And the apt proxy, added after round 1's port review, had the identical
missing-port bug round 1 had flagged.

**Violation — PR #362:** the round-3 permanence gate compared
`readyState === CLOSED` on a test fake that had neither field — vacuously
true, and untestable with the existing fake.
