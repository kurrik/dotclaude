# Fix at the owning layer, not per call site

Normalization, validation, and lifecycle state belong at the boundary that
owns them — the config schema, the repository layer, the page-level state —
not sprinkled across the comparison sites, request handlers, or components
where a reviewer happened to spot the symptom. Per-site patches guarantee the
unpatched site becomes next round's finding.

## Check

- Normalizing a value (email casing, trimming)? Do it once where the value
  enters the system (e.g. the Zod schema), not at each comparison.
- Guarding a state invariant? Validate the *effective merged state* after the
  update, not whichever request fields happened to be present — a PATCH
  carrying only `{enabled: true}` must hit the same validation as one
  carrying the full object. Fix API and UI in the same round.
- UI state being destroyed by unmount/refresh? Lift it to the owning
  container once, instead of guarding each unmount path as it's discovered.
- Introducing a config knob, admin field, or env var? Bounds/format
  validation lands in the same commit, at the boundary — and a UI input's
  parse must distinguish "invalid" from "deliberately cleared."

## From the history

**Violation — PR #331:** reply drafts lived in component-local state; four
rounds each preserved drafts across one newly-discovered unmount path
(post-submit refresh, collapse, hide-resolved, thread refresh). The root
cause — "reply text destroyed on unmount" — was named in round 1; lifting
draft text to page-level state closes all four at once.

**Violation — PR #330:** pinned-email normalization was patched at the launch
path, then re-flagged at the boot path. The fix that ended it normalized
`ASSISTANT_OWNER_EMAIL` in the Zod schema — "from one place, instead of
patching each comparison." No further casing findings.

**Violation — PR #319:** the "enabled channel needs a sink-backed binding"
invariant took four rounds because each fix guarded one request shape or one
layer — explicit re-points, then the UI advertising what the API rejects,
then a PATCH with only `{enabled: true}` skipping the lookup entirely.

**Violation — PR #309/#339:** a TTL, a server-name field, and a timeout input
each drew a round for missing bounds validation — every one introduced
earlier in the same PR it was flagged in.
