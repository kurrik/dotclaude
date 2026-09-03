---
name: polish
argument-hint: "[--quick]"
description: Frontload the PR review cycle before pushing a branch. Runs up to three reviewers in parallel subagents (the current Claude, Codex, or Grok host's native reviewer, a preferred cross-agent CLI review if installed, and a check against a layered review-principles corpus — general principles bundled with this skill, plus machine-level ~/.claude/review-principles and the repo's .claude/review-principles when present), reads the branch as a whole for structural fixes before patching individual findings, triages and fixes autonomously without expanding scope, commits each round with the feedback and justification in the message, and stops after at most two rounds; --quick runs a single round with the native and corpus legs only. Costly — run it only when the human invokes /ark:polish, or accepts the one-time offer ark:pr makes for a large or sensitive unreviewed diff, or the one ark:review makes when its fixes reshaped the PR. Never run it unprompted.
---

# ark:polish — frontload the review cycle

Move review rounds that would otherwise happen on the PR — human back-and-forth,
paid automated reviewers, push/CI round-trips — into one local loop before the
PR exists. Reviews here are cheaper and faster than reviews on GitHub, but they
are not free: every round is several full-diff subagent reviews plus a triage.

## When this runs

Polish is **opt-in per branch**, not a step on every PR:

- The human invoked `/ark:polish` (or `$ark:polish`), or
- `ark:pr` sized the unreviewed diff (large, or in a sensitive area) or
  `ark:review` found its fixes had reshaped the PR, offered a single polish
  pass, and the human accepted.

Never start polish on your own judgment, and never repeat work already
done on the same branch tip. Whether work is already done is not a matter
of memory or of reading commit subjects: it is the output of one script,
`polish-state.sh`, shared with `ark:pr` (see **Scripts** below). Run it
after Step 1 has committed any dirty work — an uncommitted change means
there is no covered tip yet — and act on its `state`:

| `state` | Meaning | Action |
|---|---|---|
| `covered` | a full run ended `ready` at `HEAD` | Say so and stop. |
| `unverified` | a quick run ended `ready` at `HEAD` | A full invocation upgrades it (see **Modes**); a second quick invocation stops. |
| `not-ready`, `at_head=yes` | the last run parked something or was round-capped | Say what was parked (`reason`, and the record commit's body) and stop, unless the human says to proceed anyway. |
| `not-ready`, `at_head=no` | commits landed after a parked run | The invocation is the go-ahead: run normally over the whole diff, carrying the parked items into triage so they are resolved or re-parked; the new record supersedes. |
| `unreviewed` | no record, or commits after a `ready` one | Run normally over the whole branch diff. |

The verdict belongs to the branch until a later run replaces it; coverage
belongs to the tip. That is the whole rule, and the script encodes it.

## Scripts

Mechanics live in tested scripts under the plugin's `scripts/` directory
(`../../scripts/` relative to this SKILL.md; resolve it to an absolute
path before use, and before handing it to a subagent). Skills state
policy; scripts do the work, so `ark:pr`, `ark:review`, and this skill
cannot drift apart on how a base is resolved, how a tip's state is read,
or what a push checks:

| Script | Does | Exit |
|---|---|---|
| `resolve-base.sh` | fetch, print `origin/<default branch>` | 2 on fetch failure |
| `polish-state.sh <base>` | key=value state of the tip (`state`, `record`, `mode`, `verdict`, `reason`, `at_head`, `round_start`, `unreviewed_from`, `unreviewed_commits`, `dirty`) | 2 on git error |
| `polish-record.sh --mode m --verdict v [--reason r] [--body-file f]` | write this run's verdict as the trailers at `HEAD` (amend the run's own unpushed round commit, else an empty record commit) | 2 on git error |
| `scan-secrets.sh <base>` | every commit's paths, added lines, and message in `<base>..HEAD`, high-confidence shapes only; a committed `.ark-scan-ignore` exempts fixture paths | 1 hits, 2 error |
| `push-branch.sh <base> [--override-scan "<why>"]` | `scan-secrets.sh`, then push with upstream — the only way a skill pushes; the override is passed only on the human's explicit say-so after seeing the hits | 1 refused, 2 error |

## Modes

The invocation's arguments select the mode; anything else after the skill
name is ignored.

| Mode | Invocation | Rounds | Legs |
|---|---|---|---|
| Full (default) | `/ark:polish` | up to 2 — a full round, then a verification round | native + external CLI + corpus, then native + corpus |
| Quick | `/ark:polish --quick` | exactly 1 | native + corpus; the external CLI leg is never launched |

Quick mode is the cheap first look: same ground rules, same architecture
pass, same commit format, but one round and no cross-agent review. It stops
after committing round 1 even when fixes landed — the report says what was
fixed and that the fixes are unverified by a second round, so the human can
decide whether a full run is worth it. A quick run that ends clean, on
diminishing returns, or after committing its fixes records `Verdict: ready`
with `Mode: quick`; a quick run that parks anything for the human records
`Verdict: not-ready` like any blocked run — committing one fix does not make
a blocked run ready.

**Upgrading a quick run.** A full invocation on a tip whose state is a
quick run's `ready` does not repeat round 1. It runs exactly what quick
skipped: the external CLI leg over the full branch diff (`<BASE>...HEAD`)
concurrently with the verification round (Step 2's native and corpus legs,
scoped to the quick run's fix commits — `round_start` from
`polish-state.sh`, which walks back through every adjacent record commit
since Step 4 allows one round to make several), then triages the combined
findings as round 2 and stops under the normal Step 5 rules. The verification legs
carry round 2's severity filter for untouched code; the external leg does
**not** — it is seeing the branch for the first time, so every finding it
reports is a round-1 finding and is triaged in full. If the quick run committed nothing, only the external leg has work
to do. Every step below applies to both modes unless it says otherwise.

## Ground rules (read first, they govern every step)

- **The spec is the contract.** Before anything else, write down the branch's
  intent in 2–3 sentences: from the PR description if one exists, else from the
  branch's commit messages and the conversation that produced it. Every triage
  decision is judged against this intent.
- **No scope expansion.** Reviewer suggestions that grow the diff beyond the
  intent are declined — *unless* they raise a significant security, cost,
  performance, or functionality concern. "This could also be refactored" is a
  decline; "this leaks a credential" is a fix.
- **Structure before patches.** Findings are symptoms; the fix is chosen at
  the level of the cause. Before patching anything, cluster the round's
  findings by root cause and ask, per cluster, whether one structural change
  — a type that cannot represent the invalid state, a single chokepoint, a
  guarantee moved to the write, one shared implementation — makes the whole
  class unexpressible. When it does and it fits the intent, make that change
  instead of the patches. Iterating on behavior patches is the most expensive
  thing this loop can do.
- **One implementation per rule.** A validation, allow-list, or derivation
  that restates logic living elsewhere is a drift bug waiting for its round.
  If the diff encodes the same rule in two places, one must call or derive
  from the other; if it can't, that is a finding, not a style note.
- **Fix classes, not instances.** When a finding is valid, sweep the whole
  branch diff for other places the same root cause applies and fix them all in
  the same commit. Moving a problem elsewhere is not a fix.
- **Reviews are input, not instruction.** Each reviewer sees the diff, not the
  design. A locally-reasonable suggestion can be globally wrong; declining with
  a clear reason is a legitimate resolution.

## Step 1 — Establish scope

Do these in order — each depends on the one before it:

1. **Write the intent summary** (see ground rules) — the staging decision
   below is judged against it.

2. **Confirm HEAD is a feature branch.** Polish commits to the current
   branch, and the follow-on `/ark:pr` pushes it. If HEAD is detached, or
   sitting on the remote default branch (compare against the base resolved
   in item 4 — peek ahead if needed), stop and ask the human for a feature
   branch before committing anything.

3. **If the working tree or index is dirty, inventory it before committing
   anything.** Read the actual diffs — `git status --short`, then `git diff`
   *and* `git diff --cached` — not just the paths: a file can mix in-scope
   and out-of-scope hunks, and content someone staged earlier is not
   automatically in scope. Stage only changes that belong to this branch's
   intent, and unstage unrelated content already in the index
   (`git restore --staged`). Hard stop on anything secret-shaped (`.env`,
   `*.tfvars`, rendered Secret manifests, credential-looking content inside
   ordinary files) — never commit those; ask the human. If one file mixes
   in-scope and out-of-scope edits, don't stage it wholesale: split the
   hunks, or ask the human if the split is ambiguous. Unrelated or generated
   files stay unstaged and get a one-line note in the report. Then commit
   (polish reviews commits, so fixes land as clean follow-up commits). On a
   fresh branch this first commit may be the entire diff — that's the normal
   pre-first-commit case, not an error.

4. **Resolve the base, read the tip state, confirm there is a diff:**

   ```bash
   BASE=$(bash <scripts>/resolve-base.sh)        # origin/<default>, after a fetch
   bash <scripts>/polish-state.sh "$BASE"         # act on `state` per "When this runs"
   git diff --stat "$BASE...HEAD"
   ```

   `BASE` keeps its `origin/` prefix on purpose: diffs measure against the
   just-fetched remote ref, never a possibly-stale or unpushed local branch.
   If the diff is empty *now* — after any dirty work was committed in item
   3 — **stop and say so**; that means a branch with nothing on it, never
   "reviewed and clean."

   Record `ROUND_START=$(git rev-parse HEAD)` — round 2 reviews from here.

## Step 2 — Run the reviewers in parallel

**Before any leg launches, gate the egress.** The external CLI leg sends
the branch diff to another vendor's service, and a later hard stop cannot
undo that disclosure. Run `scan-secrets.sh "$BASE"` (see **Scripts**); exit 1 is a hard stop
for the whole run — show the hits, launch nothing, and ask the human; if
they confirm a false positive, continue, and say so in the report. Exit
2 is a scan error: stop as well rather than reviewing unscanned. Every
push goes through `push-branch.sh`, which scans again, so a credential a
polish fix introduces is caught at the next egress.

Up to three legs in round 1; two in round 2 (see **Round 2 is a
verification round** below); two in quick mode, which has no round 2. First identify the current host from the
active session — Claude Code, Codex, or Grok — **not** from which
executables happen to be on `PATH`. Then select the native and external
reviewers from this matrix:

| Current host | Native reviewer | Preferred external CLI | Fallback |
|---|---|---|---|
| Claude Code | Claude internal review via a general-purpose Agent | `codex review` | none |
| Codex | Codex internal review via a general-purpose subagent | `claude -p` | none |
| Grok | Grok internal review via `spawn_subagent` | `codex review` | `claude -p` |

Never shell out to the current host's own CLI. That review is redundant with
the native leg, and nested same-agent sessions can collide with the parent's
app server, sandbox, or session state. Before launching, check only the CLI
selected by the matrix: `command -v codex` from Claude Code; `command -v
claude` from Codex; and `command -v codex` first from Grok, checking
`command -v claude` only as Grok's fallback if Codex is absent or if the Codex
leg later fails before producing a review. Grok must not launch both external
CLIs together — Codex is its preferred second opinion, and Claude is a
sequential failure fallback only. The native and corpus legs are always
available (the corpus's general layer ships with this skill). An unavailable
external leg is skipped with a one-line note in the report — that's a smaller
panel, not a failure. Launch every initially selected leg concurrently; do not
run them serially except for Grok's failure fallback.

In Grok, launch each leg through `spawn_subagent` with `background: true`.
Use `subagent_type: general-purpose` and `capability_mode: execute` for review
legs: that mode permits reading, searching, and shell inspection while
withholding file-edit tools. Retrieve every result with
`get_command_or_subagent_output` after all legs have launched.

**Every leg reports in the same compact shape** — it keeps triage cheap and
makes the legs dedupable:

```
## Findings
| # | Sev | file:line | Finding | Concrete failure scenario |
## Architecture
<1–3 observations about the change as a whole, or "none">
## Checked
- <area>: clean
```

Findings are correctness, security, performance, and convention defects
only, each adversarially self-verified before it is reported; no style. The
**Architecture** section is where the reviewer steps back from the hunks and
reads the branch as one design. It answers, briefly: Which findings share a
root cause? Where is a guarantee held by convention (a comment, a counter,
callers remembering to check) rather than by construction? Where does the
diff restate a rule that already exists elsewhere — a validation mirroring
the logic it guards, a client re-deriving a server rule, an enum copied into
a list — without sharing code? What one change would make the largest class
of these findings impossible? "None" is a valid answer; a paragraph of
generalities is not.

1. **Native/internal reviewer** (always available) — run the current host's
   internal review through its general-purpose subagent mechanism (Claude's
   Agent tool in Claude Code; Codex's subagent delegation in Codex; Grok's
   `spawn_subagent` in Grok). Have it review the full branch diff
   (`git diff -M <BASE>...HEAD`) as a rigorous code reviewer in the shape
   above, with the intent summary as context so it can judge the design and
   not just the hunks. Record this leg as `claude-native`, `codex-native`, or
   `grok-native` according to the current host.

   In Claude Code or Grok, do NOT try to invoke the host's built-in
   `code-review` skill — it may be `disable-model-invocation` and reserved for
   the human typing `/code-review`. Use the explicit native subagent review
   above. If the human has already run a native review this session AND its
   report covers the current diff, fold that report into triage instead of
   spawning a duplicate reviewer. A report from before this round's fixes is
   stale — spawn a fresh reviewer; this check re-applies every round.

2. **External CLI reviewer** (full mode, round 1 only, if the opposite CLI
   is installed; never in quick mode) — launch it inside a general-purpose native subagent so it runs
   concurrently with the other legs and its failure stays isolated. Record
   the leg as `codex-cli` or `claude-cli` according to the executable that
   actually ran. It runs in round 1 only: a cross-agent review of the whole
   diff is the expensive leg, and round 2 verifies fixes rather than
   re-discovering the branch.

   **From Claude Code, or from Grok when Codex is available**, run from the
   repo root:

   ```bash
   codex review --base <BASE>
   ```

   No custom PROMPT argument: codex treats the scope flags (`--base`,
   `--uncommitted`, `--commit`) and custom instructions as mutually exclusive
   modes — combining them is a usage error. Pass the same `origin/`-prefixed
   BASE; if codex rejects the remote-ref form, retry once with the short branch
   name and say so in the report.

   **From Codex, or from Grok only when Codex is unavailable or its review leg
   failed before producing findings**, run from the repo root:

   ```bash
   claude -p \
     "Review the full branch diff from <BASE> through HEAD. Run git diff -M <BASE>...HEAD, inspect the relevant files, and report only correctness, security, performance, or repository-convention defects. For every finding give severity, file:line, and a concrete failure scenario, and adversarially verify it before reporting. Then add an Architecture section: 1-3 observations about the change as a whole — findings that share a root cause, guarantees held by convention rather than construction, and logic restated in two places without shared code — or 'none'. Do not modify files. Include one short checked line for areas that are clean." \
     --permission-mode dontAsk --no-session-persistence \
     --allowedTools "Bash(git diff -M <BASE>...HEAD)" \
     --tools Bash,Read,Grep,Glob
   ```

   The prompt is intentionally self-contained: do not ask Claude to invoke
   `ark:polish`, `/code-review`, or another nested orchestration workflow.
   Substitute the same `origin/`-prefixed BASE in both the prompt and
   `--allowedTools`. Keep the Bash permission exact: broader patterns such as
   `Bash(git diff *)` also allow write-capable options like `--output`.

   Give either external CLI call a 10-minute timeout — reviews take minutes.
   The subagent returns the findings verbatim (reshaped into the compact
   shape above if the CLI's output differs), plus a one-line note if the CLI
   errored (sandbox, auth, network, timeout) rather than papering over it.

3. **Corpus reviewer** (always available) — the corpus is layered across up
   to three directories, most general first:

   1. **Bundled** — the `principles/` directory next to this SKILL.md
      (inside the installed plugin's `skills/polish/` directory). Always
      present; resolve it to an absolute path before spawning the subagent —
      the subagent won't know where the skill lives.
   2. **Machine** — `~/.claude/review-principles/`, if it exists
      (machine-specific, cross-repo rules).
   3. **Repo** — `.claude/review-principles/` at the repo root, if it exists
      (repo-specific rules, evidence, and overrides).

   Spawn a native general-purpose subagent, passing it the absolute paths of
   the layers that exist, instructed to:
   - Read every principle file in each layer (skip each layer's
     `README.md`). Files with the same name in more than one layer are the
     *same principle*: read them together, with the deeper layer
     (repo > machine > bundled) augmenting the rule and winning outright
     where they conflict — a repo file may narrow, extend, or explicitly
     suspend a bundled rule.
   - Read the full branch diff (`git diff -M <BASE>...HEAD`).
   - For each principle, check whether the diff violates it. Report only real
     violations, citing the principle filename and the offending hunk, in the
     compact shape above (the principle filename goes in the Finding column).
     Its Architecture section names the principles whose violations would
     collapse together under one structural change. Confirm principles that
     were checked and hold — one line each — so silence is distinguishable
     from "not checked".

Wait for every launched leg to complete before triaging: the triage step
needs the full set to dedupe overlapping findings and spot patterns no single
reviewer saw.

**If a launched leg fails outright** (tool error, auth failure, timeout):
continue with the legs that ran, and record the failure in the round's commit
message — or in the final report, if the round produces no commit — so the
trailer never claims a reviewer that didn't run. If no leg produces a review,
stop and tell the human — zero reviewers isn't a polish loop. If only one leg
ran (by availability or by failure), proceed, but say prominently in the
report that the panel was a single reviewer.

On Grok only, if the preferred `codex-cli` leg fails before returning a review,
launch one `claude-cli` fallback when Claude is installed. Record the Codex
failure, but list only `claude-cli` as the external reviewer that actually ran.
Do not fall back after Codex returned findings, even if those findings are
empty; an empty successful review is still a completed second opinion.

**Round 2 is a verification round.** It runs only the native and corpus
legs, and each gets the round-1 findings with their triage verdicts as
context. They read the fix commits first (`git diff -M <ROUND_START>..HEAD`)
and the full branch diff only as far as needed to check three things: each
fix actually closes its finding (not just the flagged line — the class);
the fix commits introduce no new instance of a class already flagged on the
branch; and nothing an earlier fix established was dropped by a later one.
Anything *inside the fix commits* is reported at every severity — fix code
is new code, and a patch that also changed an adjacent condition is exactly
what this round exists to catch. The severity filter applies only to code
the fixes did not touch: pre-existing findings round 1 missed are reported
at high severity only, so round 2 verifies rather than re-discovers. The
one exception: if round 1's structural pass reshaped the branch (Step 3a
chose a restructuring over patches), round 2 reviews the full diff again
with the same two legs — a new shape deserves a fresh read.

## Step 3 — Triage and fix

Merge the finding lists and dedupe (reviewers overlap heavily). Then work in
two passes — the order matters.

### 3a — Architecture pass (before any fix)

Take the merged findings plus every leg's Architecture section and cluster
by root cause, not by file. For each cluster, and for any single finding
that lands on an area a previous round already fixed, decide the fix
*level* before writing a line:

- **Structural** — one change removes the whole class: a type or schema
  that cannot represent the invalid state; one chokepoint (constructor,
  parser, repository method) through which every path must go; the
  guarantee moved to the state transition (a guarded write, a DB
  constraint) instead of a check before it; one implementation that the
  other copies call or derive from; an explicit state machine in place of
  scattered flags. Choose this whenever it fits the intent summary and the
  cluster has two or more members, or is a repeat of an earlier round.
- **Patch** — a local fix at the flagged site plus its siblings (the
  fix-classes ground rule). Acceptable for a singleton finding with no
  structural cause.
- **Park** — the structural fix is right but exceeds the intent (a schema
  redesign, a new abstraction the branch didn't set out to introduce).
  Record the structural option in the report for the human; do not
  substitute a stack of patches for it.

Also run the one-implementation check here even when no reviewer raised it:
does the diff add a validation, allow-list, mapping, or derived value that
restates logic owned elsewhere (the business rule it guards, a server-side
rule, a schema, an enum)? Point the copy at the owner or derive it; a
comment saying "keep in sync with X" is the finding, not the fix.

Write the pass down — one line per cluster with the chosen level and why —
it goes into the commit message and the report.

### 3b — Per-finding triage

For each unique finding not already resolved by a structural change:

| Verdict | Action |
|---|---|
| Real defect | Fix it, plus every sibling instance in the branch (see ground rules) |
| Valid concern, wrong suggested fix | Fix the underlying concern the way that fits the branch's design |
| Scope expansion without a significant security/cost/perf/functionality concern | Decline; record one-line reason |
| Conflicts with the intent summary | Decline; record reason |
| Needs the human (design decision, unclear requirement, direction change) | Park it — see exit conditions |

After fixing, do a holistic pass over the *new* full diff: fixes must compose
(consistent naming, no fix contradicting another, no relocated problems).
Then run the repo's checks and fix failures: use whatever the repo's
CLAUDE.md / AGENTS.md / contributing docs name as the standard pre-commit
check (lint, typecheck, fast tests); if nothing is documented, run the
project's standard build/test command for its toolchain. Skip the checks
when the round changed nothing. If Step 1 left unrelated changes unstaged,
the checks are validating the working tree, not the commit — before acting
on a failure, confirm it comes from the branch diff rather than the
unrelated files (does it implicate them? does it reproduce without them,
e.g. in a clean worktree at HEAD?); a failure owned by the unrelated files
gets a note in the report, not a fix here.

## Step 4 — Commit the round

If the round produced no file changes — clean round, or every finding was
declined/parked — there is nothing to commit: skip this step, carry the
decline/park reasons into the final report, and go straight to Step 5.

Otherwise, one commit per review round (or per coherent group of fixes). The
commit message must carry the audit trail:

```
polish: address round N review feedback

Structure:
- <cluster> — structural: <the change and the class it removes>
- <cluster> — patch: <why no structural cause>

- <finding, one line> — <what was done and why>
- <finding declined> — declined: <one-line justification>

Reviewers: codex-native, claude-cli, review-principles
Mode: full
Verdict: pending
```

List only the legs that actually ran (see the failure rule in Step 2).
`Mode:` is `full` or `quick`; `Verdict:` is written as `pending` here and
set by Step 6, so a run that dies mid-loop leaves a record `ark:pr` reads
as not ready. `polish-state.sh` finds the record by the `Verdict:` trailer,
never by the subject; keep the `polish:` subject prefix anyway so
`ark:improve-polish`, which reads audit trails, still finds the rounds.

If a finding revealed a lesson not already covered by any corpus layer,
route it by scope. Repo-specific lessons: if the repo has a
`.claude/review-principles/` layer, follow its admission rule (typically in
its README — e.g. requiring evidence from real merged-PR review history);
evidence from this branch's own polish rounds never qualifies on its own. If
real review history backs the lesson, draft the principle file in the same
commit; otherwise list it in the final report as a corpus candidate for the
human to promote once history exists. If the repo has no corpus directory,
don't create one unasked — put the candidate in the report. Lessons that
generalize beyond the repo: never edit the bundled or machine layers
mid-polish — list them in the report as candidates for those layers.

## Step 5 — Loop or stop

After round 1, run round 2 (the verification round in Step 2) only if round
1 committed fixes — and never in quick mode, which ends after round 1
regardless. **Stop when any of these hits:**

- **Blocked on a human** — a parked finding needs a design decision, or a
  reviewer raised something that would mean significant rework or a direction
  change. Stop and present it; do not guess.
- **Diminishing returns** — the round produced only nits, edge-cases outside
  realistic use, or re-litigation of already-declined items. Say so and stop;
  the goal is shipping the core feature promptly, not a zero-findings state.
- **Clean round** — no findings above the bar. Done.
- **Same area, second time** — round 2 re-flags an area round 1 patched.
  Do not patch it again: either make the structural change Step 3a should
  have chosen, or park it for the human. A third patch on one area is the
  loop this skill exists to prevent.
- **Round cap** — two rounds. A branch that still has real findings after a
  full review and a verification round is disagreeing with its reviewers
  about something a human should look at; say what it is.

## Step 6 — Report

Summarize: the mode, rounds run, which reviewer legs ran (and which were skipped or
failed), the architecture pass (each cluster and the level chosen — the
structural changes made and the ones parked), findings fixed / declined /
parked per round (with the one-line reasons), any new principle files added,
and exactly what needs the human's input. End with an explicit readiness
verdict: after a clean or diminishing-returns exit the branch is ready for
`/ark:pr`; after a blocked or round-capped exit, say plainly that it is
**not** ready and what must be resolved first. A quick run that committed
fixes is ready with a caveat: say the fixes had no verification round and
that `/ark:polish` (full) is the way to get one. A quick run that parked
anything is not ready, caveat or no caveat.

Then record the verdict — every run ends with a record at `HEAD`:

```bash
bash <scripts>/polish-record.sh --mode <full|quick> --verdict <ready|not-ready> \
  [--reason "<one line>"] [--body-file <parked findings>]
```

It rewrites the `Verdict: pending` trailer on this run's own unpushed round
commit, or, when the run committed nothing (or `HEAD` is a pushed record
from an earlier run), creates an empty record commit carrying the body —
for `not-ready`, the parked findings, so they travel with the branch and a
later session's `ark:pr` stops on them. That empty commit is an
audit-trail entry, not a CI kick; the script decides which case applies,
so the amend-versus-new decision is never made in prose.
