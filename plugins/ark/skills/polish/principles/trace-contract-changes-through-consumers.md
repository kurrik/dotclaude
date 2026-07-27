# Trace contract changes through every consumer

When a fix changes what a value means, when an event fires, or what a
function returns on failure, every consumer that assumed the old contract is
now suspect — including consumers this same PR just touched, and state whose
effect is deferred. The fix is not done at the flagged line; it's done when
the new contract has been traced end-to-end.

## Check

- Changed a signal's meaning or widened when it fires? List its consumers and
  re-derive each one's assumption. A staleness rule keyed on "version only"
  breaks the moment version stops being the only axis of change.
- Changed reject→resolve, or added an early `return`? Read what the caller's
  `.then`/follow-on code now does in the new case.
- Added a binding, cap, or lease? Trace it through *every hop* of the chain
  it protects (auth code → access token → refresh token), not just the hop
  the reviewer named.
- Wrote state whose effect fires later (an armed collapse, a queued token)?
  Trace what the *recorded* state does, not just what renders now.

## From the history

**Violation — PR #362:** a round-4 fix widened the server's change signal so
sharing changes pushed snapshots at an *unchanged* version; round 5 found the
client's version-only staleness rule silently dropped them. Author: "a direct
consequence of my round-4 change… I didn't revisit the client rule that
assumed `version` was the only axis."

**Violation — PR #320:** round 1 asked for a missing `return` after
`onUnauthorized()`; the one-line fix changed the promise from rejecting to
resolving, so round 2 found the composer clearing the draft and flashing
"Comment posted ✓" for a comment that was never posted.

**Violation — PR #340:** the round-2 fix bound `client_id` to the auth code;
round 3 found the binding "stops one hop short… dropped when the refresh
token is minted." The full chain was visible when the binding was added.

**Violation — PR #341:** a header tap while composing was accepted as
harmless because it "can't change what's on screen"; round 5 found it still
wrote `expanded: false` — arming a collapse that fired later, hiding the
reply the user had just posted.
