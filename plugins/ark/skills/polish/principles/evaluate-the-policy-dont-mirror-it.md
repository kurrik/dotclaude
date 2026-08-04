# Evaluate the policy — don't mirror it in a gate

A boundary that pre-checks authorization before querying (to keep errors
clean, or to avoid a policy raise mid-list) must not re-implement the policy
with its own predicate. A hand-mirrored gate drifts in both directions: too
weak, it passes callers the rows will raise on; too strong, it denies
principals the policy admits — and each direction costs its own review
round. Where the policy is decided by scope and ownership fields, evaluate
the real policy against a prospective record carrying those fields instead;
that portion of the gate cannot drift because it *is* the policy. Where
per-record grants (ID-keyed ACLs) also admit principals, a synthetic record
cannot represent them — filter or authorize the actual records for that
part, or state explicitly that the boundary excludes grant-only access.

## Check

- Does a new gate duplicate an authorization decision that a schema policy,
  middleware, or ruleset already owns? List the principal classes each
  admits and diff them — any asymmetry is a latent round.
- Weaker-than-policy gate: a caller passes the gate, then the row policy
  raises on results. Does the boundary's error contract survive that (or
  does it 500 on populated data and succeed on empty — an existence oracle)?
- Stronger-than-policy gate: enumerate the policy's non-obvious admits
  (service/system identities, machine principals, delegated actors) and
  confirm the gate admits them too.
- If evaluating the policy against a prospective/synthetic record: the
  technique is sound only for the policy branches decided by the record's
  populated fields. Give the record a fresh never-persisted ID so ID-keyed
  grants resolve to nothing — and then decide deliberately whether
  grant-only principals should pass this boundary; if they should, authorize
  the actual records instead. Confirm write authority is still enforced on
  the real record after fetch.

## From the history

**Violation — ArchAstro/firstlanding#9282:** a Team-scoped listing gated on
"can the caller see the Team" while the rows required Team membership. The
Team policy admits non-members (residence-org admins, ACL read grantees), so
those callers got a 500 (`PrivacyError`) when definitions existed and an
empty 200 when none did — an inconsistent contract and a presence oracle.

**Violation — ArchAstro/firstlanding#9282:** the fix swapped in a hand-picked
membership predicate — human members plus two privileged tiers — and the
next round flagged the mirror image: the row policy also admits the Team's
own system identity and the team's agents, which the human-only predicate
rejected. Same defect class, opposite sign, one extra round.

**Done right — ArchAstro/firstlanding#9282:** the closing fix evaluated the
row policy itself against a prospective record carrying the Team's scope
fields and a fresh unpersisted ID (`can_view(viewer, prospective) == :ok`).
The gate now admits exactly what the rows admit, and the reviewer's re-check
passed with no further rounds.
