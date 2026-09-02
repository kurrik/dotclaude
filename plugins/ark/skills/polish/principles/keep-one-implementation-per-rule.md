# Keep one implementation per rule

When the same rule is written in two places — a validation beside the
business logic it guards, a client re-deriving a server decision, a constant
the issuer stamps and the verifier re-types, a column list spelled out on the
read side and again on the write side, a lock set hand-written next to the
refusals it protects — the copies are correct only until one changes. Tests
do not catch the drift: each copy has its own fixture and both halves stay
green. A reviewer catches it one copy per round. The fix is never "update the
other copy": one implementation owns the rule and every other site calls it,
imports it, or derives from it. A copy that genuinely cannot be removed is a
finding to raise, not a "keep in sync" comment to leave. The
authorization-gate special case is evaluate-the-policy-dont-mirror-it; this
is the general shape.

## Check

- For each new predicate, constant, allow-list, mapping, or projection: does
  the rule already exist — in the domain layer, the store, the schema, the
  provider's SDK, a sibling surface? Grep for the literal and the concept.
  If it exists, the new code calls or derives from it.
- Two versions of one check — a throwing one beside a boolean one, an
  application early-return beside the store's first-write-wins rule — are a
  rule written twice. Keep the stronger one; delete the other.
- A member list typed as a *subset* of a union lets the union grow without
  the list. Derive the type from the runtime value
  (`(typeof LIST)[number]`), never the reverse.
- A client that pre-checks a remote policy (branch protection, an
  authorization decision, a provider's retry rule) has mirrored it and will
  disagree with it. Let the owner decide and surface its answer.
- The sweep is the fix: once one copy is found, enumerate every surface in
  the diff that states the same rule — discovery document, cookie name,
  config parser, the third URI field — and point them all at the owner in
  the same commit. Three catches of one rule in one PR is three rounds.
- Two projections that must agree (read-side fields, write-side columns)
  kept in sync by a test are still two copies. Prefer one definition both
  derive from.

## From the history

**Violation — a17k/a17k#432:** three catches of one rule in one PR. A
verifier-local `ES256` "duplicates the literals used by `accessTokenHeader()`
and ID-token issuance, so an algorithm migration can update the signing side
while leaving every verifier pinned to the old value; the issuance and
verification suites also use independent hard-coded fixtures, allowing both
halves to remain green." Then `ENVIRONMENTS` typed as a subset of its union.
Then the token `typ`: "a `typ` the issuer stamps and the verifier does not
require is a defence that quietly does nothing." Each was fixed at the source;
the author's "this is the third instance of that rule in this PR" is the
cost of not sweeping after the first.

**Violation — a17k/a17k#454:** discovery's `scopes_supported` was a hand copy
of the library's `OIDC_SCOPES` — "the same fix this branch already made for
the binding cookie's name." A round-1 CR/LF check on redirect URIs gave way
in round 2 to the round-trip rule `requireCanonicalUri` already applied to
resource URIs, "rather than a second enumeration." The issuer URL, a third
surface for the same rule, was flagged after merge.

**Violation — a17k/a17k#447 / #449:** an agent's column list lived in the
read projection and both write spreads; round 2 found "the write side of the
class round 1 closed on the read side was still open… dropping one is
invisible to TypeScript." A lock set hand-written beside four refusal
namespaces locked one: three findings in one round, one per namespace.

**Done right — a17k/a17k#439:** asked to preserve `revokedAt` under
concurrent retries, the fix made the store's `revoke` first-write-wins *and
deleted* the application's `if (family.revokedAt !== null) return;` — "once
the store owns the rule, the application copy is the same rule stated a
second time and the weaker statement of it."

**Done right — a17k/a17k#452:** a reviewer asked the client to refuse merging
a behind branch; declined — "refusing here is re-deriving the
branch-protection policy that this whole change deliberately leaves to
GitHub." No further rounds on it.

**Done right — a17k/a17k#435 / #436:** three rounds of applying two authority
rules to three functions one cell at a time ended with one authority matrix
in the tests and one implementation, `requireGrantWriter`, "because three
surfaces asking the same question three times are three rules that can
differ."
