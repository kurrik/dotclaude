# Don't acknowledge work you haven't made durable

Any design that accepts a write, answers success, and persists later owes a
trace of every path between the acknowledgement and durability. Shutdown,
teardown, disposal, error, and rebuild paths are where accepted work
disappears — and it disappears silently, because the caller was already told it
landed. Enumerate those paths when the buffer is introduced, not when a
reviewer names one.

## Check

- List every way the in-memory holder of accepted-but-unwritten work can go
  away: process shutdown, last-consumer-disconnects, idle expiry, a failing
  flush, an invalidation, a rebuild from the source of truth. What happens to
  the buffer in each?
- Does the flush actually run on shutdown? A teardown hook that fires *after*
  the framework waits for in-flight requests never runs when the connection you
  hold is deliberately long-lived.
- Once shutdown begins, is the *accept* path closed too? A request already
  inside the handler can land after the final flush and before teardown.
- Retrying a failed flush: is it bounded, and does the bound leave the work
  recoverable or say plainly that it is lost? Unbounded retry reintroduces the
  leak the disposal existed to close.
- Is the success response emitted before or after the durable step? If before,
  every branch above is a data-loss branch and belongs in the tests.

## From the history

**Violation — PR a17k/a17k#371:** a service accepted editing updates with 204
and reconciled them to the database on a debounce. Over four rounds reviewers
found four separate paths from ack to loss: the shutdown flush hook ran only
after the framework waited for in-flight requests, and the stream it needed to
flush never ends, so it never ran at all and a watchdog force-exited; a
transient database error while the last client disconnected discarded the
session outright; updates were still accepted after shutdown began and were
destroyed moments later by the invalidation loop; and a stale generation stamp
let an update apply into a replaced document. Every one returned success first.

**Violation — PR a17k/a17k#371:** the author had previously recorded graceful
shutdown as verified — "but that run had no stream open, so it proved nothing."
The teardown path is the one least likely to be exercised by an incidental
test.

**Done right — PR a17k/a17k#371:** the bounded-retry fix named its own residual
in the commit rather than hiding it behind an unbounded retry: after the
budget, "the edits are unrecoverable by any means this process has, and saying
so is better than pretending otherwise."
