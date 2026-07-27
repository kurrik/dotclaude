---
name: improve-polish
description: Upstream review-cycle lessons from the current session into the ark:polish bundled principles corpus. Diagnoses this session's polish rounds, PR review feedback, and human corrections for generalizable lessons — errors and feedback polish should anticipate, or better fix patterns — then drafts principle updates (with real positive and negative examples from the session) and opens a PR against kurrik/dotclaude entirely through the GitHub API, no local checkout of that repo required. Use after a review cycle exposed something ark:polish missed or handled badly, or when asked to upstream review lessons.
---

# ark:improve-polish — upstream review-cycle lessons

The `ark:polish` skill reviews branches against a bundled principles corpus
(`plugins/ark/skills/polish/principles/` in kurrik/dotclaude). That corpus only
improves if real review cycles feed it. This skill closes the loop: mine the
current session for lessons that would have saved a review round, turn them
into principle files in the corpus's format, and open a PR against
`kurrik/dotclaude` using only `gh api` — it must work from any machine that
installed the marketplace, with no local clone of that repo.

## Ground rules (they govern every step)

- **Evidence must be real and cited.** Every example comes from an actual
  review comment, commit, polish round, or human correction in this session's
  orbit — quoted or paraphrased faithfully, with a PR link
  (`owner/repo#N`). Never invent, embellish, or "reconstruct" an example. A
  lesson without real evidence is an opinion and does not ship.
- **Generalizable only.** The bundled layer is repo-agnostic: evidence may
  cite a specific repo, but the rule and its checks must mean something in an
  unrelated codebase. Repo-specific lessons belong in that repo's
  `.claude/review-principles/` layer — list them in the report as candidates,
  don't put them in this PR.
- **Rounds, not style.** A lesson earns its place only if it would have saved
  an actual round of review feedback (or a whole polish round). Style belongs
  to linters.
- **Prefer augmenting over adding.** A new example on an existing principle
  beats a near-duplicate file. Same filename = same principle.
- **The human curates the corpus.** Show the complete draft and get explicit
  approval before writing anything to GitHub. Publishing without approval is
  never correct, even if the session seems unambiguous.

## Step 1 — Inventory the session's review activity

Collect every review signal this session touched, from three sources:

1. **The conversation itself.** Polish rounds run this session (findings
   fixed / declined / parked), corrections the human made to triage decisions,
   fixes that had to be redone, anything the human flagged that a reviewer or
   polish missed.

2. **Polish audit trails in git.** On each branch worked this session:

   ```bash
   git log --grep='^polish:' --format='%H%n%B---' <base>..HEAD
   ```

   The bullet lists in those commit messages record what each round found and
   how it was resolved — including declines and their justifications.

3. **External PR review feedback.** For each PR associated with the session
   (current branch's PR via `gh pr view --json number,url,title,body`, plus
   any PR the conversation worked on), fetch reviews and threads:

   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(first: 50) { nodes { author { login } state body submittedAt } }
           reviewThreads(first: 100) {
             nodes {
               isResolved isOutdated path line
               comments(first: 50) { nodes { author { login } body createdAt } }
             }
           }
         }
       }
     }' -F owner=<owner> -F repo=<repo> -F number=<pr-number>
   ```

   Resolved threads matter most here — unlike in `ark:review`, a resolved
   thread is a *completed* feedback cycle, which is exactly the evidence a
   principle needs. Bot reviewers (Copilot, codex, CI annotations) count as
   external feedback too.

If the session has no polish rounds, no PRs, and no review feedback, stop and
say there is nothing to mine — do not manufacture lessons from ordinary coding
activity.

## Step 2 — Diagnose the review cycle

For each review event from Step 1, ask what would have prevented it or made it
cheaper. Classify:

| Signal | Lesson type |
|---|---|
| External reviewer caught what polish's panel missed | Anticipation — a check polish should run |
| Same defect class re-flagged across rounds | Fix pattern — enumerate the class, not the instance |
| A fix itself drew new feedback | Fix quality — what the fix should have included |
| The human overrode a polish triage decision (fixed a decline, or vice versa) | Triage calibration |
| A decline-with-rationale that stuck, or a class swept once and never re-flagged | Positive example — "Done right" evidence |

For each candidate lesson: state the defect class in one sentence, attach the
concrete evidence (PR, round, file, quote) — negative *and* positive examples
where both exist — and apply the generalizability test: would this rule mean
anything in an unrelated repo? If not, it's a repo-corpus candidate for the
report, not this PR.

## Step 3 — Read the live corpus from GitHub

The PR targets the corpus as it exists on `main` *now* — not a possibly-stale
installed copy of the plugin. Fetch it remotely:

```bash
REPO=kurrik/dotclaude
PDIR=plugins/ark/skills/polish/principles

# List files with their blob SHAs (SHAs are required later to update a file):
gh api "repos/$REPO/contents/$PDIR" --jq '.[] | "\(.name) \(.sha)"'

# Read any file:
gh api "repos/$REPO/contents/$PDIR/<file>" --jq .content | base64 --decode
```

Read the corpus `README.md` first — it states the current file format and
admission rules, and it governs over anything this skill remembers about
them. Then read every principle whose topic is near a candidate lesson, and
map each lesson to one of:

- **Already covered, no new signal** — drop it; note in the report.
- **Covered, but the session adds a new example or sharper check** — edit the
  existing file (keep its blob SHA from the listing above).
- **Genuinely new** — new file, kebab-case imperative filename per the README.

## Step 4 — Draft and get approval

Write each new or edited principle in full, following the corpus README's
format exactly (rule statement, `## Check`, `## From the history`, under ~60
lines). Cite cross-repo evidence as `owner/repo#N` with enough narrative that
the example grounds a reviewer agent outside the origin repo. Include a
**Done right** entry only when a real one exists.

Present the complete draft to the human — every file, full text, plus the
dropped lessons and why — and get explicit approval. Apply any edits they
ask for. Nothing is written to GitHub before this gate.

## Step 5 — Publish via the GitHub API (no checkout)

Write each approved file to the scratchpad, then drive everything with
`gh api`:

```bash
REPO=kurrik/dotclaude
PDIR=plugins/ark/skills/polish/principles

# 1. Branch off the default branch's current tip:
DEFAULT=$(gh api "repos/$REPO" --jq .default_branch)
HEAD_SHA=$(gh api "repos/$REPO/git/ref/heads/$DEFAULT" --jq .object.sha)
BRANCH="improve-polish/$(date +%Y%m%d)-<short-slug>"
gh api "repos/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$HEAD_SHA"

# 2. One PUT per file (each creates a commit on the branch):
CONTENT=$(openssl base64 -A -in <scratchpad-draft>)   # -A: single line, portable across macOS/Linux
gh api -X PUT "repos/$REPO/contents/$PDIR/<name>.md" \
  -f branch="$BRANCH" \
  -f message="polish: <one-line summary of this principle change>" \
  -f content="$CONTENT" \
  -f sha="<blob SHA from Step 3>"   # REQUIRED when updating an existing file; OMIT for a new file

# 3. Open the PR:
gh api "repos/$REPO/pulls" \
  -f base="$DEFAULT" -f head="$BRANCH" \
  -f title="polish: <summary of the lessons>" \
  -F body=@<scratchpad-body-file>
```

The PR body must let the human review the *evidence*, not just the prose:
which repo/PRs were mined, a per-file summary of what changed and why, and
links to the PRs cited in each example. Write it to a scratchpad file and
pass it with `-F body=@file` so multi-line content survives quoting.

**If the branch-creation call fails with 403/404** (no push access — e.g. a
machine authenticated as a different account), fork instead:
`gh repo fork "$REPO" --clone=false`, repeat the ref and contents calls
against the fork, and open the PR with `-f head="<fork-owner>:$BRANCH"`.

## Step 6 — Report

Summarize: the PR URL; lessons upstreamed (per file, one line each); lessons
dropped and why (already covered, not generalizable, insufficient evidence);
repo-specific candidates the human may want to add to the working repo's
`.claude/review-principles/`; and anything that still needs their input.
