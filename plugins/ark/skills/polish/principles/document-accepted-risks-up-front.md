# Document accepted risks before reviewers find the gap

Automated reviewers escalate undocumented risk acceptance round after round —
they cannot distinguish "didn't think about it" from "considered and
declined." A written decision entry (threat model, deliberately-unbuilt
hardening, accepted trade-off) makes reviewers withdraw in one exchange
instead of re-raising for three rounds. If the project's threat model is
deliberately narrow (single-maintainer, internal-only, trusted operators),
state it in the PR — reviewers cannot infer it, and saying so once is
cheaper than defending it per round.

## Check

- Does the branch add anything security- or reliability-shaped where the
  design deliberately stops short (shared credentials, non-rotating tokens,
  no revocation path)? Write the decision entry *in this PR*, before review.
- When a fix intentionally keeps a residual weakness (a discriminator that
  can still collide, a race accepted as harmless), name the residual and the
  reasoning in the fix commit — "accepted, not fixed" recorded explicitly.
- When two reviewers demand opposite changes on the same lines, stop and
  escalate to the owner instead of applying either — applying each in turn
  ping-pongs the code at a round per swing.

## From the history

**Violation — PR #303:** the single-user threat model existed from day one
but wasn't stated; reviewers escalated shared staging credentials into a
"production security gate," the design was built and then reversed by the
owner ("per-run credentials are deliberately not built… single user"), and a
further round arrived against the already-dead design. Stating the model in
round 1 would have cut 3+ rounds.

**Violation — PR #317:** duplicate-hunk IDs got encounter-order suffixes;
the next round flagged the renumbering residual. The author ultimately kept
the suffixes *and documented the residual* — an outcome writable in round 1.

**Done right — PR #340:** the refresh-token non-rotation decision entry made
CodeRabbit withdraw its 30-day-replay finding as "already addressed by the
documented decision" in one exchange.

**Done right — PR #340:** faced with opposite demands on PKCE-vs-code-burn
ordering, the author held: "you and the other reviewer are asking for
opposite things on the same lines" — and the owner's call settled it.
Reviewer: "Thank you for pausing rather than bouncing the implementation
between conflicting review comments."
