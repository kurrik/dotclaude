---
name: polish
description: Frontload the PR review cycle before pushing a branch. Runs up to three reviewers in parallel subagents (the current Claude, Codex, or Grok host's native reviewer, a preferred cross-agent CLI review if installed, and a check against a layered review-principles corpus — general principles bundled with this skill, plus machine-level ~/.claude/review-principles and the repo's .claude/review-principles when present), triages and fixes their findings autonomously without expanding scope, commits each round with the feedback and justification in the message, and loops until findings are exhausted, nitty, or need a human. Use before /ark:pr, or whenever asked to polish a branch for review.
---

# ark:polish — frontload the review cycle

Move review rounds that would otherwise happen on the PR — human back-and-forth,
paid automated reviewers, push/CI round-trips — into one local loop before the
PR exists. Reviews here are cheap and immediate; reviews on GitHub are not.

## Ground rules (read first, they govern every step)

- **The spec is the contract.** Before anything else, write down the branch's
  intent in 2–3 sentences: from the PR description if one exists, else from the
  branch's commit messages and the conversation that produced it. Every triage
  decision is judged against this intent.
- **No scope expansion.** Reviewer suggestions that grow the diff beyond the
  intent are declined — *unless* they raise a significant security, cost,
  performance, or functionality concern. "This could also be refactored" is a
  decline; "this leaks a credential" is a fix.
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

4. **Resolve the base and confirm there is a diff to review:**

   ```bash
   git fetch -q origin
   BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null ||
     git ls-remote --symref origin HEAD 2>/dev/null |
     awk '/^ref:/ { sub("refs/heads/", "origin/", $2); print $2 }')
   BASE=${BASE:-origin/main}
   git diff --stat ${BASE}...HEAD
   ```

   `BASE` keeps its `origin/` prefix on purpose: diffs must measure against
   the just-fetched remote ref, not a possibly-stale local branch.
   `origin/HEAD` is often unset in locally-initialized clones, so the second
   resolver asks the remote for its advertised HEAD; `origin/main` is only
   the last-resort guess, and every fallback must be executable — a comment
   is not a fallback. If the diff is empty *now* — after any dirty work was
   committed in item 3 above — **stop and say so**; that means a broken BASE
   or a branch with nothing on it, never "reviewed and clean."

## Step 2 — Run the reviewers in parallel

Up to three legs. First identify the current host from the active session —
Claude Code, Codex, or Grok — **not** from which executables happen to be on
`PATH`. Then select the native and external reviewers from this matrix:

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

1. **Native/internal reviewer** (always available) — run the current host's
   internal review through its general-purpose subagent mechanism (Claude's
   Agent tool in Claude Code; Codex's subagent delegation in Codex; Grok's
   `spawn_subagent` in Grok). Have it review the full branch diff
   (`git diff -M <BASE>...HEAD`) as a rigorous code reviewer: correctness,
   security, performance, and convention findings only; each finding needs
   severity, file:line, and a concrete failure scenario; each must be
   adversarially self-verified before reporting; clean areas get one "checked"
   line. Record this leg as `claude-native`, `codex-native`, or `grok-native`
   according to the current host.

   In Claude Code or Grok, do NOT try to invoke the host's built-in
   `code-review` skill — it may be `disable-model-invocation` and reserved for
   the human typing `/code-review`. Use the explicit native subagent review
   above. If the human has already run a native review this session AND its
   report covers the current diff, fold that report into triage instead of
   spawning a duplicate reviewer. A report from before this round's fixes is
   stale — spawn a fresh reviewer; this check re-applies every round.

2. **External CLI reviewer** (if the opposite CLI is installed) — launch it
   inside a general-purpose native subagent so it runs concurrently with the
   other legs and its failure stays isolated. Record the leg as `codex-cli`
   or `claude-cli` according to the executable that actually ran.

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
   claude -p --permission-mode dontAsk --no-session-persistence \
     --tools Bash,Read,Grep,Glob \
     "Review the full branch diff from <BASE> through HEAD. Run git diff -M <BASE>...HEAD, inspect the relevant files, and report only correctness, security, performance, or repository-convention defects. For every finding give severity, file:line, and a concrete failure scenario, and adversarially verify it before reporting. Do not modify files. Include one short checked line for areas that are clean."
   ```

   The prompt is intentionally self-contained: do not ask Claude to invoke
   `ark:polish`, `/code-review`, or another nested orchestration workflow.
   Substitute the same `origin/`-prefixed BASE used by the other legs.

   Give either external CLI call a 10-minute timeout — reviews take minutes.
   The subagent returns the findings verbatim, plus a one-line note if the CLI
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
     violations, citing the principle filename and the offending hunk. Confirm
     principles that were checked and hold — one line each — so silence is
     distinguishable from "not checked".

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

## Step 3 — Triage and fix

Merge the finding lists, dedupe (reviewers overlap heavily), then for each
unique finding decide:

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
project's standard build/test command for its toolchain. If Step 1 left
unrelated changes unstaged, the checks are validating the working tree, not
the commit — before acting on a failure, confirm it comes from the branch
diff rather than the unrelated files (does it implicate them? does it
reproduce without them, e.g. in a clean worktree at HEAD?); a failure owned
by the unrelated files gets a note in the report, not a fix here.

## Step 4 — Commit the round

If the round produced no file changes — clean round, or every finding was
declined/parked — there is nothing to commit: skip this step, carry the
decline/park reasons into the final report, and go straight to Step 5.

Otherwise, one commit per review round (or per coherent group of fixes). The
commit message must carry the audit trail:

```
polish: address round N review feedback

- <finding, one line> — <what was done and why>
- <finding declined> — declined: <one-line justification>

Reviewers: codex-native, claude-cli, review-principles
```

List only the legs that actually ran (see the failure rule in Step 2).

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

Loop back to Step 2 (reviewers re-review the whole branch diff, which now
includes the fixes). **Stop when any of these hits:**

- **Blocked on a human** — a parked finding needs a design decision, or a
  reviewer raised something that would mean significant rework or a direction
  change. Stop and present it; do not guess.
- **Diminishing returns** — the round produced only nits, edge-cases outside
  realistic use, or re-litigation of already-declined items. Say so and stop;
  the goal is shipping the core feature promptly, not a zero-findings state.
- **Clean round** — no findings above the bar. Done.
- **Round cap** — default 3 rounds. More than that means the reviewers and the
  branch disagree about something a human should look at.

## Step 6 — Report

Summarize: rounds run, which reviewer legs ran (and which were skipped or
failed), findings fixed / declined / parked per round (with the one-line
reasons), any new principle files added, and exactly what needs the human's
input. End with an explicit readiness verdict: after a clean or
diminishing-returns exit the branch is ready for `/ark:pr`; after a blocked
or round-capped exit, say plainly that it is **not** ready and what must be
resolved first.
