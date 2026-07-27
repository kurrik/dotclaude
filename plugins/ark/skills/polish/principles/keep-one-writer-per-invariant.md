# Keep one writer per invariant, and prefer construction over bookkeeping

When a guarantee rests on a counter or a flag — uniqueness of a generation
stamp, a retry budget, a deadline — it holds only while exactly one place
advances it, in the unit the guarantee is denominated in. A second writer, or a
writer spending the budget in a different unit, voids the guarantee silently
while every comment and constant still asserts it. Where a guarantee can hold
by construction (a random token rather than a counter), prefer that: it cannot
be broken by a writer nobody remembered.

## Check

- Grep every assignment to the counter or flag the guarantee names. More than
  one writer means the guarantee is now a convention.
- Is the value's issuer the same object as its consumer? An `allocate` living
  in a registry and a `+= 1` living on the instance are two issuers.
- Does the counter survive a process restart? A per-process counter starting at
  1 collides with values a client from the previous process still holds —
  especially where the deploy strategy guarantees such clients exist.
- Is the budget spent in the unit its comment names? "Five poll cycles ≈ 10 s"
  is fiction if a synchronous drain loop also decrements it three times in
  milliseconds. Count in the loop the unit belongs to.
- After hoisting or narrowing a call, re-derive every bound that call feeds —
  moving it changes *which* paths reach it.

## From the history

**Violation — PR a17k/a17k#371:** an editing session's epoch fenced in-flight
writes so a stale client got a 409 rather than a silent loss. A later round
made the epoch mutable so an external write could re-fence it — but the
registry's allocator advanced only on open while the session bumped its own
copy privately, so a later session could be issued an epoch an earlier one had
published, and a stale client's update applied into a different document under
a 204. "The fence works within a session's lifetime and fails across one."

**Violation — PR a17k/a17k#371:** the follow-up routed both writers through the
single registry counter — and the next round found that counter restarts at 1
in every new process, while the deployment strategy adopted two rounds earlier
guaranteed a client from the old process held old values at exactly that
moment. The two fixes together made collision *more* likely. Only replacing the
counter with an opaque random token closed the class: "uniqueness by
construction rather than by bookkeeping."

**Violation — PR a17k/a17k#371:** a five-cycle retry budget documented as
"~10 s at the poll interval" was cut to a single poll when an unrelated fix
made a synchronous drain loop reach the same accounting line three times back
to back. Both reviewers found it independently; the constant's comment and two
PR replies still claimed 10 s.
