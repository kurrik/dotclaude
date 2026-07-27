# Fix the class, not the instance

When a finding names one line, the defect is almost always a *class* with
siblings elsewhere in the branch. Fixing only the named instance is the single
most common cause of extra review rounds in the history this corpus was mined
from — the next round reliably finds the sibling. Before writing the fix,
define the class in one sentence and enumerate every instance.

## Check

- State the class ("any `${VAR:-}` in Woodpecker YAML", "any FK into a
  channel-scoped table", "any exit path after code exchange"). Is it greppable?
  Then grep the whole branch, not the flagged file.
- Enumerate the *sites*, not just the lines: every render path for the data
  (history rows, live message, empty-state), every install/consumption site for
  the config (including generated or copied bundles in Docker stages), every
  publish-capable CI step, every write surface (create, PATCH, link, UI action,
  bootstrap).
- If the class recurs across PRs, propose a lint/CI gate so it stops being
  review-findable at all.

## From the history

**Violation — PR #353:** round 2 flagged `${WOODPECKER_API_TOKEN:-}` being
consumed by Woodpecker's `EnvVarSubst` before the shell sees it. The fix
changed that variable only. Round 6 flagged `${FAIL_REASON:-unknown}` — "the
exact hazard this file documents 350 lines above." Author: "the third instance
of the same class on this branch." The class was a one-line grep.

**Violation — PR #315:** composite-FK hole flagged on `Message.thread` /
`AgentRun.thread`; fixed only those two. The identical hole was re-flagged on
`Thread.parent` and `EventSubscription` the next round, and on
`Message.agentRunId` the round after — three rounds, one schema file, one
auditable rule.

**Violation — PR #359:** Yarn's `unsafeHttpWhitelist` fix landed in the
repo-root `.yarnrc.yml`; round 3 found it "doesn't reach this install site —
or 7 of its siblings" (generated `.yarnrc.yml` in `/app/dist` bundles); round
4 found yet another in `/app`. `grep -r 'yarn install\|yarn add' infra/docker/`
enumerated all sites in seconds.

**Done right — PR #353:** after the third EnvVarSubst instance, the author
added `scripts/check-woodpecker-substitution.mjs` as a CI gate — the class
stopped being review-findable entirely.

**Done right — PR #132:** a cleanup-resilience class spanning five files was
closed in a single commit; reviewers confirmed rather than re-flagged.
