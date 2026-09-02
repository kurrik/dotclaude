---
name: review
description: Fetch PR review comments, address them, and push the fixes. Use when asked to address review feedback on the current branch's pull request.
---

Do the following steps in order. This skill talks to GitHub's GraphQL API directly through `gh api` — it needs an authenticated `gh` CLI but no `gh` extensions.

1. **Identify the current PR and its intent.** Get the PR number, repo (owner/repo), and description for the current branch:
   gh pr view --json number,title,body,url,headRepositoryOwner,headRepository

   Read the title and body carefully — they state what the PR is trying to accomplish and often the design decisions behind it. Skim the PR's diff (`gh pr diff`) so you understand the shape of the change as a whole. You will judge every review comment against this context, so build it before reading the feedback.

2. **Fetch review comments and threads** with the GraphQL API:

   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(first: 50) {
             nodes { author { login } state body submittedAt }
           }
           reviewThreads(first: 100) {
             nodes {
               id
               isResolved
               isOutdated
               path
               line
               comments(first: 50) {
                 nodes { author { login } body createdAt }
               }
             }
           }
         }
       }
     }' -F owner=<owner> -F repo=<repo> -F number=<pr-number>
   ```

   Each `reviewThreads.nodes[].id` is the thread ID you reply to in step 6 — keep it paired with the comment it belongs to. Read the review bodies and the unresolved thread comments to understand what each reviewer is asking for. You can skip threads where `isResolved` or `isOutdated` is true unless the point still stands.

3. **Evaluate each comment before acting.** Review feedback is input, not instruction. Do not blindly apply suggestions — reviewers usually see one hunk of the diff, not the PR's design, so a locally-reasonable suggestion can be wrong globally. For each comment, decide which case it is:

   - **Valid, and the suggested fix is right.** Apply it.
   - **Valid concern, but the suggested fix is wrong for this PR.** Fix the underlying concern in the way that fits the PR's architecture and goals, and explain the divergence in your reply (step 6).
   - **Not valid, or conflicts with the PR's design.** Don't change the code. Reply explaining the design rationale, or flag it for me if the disagreement is significant. Declining with a clear explanation is a legitimate resolution — churn from accepting a bad suggestion causes another round of review.
   - **Unclear.** Flag it for me instead of guessing.

   Prefer the minimal fix that resolves the reviewer's actual concern. Don't refactor beyond what the comment requires — expanded diffs attract new feedback and prolong the review cycle.

4. **Holistic review pass before committing.** Once all fixes are made, review the complete result — this is what catches the "feedback on the fixes" loop:

   - Re-read the full working diff (`git diff` plus anything staged), not just the lines you touched. Check that the individual fixes compose coherently: consistent naming, no duplicated logic, no fix that contradicts another.
   - Verify each fix still serves the PR's stated goals from step 1, and that none quietly changed behavior the PR didn't intend to change.
   - Review your own changes as a skeptical reviewer would — if a fix would itself draw an obvious comment (dead code, leftover debug output, inconsistent style with the surrounding file, missing edge case), fix that now rather than in the next cycle.
   - Run the project's tests/lint/build if available, and fix any failures before committing.

5. **Commit and push.** Stage all changes and write a commit message like `address PR review feedback`, then push to the remote branch. The step 4 holistic pass is the review of the fixes — `ark:polish` is **not** run here by default; it is a full multi-reviewer loop and the fix set is usually a few hunks. Offer it once, before pushing, only when the fixes changed the *shape* of the PR: step 3 chose a structural fix over the suggested patch, or one fix touched more than a handful of files. That shape test is the whole trigger — `ark:pr`'s line-and-file thresholds do not apply here, since a one-file structural rewrite is exactly the case worth a second look. Ask once with the host's question tool (`AskUserQuestion` in Claude Code), saying which fix reshaped the PR, with three options: a full `ark:polish` pass, a quick pass (`ark:polish --quick`, one round, native and corpus reviewers only — the default recommendation here, since the fix set is small), or push without either. If the session cannot ask, push and say in the summary that a pass was recommended and why. If I explicitly ask for polish, run it; if I said to skip it ("without polish", "just push"), don't offer. If polish runs and exits blocked or round-capped, stop and ask me instead of pushing; otherwise fold anything it fixed or declined into the step 6 replies and the step 8 summary.

6. **Respond to review comments — drive all replies through a single pending review.** Create one pending review, attach every reply to it via its `pullRequestReviewId`, and submit once at the end. If you instead post replies without an explicit review id, they can land as dangling PENDING comments with no parent review — and GitHub has no way to attach them to a review afterward (the UI's "Finish your review" button only submits pending *reviews*, not loose comments), so cleaning up means re-posting and deleting them. Always pass the review id.

   ```bash
   # Open one pending review and capture its ID.
   PR_ID=$(gh pr view <pr> -R <owner/repo> --json id --jq .id)
   REVIEW_ID=$(gh api graphql -f query='
     mutation($pid: ID!) {
       addPullRequestReview(input: { pullRequestId: $pid }) {
         pullRequestReview { id }
       }
     }' -F pid="$PR_ID" --jq '.data.addPullRequestReview.pullRequestReview.id')

   # For each thread you want to reply to, attach the reply to that review.
   # THREAD_ID is the reviewThreads.nodes[].id from step 2.
   gh api graphql -f query='
     mutation($threadId: ID!, $reviewId: ID!, $body: String!) {
       addPullRequestReviewThreadReply(input: {
         pullRequestReviewThreadId: $threadId,
         pullRequestReviewId: $reviewId,
         body: $body
       }) {
         comment { id }
       }
     }' -F threadId="<THREAD_ID>" -F reviewId="$REVIEW_ID" -f body="Follow-up addressed in commit abc123"

   # When you've replied to everything, submit the review (event=COMMENT
   # publishes the attached replies without giving the review an
   # APPROVE / REQUEST_CHANGES state):
   gh api graphql -f query='
     mutation($rid: ID!) {
       submitPullRequestReview(input: { pullRequestReviewId: $rid, event: COMMENT }) {
         pullRequestReview { id state submittedAt }
       }
     }' -F rid="$REVIEW_ID"
   ```

   Describe the implementation chosen if it's not obvious from the comment. For comments where you diverged from the suggestion or declined to make a change (step 3), explain your reasoning against the PR's design so the reviewer can evaluate it rather than re-raise the same point.

7. **Sanity-check that nothing was left pending.** Run this after step 6; it should print `0`:

   ```bash
   AUTHOR=$(gh api user --jq .login)
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviewThreads(first: 100) {
             nodes { comments(first: 20) { nodes { state author { login } } } }
           }
         }
       }
     }' -F owner=<owner> -F repo=<repo> -F number=<pr-number> \
     --jq "[.data.repository.pullRequest.reviewThreads.nodes[].comments.nodes[] | select(.state == \"PENDING\" and .author.login == \"$AUTHOR\")] | length"
   ```

   If it prints > 0, you have orphans from a previous run. Recover by:
   (a) snapshotting `{ thread_id, body }` for each pending comment via the same GraphQL query as above,
   (b) opening a new pending review (step 6's `addPullRequestReview` mutation),
   (c) re-replying each one with the `addPullRequestReviewThreadReply` mutation from step 6, passing the new `pullRequestReviewId`,
   (d) submitting the review,
   (e) deleting each orphan via the `deletePullRequestReviewComment` mutation with its node ID.

8. **Summary.** Give me a brief summary of what you changed, which suggestions you diverged from or declined (and why), and any comments that need my input.
