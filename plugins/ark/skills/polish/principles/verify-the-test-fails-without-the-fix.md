# Verify the regression test fails without the fix

A test that has only ever been seen passing proves nothing — it may assert
something the broken version also satisfied. Before claiming a fix is covered,
revert the fix (or induce its failure mode) and watch the test fail. And assert
the *quantity* the fix changed — the window, the location, the value — not
merely the eventual outcome, because "it happens eventually" is usually true of
the bug too.

## Check

- Revert the fix, run the test, confirm it fails. If it still passes, it is
  testing something else. Record that you did this in the commit message.
- Timing fixes: does the assertion pin the *window*? "Eventually cleaned up"
  passes at 2 s and at 12 s. Assert alive-at-T and gone-by-T'.
- Placement fixes (a hook, a handler, a registration): does the test build the
  real wiring, or construct the subject inline and so pass wherever the real
  one lives?
- Does the test exercise the branch the fix *added*, or only the branch that
  already worked? A retry arm, a failure arm, and an error arm each need their
  own induced failure.
- New field on a wire frame or a return type: delete the field and re-run. If
  the suite is still green, nothing asserts it.
- A bare `sleep` before an assertion is a false pass waiting for a loaded
  machine — settle the thing you are waiting on instead.

## From the history

**Violation — PR a17k/a17k#371:** the test written for a new retry budget
asserted only that an abandoned session was "eventually disposed" — true of the
broken version too, which disposed at ~4 s instead of ~12 s. The regression
shipped and was caught by the next round's reviewer, who re-derived the
arithmetic by hand.

**Violation — PR a17k/a17k#371:** a shutdown-hook regression test built a bare
framework instance and registered the hook inline, so it passed whether the
hook lived on the root instance or on the encapsulated child where it never
ran. It did not exercise its own subject.

**Violation — PR a17k/a17k#371:** two rounds later the same suite's
prompt-shutdown test held a *clean* document, so it passed both before and
after the fix that narrowed the shutdown gate; and a field added to a sync
frame one round earlier was asserted nowhere — deleting the line left all 130
tests green.

**Done right — PR a17k/a17k#371:** from round 2 on, every fix on the branch
carried a test explicitly verified failing against the reverted fix ("verified
failing against the revert — times out with only the first frame"). One such
check found that an untested retry arm could be disabled outright — flipping
its cause left the whole suite green — while a database blip during a rollout
would have silently dropped edits already acknowledged to the client.
