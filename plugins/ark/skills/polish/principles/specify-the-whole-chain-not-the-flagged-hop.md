# Specify the whole chain, not the hop that was flagged

Some findings are about one hop of a multi-hop contract — a value that is
declared, requested, narrowed, stored, re-derived, and finally enforced across
several components. Fixing the named hop leaves the adjacent ones ambiguous,
and the next round finds the next hop; each fix looks correct in isolation
while the contract as a whole is still unstated. When a finding lands on a
pipeline like this, write the whole chain down — every hop, in order, with the
invariant that relates them — and fix the flagged hop as part of it.

## Check

- Does the flagged value travel? Trace it: who declares it, who requests it,
  where it is narrowed or intersected, what persists it, what re-derives it,
  who enforces it. If that list is longer than two, the finding is about a
  chain.
- Is there one invariant that should hold at every hop ("each hop narrows,
  none widens", "the value is only ever copied, never recomputed")? State it
  explicitly; unstated invariants are where the next round's finding lives.
- Which hops does the diff leave unspecified? An adjacent hop that "obviously"
  works is the one that gets flagged next — especially the endpoints, where a
  producer that emits nothing or a consumer that enforces nothing is easy to
  miss.
- Is the chain written in one place a future reader will find, or spread
  across sentences in several sections? Spread prose is how the hops drift
  apart again.

## From the history

**Violation — a17k/a17k#421:** four separate review rounds each found a
different hop of one scope/role chain in an auth-service design. Round 6:
requested OAuth scopes were not carried across the authorize transaction, so
consent could not intersect them with the user's grants. Round 9: the access
token omitted the `scope` claim RFC 9068 requires. Round 10: audiences stored
no required-scope policy, so the session fast path had nothing to compare
against. Round 11: the relying-party plugin had no scope configuration at all
— it requested nothing, so sessions landed with no roles — and issuance never
rejected an empty intersection, which would have minted role-less tokens that
a resource server checking only validity would honor. Every individual fix was
correct; none of them made the next round unnecessary, because the chain was
never stated.

**Done right — a17k/a17k#421:** the round-11 fix stopped patching links. It
added one "Roles and scopes, end to end" section naming all six hops (config →
authorize → consent → code/refresh → issuance → enforcement) with the
invariant that every hop narrows and none widens, then fixed the two exposed
links inside that frame. The decision log recorded that future changes amend
that section rather than adding another sentence elsewhere.
