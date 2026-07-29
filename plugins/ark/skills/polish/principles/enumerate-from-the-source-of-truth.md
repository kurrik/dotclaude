# Enumerate from the source of truth

When correctness depends on the complete membership of a set — statuses,
enum values, tool names, address ranges, config keys, entities in a diagram,
the valid shapes of a relationship — build the list from the authoritative
source, never from memory or from the examples the reviewer happened to name.
And treat "X is missing from this list" as "this list was never verified
complete," not as "append X."

## Check

- Where does the full set actually live (the dependency's source, the SDK's
  tool list, the IANA registry, `config.ts`'s env assembly)? Read it; don't
  reconstruct it.
- Prefer the covering rule to enumerated members: block the `/23`, don't list
  three of its sub-blocks. Prefer an allowlist of known-good over a
  hand-built denylist of known-bad.
- A relationship modeled by more than one foreign key (both `A.b_id` and
  `B.a_id`) has more than one valid shape. Enumerate the shapes from the
  schema before asserting a single-direction equality; a one-way check
  silently rejects the other-way-valid rows.
- After an incompleteness finding, reconcile the *entire* list against its
  source before replying — the named item is the sample, not the defect.

## From the history

**Violation — PR #342:** the round-1 fix added three individually enumerated
IPv6 ranges; round 2: "three of these rows are sub-blocks of one range…
Enumerating members of it leaves the siblings passing." Blocking IANA's
`2001::/23` was the correct shape from the start.

**Violation — PR #353:** a from-memory denylist of terminal pipeline statuses
missed three; the author then read Woodpecker's `server/model/const.go`,
found the full enum, and inverted to an allowlist (`pending, running,
success`) — closing the class permanently in one round.

**Violation — PR #339:** the built-in tool denylist took three mentions
across rounds ("Still incomplete (third mention)… `BashOutput`, `KillShell`")
— the SDK's full tool-name list was checkable when the list was first
written.

**Violation — PR #314:** "`ProcessedEvent` doesn't appear in the ER diagram"
was fixed by adding exactly the two named entities to a not-shown note;
round 3 found `AgentRun` missing from both. One reconciliation of the full
entity list would have caught it in round 1. The same PR's config-surface
inventory (redirect URI, SA key, Pub/Sub, HMAC kinds) leaked out over three
rounds for the same reason.

**Violation — ArchAstro/firstlanding#8910:** a residence check validated an
org/sandbox pair with one equality (`org.sandbox_id == viewer.sandbox_id`) and
rejected a valid pair — the schema models the relationship in *both* directions
(`orgs.sandbox_id` and `developer_sandboxes.org_id`), and the production shape
uses the second, which the one-directional check never considered. The two
`belongs_to` edges are the source of truth for the valid shapes; a reviewer's
P1 forced the second direction a round later.
