# Enumerate every reader before retiring a name

A plan that deletes a config value, table, column, or endpoint is a claim
about *all* of its readers, not just the one that motivated the deletion.
Names describe the intent someone had when adding them, never the full set of
things that came to depend on them, and the second reader is where migrations
break — or destroy data. Before a diff says "delete X at cutover", grep X and
read every hit; the deletion is only safe once each reader is either migrated
or explicitly exempted in the same plan.

## Check

- Grep the name across the whole repo — not just the module being migrated,
  and including background jobs, CLIs, and test fixtures. For each hit, ask
  what breaks the moment the value is absent: does config parsing fail closed,
  or does the value silently become empty?
- Does the name promise less than it does? A value called an allowlist that is
  also a partition key, a client credential that is also a data-API
  credential, a table called an identity copy that is also a foreign-key
  target — each is a deletion that reads as safe and is not.
- For a table or column, read the schema's referential actions. `ON DELETE
  CASCADE` turns "drop the rows we no longer need" into "drop everything that
  pointed at them"; the schema comment saying so is not a substitute for
  checking.
- Distinguish *admission* from *authorization*. A value consulted at the door
  is easy to retire; the same value consulted inside a handler to decide what
  a caller may do needs its replacement wired first.
- When a reader genuinely must survive, say so in the plan next to the
  deletion — rename it to its real role rather than leaving a future
  implementer to rediscover the exception.

## From the history

**Violation — a17k/a17k#421:** a migration plan for a central auth service
slated four things for deletion, and review found a second reader behind every
one. `ALLOWED_EMAIL` was documented as a login allowlist but was also the
mailbox partition key for bundle reads, source binding, the sync scheduler and
the MCP tools. `GOOGLE_CLIENT_ID/SECRET` were also the credentials for a Gmail
refresh-token provider the design deliberately kept local, so deleting them
would have lost mailbox access at the next token refresh. Two services' local
`User` tables were described as identity copies to fold into the central
store, but were domain principals: `ownerId` foreign keys with
`onDelete: Cascade`, whose own schema comments state that deleting a user
wipes their content — the plan as written would have deleted every recipe and
box those users owned. And `ALLOWED_AUTHOR_EMAILS`, retired as an admission
allowlist, was also read inside two handlers to authorize creation, so
deleting it would have stripped author rights from centrally-granted authors.
