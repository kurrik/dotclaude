# Vary scope axes independently in test fixtures

A test can only catch mismatches along dimensions its fixtures actually
vary. In multi-tenant code, three scope axes routinely matter: the caller's
session scope, the destination scope of the operation, and the residence of
the existing data. Fixtures that collapse them — everything in one tenant,
or every principal tenant-less — make caller-scoped and destination-scoped
queries indistinguishable, so scope-confusion bugs pass green. Worse, a
green test can *certify* a false invariant its fixtures cannot distinguish
from the true one.

## Check

- For each boundary query the diff touches (authorization gates, uniqueness
  prechecks, availability/count checks): do any fixtures make caller scope,
  destination scope, and data residence *differ from each other*? If they
  are always equal (or always nil), the test cannot fail on a scoping bug.
- Do fixtures include principals who can see the container but not the
  contents (the partially-privileged tier: tenant admins, grantees,
  token-holders)? All-or-nothing casts miss every gate/policy asymmetry.
- Does any test name assert a broader invariant ("global", "app-wide",
  "unique across X") than its fixtures exercise? Either widen the fixtures
  to distinguish the claim or narrow the name to what is actually proven.
- Prefer a small matrix (caller class × data residence × expected outcome)
  over one-off cases: the failing cell names the bug.

## From the history

**Violation — ArchAstro/firstlanding#9282:** the shared privacy context built
every team and user tenant-less, so "org admin cannot read Team-owned rows"
had never been exercised with an org-resident admin against an org-resident
row. A reviewer found that exact caller got a 500 on populated Teams and an
empty 200 on empty ones — an existence oracle no green matrix had covered.

**Violation — ArchAstro/firstlanding#9282:** a lookup-key availability check
scoped by the *caller's* session passed every test — all fixtures kept the
caller, the destination org, and the colliding rows in one org, where a
caller-scoped and a destination-scoped query return identical answers. A
test titled "…across the whole app namespace" certified the false app-wide
invariant. Privileged callers whose session scope differed from the
destination were both falsely blocked and under-checked in production paths.

**Done right — ArchAstro/firstlanding#9282:** the closing matrix varied
caller class {tenant admin, tenant-less developer, tenant-less service} ×
colliding-row residence {destination org, unrelated org, none}. Run before
the fix it failed on exactly the predicted cells (caller-less scope ×
unrelated-org decoy); after the destination-scoped fix all nine cells pass
and the failing cell names any regression.
