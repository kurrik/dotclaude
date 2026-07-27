# Prove the fix fires

A fix that was never observed working is a claim, not a fix. Config-shaped
fixes can be correct-looking and inert; a gate can be vacuously true against
a test fake missing the field it checks; an Edit anchor can silently swallow
an adjacent finding. Reviewers re-raise unverified fixes at one full round
per repeat — and "still here after two rounds" is the most expensive comment
in the corpus.

## Check

- Induce the failure the fix prevents, once. If you can't induce it, say why
  it's still trustworthy.
- Config/tsconfig/CI fixes: verify something actually consumes the config you
  changed (a target that runs it, a step that reads it).
- Gates compared against test fakes: confirm the fake has the field, or the
  gate is `undefined === undefined`.
- Before replying, diff the fix commit against the finding list — verify
  every flagged item is actually present in the commit, especially near Edit
  anchor boundaries where a replacement can drop adjacent content.
- Operator-facing remediation text ("push again", "re-run with --source X"):
  run the suggested command against the failure state it accompanies. Twice
  in this corpus the advertised escape hatch could not work.

## From the history

**Violation — PR #213:** "stories aren't typechecked" was fixed by adding
stories to a tsconfig `include`; round 3: "the story-include change has no
effect — nothing typechecks this tsconfig" (no typecheck target existed).
Injecting one story type error would have exposed the no-op immediately.

**Violation — PR #303:** a flagged orphaned decision header survived the fix
commit untouched — "collateral damage from an earlier edit (the old_string
anchored on it and the replacement dropped it)" — costing a repeat round for
zero progress.

**Violation — PR #225:** the memoized-transient-failure fix was replied-to as
fixed twice while `authed = false` remained on line 51; round 3: "Still here
after two rounds of comments."

**Violation — PR a17k/a17k#371:** a shutdown-flush fix moved the hook to an
earlier lifecycle phase for a correct reason, but registered it inside an
encapsulated plugin — where the framework gives child instances an empty array
for that phase and runs only the root's. The hook landed where nothing reads
it, making the fix strictly *worse* than the code it replaced, with CI green
because every test called the flush directly.

**Violation — PR #353/#236:** error messages told the operator to "push
again" (can't retrigger a path-filtered workflow) and to use a `--source`
selector that "also resolves through `bySlug.get(...)`" — the escape hatch
the fix advertised didn't exist.

**Done right — PR #356:** "I checked the premise against the API rather than
reasoning about it" — the author tested GitHub's `total_count` de-dup
behavior on the PR's own head commit before changing the guard; the thread
closed in one round.

**Done right — PR a17k/a17k#371:** an intermittent failure a previous commit
claimed to have fixed was re-measured rather than assumed (peak 11 connections
against a pool of 20, zero blocked queries), and the claim withdrawn in the
next commit: "draining removed a real contributor; it wasn't the whole story."
