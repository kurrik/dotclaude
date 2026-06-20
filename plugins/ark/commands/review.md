---
description: Fetch PR review comments, address them, and push the fixes
---

Do the following steps in order. This command talks to GitHub's GraphQL API directly through `gh api` — it needs an authenticated `gh` CLI but no `gh` extensions.

1. **Identify the current PR.** Get the PR number and repo (owner/repo) for the current branch:
   gh pr view --json number,url,headRepositoryOwner,headRepository

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

   Each `reviewThreads.nodes[].id` is the thread ID you reply to in step 5 — keep it paired with the comment it belongs to. Read the review bodies and the unresolved thread comments to understand what each reviewer is asking for. You can skip threads where `isResolved` or `isOutdated` is true unless the point still stands.

3. **Address each comment.** For every actionable review comment:
   - Make the requested code change
   - If a comment is unclear or you disagree with it, flag it for me instead of guessing

4. **Commit and push.** Stage all changes, write a commit message like `address PR review feedback`, and push to the remote branch.

5. **Respond to review comments — drive all replies through a single pending review.** Create one pending review, attach every reply to it via its `pullRequestReviewId`, and submit once at the end. If you instead post replies without an explicit review id, they can land as dangling PENDING comments with no parent review — and GitHub has no way to attach them to a review afterward (the UI's "Finish your review" button only submits pending *reviews*, not loose comments), so cleaning up means re-posting and deleting them. Always pass the review id.

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

   Describe the implementation chosen if it's not obvious from the comment.

6. **Sanity-check that nothing was left pending.** Run this after step 5; it should print `0`:

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
   (b) opening a new pending review (step 5's `addPullRequestReview` mutation),
   (c) re-replying each one with the `addPullRequestReviewThreadReply` mutation from step 5, passing the new `pullRequestReviewId`,
   (d) submitting the review,
   (e) deleting each orphan via the `deletePullRequestReviewComment` mutation with its node ID.

7. **Summary.** Give me a brief summary of what you changed and list any comments you skipped or need my input on.
