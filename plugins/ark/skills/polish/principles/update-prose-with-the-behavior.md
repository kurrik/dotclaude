# Update prose with the behavior — in the same commit

A behavior change stales every comment, doc, decision entry, and operator
message that describes the old behavior. Stale prose is not cosmetic: a
comment claiming the opposite of the code invites a future reader to
"restore" the bug, and each stale surface reliably costs one review round.
Status claims live in multiple surfaces and must be updated as a set.

## Check

- Grep the branch (and docs) for the term, filename, or behavior the fix
  changed — every hit is a candidate stale pointer.
- If the repo keeps a fixed set of project-state docs (a README status
  banner, architecture/roadmap/decision/design docs), that set is enumerable
  — a fix that updates one surface and not the others has moved the drift,
  not fixed it. Don't write a fresh overclaim into one surface while
  correcting another.
- Comments *inside the fix's own diff* are the most common offenders: a
  comment written for round N's approach describing the mechanism round N+1
  rejected.
- Moved or renamed a symbol? Grep for the old name in prose, not just code.

## From the history

**Violation — PR #364:** three consecutive rounds were nothing but stale
prose left by each successive fix — a header pointing at a file still
documenting the pre-reorder shape, then a stale file pointer in
`ingest-service.md`, then a warning prescribing exactly the two-step rename
the fix had just made unnecessary, duplicated across six workflow files.

**Violation — PR #355:** the decision doc written in round 3 described round
3's *rejected* mechanism — "`omitUnavailable` doesn't exist — and the bullet
describes the mechanism that was rejected."

**Violation — PR #225:** the round-1 fix added a comment "*don't cache a
transient failure*" directly above the line that caches the transient
failure. Two reviewers flagged it; it took until round 4 to land the one-line
deletion.

**Violation — PR a17k/a17k#371:** the commit message, the PR body, and the
architecture doc all stated that a normalization helper had moved out of the
SPA into a shared library. The SPA's byte-identical copy was still there and
still the live path for every save — "it didn't take over, it duplicated it" —
leaving two implementations that must agree, in exactly the place the shared
module existed to prevent drift. A claim about a *move* is checkable by
grepping for the old copy.

**Violation — PR a17k/a17k#371:** a later round updated a doc's narrative
paragraph to match a new frame contract but left the per-frame enumeration —
the part a client implementer actually reads — describing the old one. Drift
moved rather than closed.

**Violation — PR #353:** the code moved from a status denylist to an
allowlist; the doc kept naming "the incomplete set the code no longer uses,
and a future reader… would reintroduce the bug."

**Done right — PR #148:** the `drone_secret_prefix` fix resolved naming drift
across `.drone.yml`, the Terraform module, and both doc files in one commit —
three reviewers' threads closed on it.
