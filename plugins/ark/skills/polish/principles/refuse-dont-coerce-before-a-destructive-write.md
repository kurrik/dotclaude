# Refuse, don't coerce, when the value feeds a destructive write

A reader that degrades unparseable input to an empty or default value is often
right for display — a malformed record should not take the page down. It is
dangerous when the same reader feeds a write that *replaces* what it reads:
"I cannot interpret this" and "the user deleted everything" become
indistinguishable, and the destructive reading wins under a success response.
Split the two — degrade when rendering, refuse when persisting.

## Check

- Trace every consumer of a lenient parser or coercion. Does any of them feed a
  delete-and-recreate, a full replace, a sync-to-target, or an overwrite?
- For a replace-all write, ask what an *absent* key reads back as. If missing
  and empty are the same value downstream, absence is a deletion instruction
  the sender never gave.
- Fixing a wrong-type case? The absent case, the null case, and the
  wrong-container case are the same class — enumerate all of them, not the one
  the reviewer demonstrated.
- Where refusal is the fix, make it a first-class reportable state (a blocked
  flag, an error the caller can render), not a throw that takes the whole
  session down — the reason the lenient read exists is still valid.

## From the history

**Violation — PR a17k/a17k#371:** a CRDT-to-domain reader deliberately degraded
a wrong-typed node to an empty collection and argued for it in its own
docstring — correct for rendering. The same read fed a replace-children
database write, so a version-skewed client sending `notes` as a text node read
back as `[]`, passed schema validation, and permanently deleted every stored
note while the request returned 204. Author: "I'd not carried that reasoning
through to the fact that the same read feeds a replace-children write."

**Violation — PR a17k/a17k#371:** the fix added a structure check but
explicitly exempted *absent* keys, reasoning that a document is empty before
its first sync. The next round found that reasoning doesn't hold on the
persistence path, where the session seeds every key before accepting any
update: an ordinary `Map.delete('notes')` is then indistinguishable from a
mistyped node and erases the same rows. "The instance I explicitly exempted
when fixing the wrong-type case last round, which makes it the better catch of
the two."

**Done right — PR a17k/a17k#371:** the eventual fix left the readers unchanged
and added a separate structural validator consulted only before writing, so the
split is explicit — "degrade when displaying, refuse when persisting" — with
the refusal surfaced through the existing user-visible blocked state rather
than thrown.
