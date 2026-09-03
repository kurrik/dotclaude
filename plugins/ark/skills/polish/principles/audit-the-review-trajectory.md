# Audit the review trajectory before fixing the next finding

A finding can be entirely valid and still be the wrong thing to fix. When
review runs for several rounds, look at *what the findings are landing on*:
code that serves the branch's intent, or code an earlier round introduced.
Findings on round-introduced code are evidence about the expansion — that
it is growing, that it is the kind of thing an adversarial reviewer can
probe forever — and the fix at the right altitude is usually to remove the
expansion, not to harden it. Validity is not the test; the intent summary
is. This is the trap the no-scope-expansion ground rule exists for, and it
is easy to fall into one valid finding at a time.

## Check

- Before fixing, classify every finding in the round: on intent code, or
  on code added in response to an earlier finding? If a PR exists, read
  its threads; on a branch, read the `polish:` commits. Keep a running
  count of how much of the diff is round-introduced.
- Would deleting the subsystem the finding sits in satisfy the finding *and*
  the intent summary? Then delete it. A hardened expansion is still an
  expansion.
- Did a one-sentence check become a mechanism? ("Look for secret-shaped
  values" → scan before push → scan history → scan messages → a scanner.)
  The moment it needs a second commit, ask whether it belongs in this PR at
  all, and whether an existing tool already does it.
- Is the reviewer enumerating an external system's edge cases (git's
  quoting rules, `pushurl`, refspec configuration) in code that exists to
  wrap that system? That review has no end; the wrapper is the problem.
- Is the fix protecting against a scenario nobody asked to protect
  against (a verdict lost across sessions, a fork workflow)? Decline with
  the intent summary as the reason.
- Restructuring is not the same as descoping. Moving round-introduced
  prose into tested scripts is better engineering and still ratifies the
  expansion; do the descoping question first.
- Stop signal: a round whose findings are all on round-introduced code.
  Name the expansion and put its removal to the human before another fix.

## From the history

**Violation — kurrik/dotclaude#18:** a PR to make `ark:polish` opt-in and
add two principles ran thirteen review rounds and fifty threads. Round 1
had a sentence about a "secret-shaped value" in a post-push sanity check;
valid findings said scan before the push, then scan history, then scan
commit messages, and a scanner existed. Round 2 had a valid finding about
a polish verdict lost across sessions, and a persisted state machine
existed. A restructure moved both into five tested scripts — better code,
same expansion. Every round after that was a git edge case in the
scripts: `pushurl` versus fetch URL, newlines in filenames, `++counter`
lines starting with three pluses, remote aliases, single-branch clones.
At the cut, 607 of the PR's 1,148 added lines were round-introduced; the
original ask was about 400.

**Done right — kurrik/dotclaude#18:** the descoping commit removed the
scripts and their prose, restored the three skills to the last
prose-only round plus three one-line fixes that served the intent, closed
seven open threads as out of scope, and added this principle. The
reviewer's next pass had only the intent to look at.
