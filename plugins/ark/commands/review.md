---
description: Fetch PR review comments, address them, and push the fixes
---

Do the following steps in order:

1. **Identify the current PR.** Get the PR number and repo (owner/repo) for the current branch:
   gh pr view --json number,url,headRepositoryOwner,headRepository

2. **Fetch review comments** using the gh-pr-review extension:
   gh pr-review review view -R <owner/repo> <pr-number>
   Parse the review comments and understand what each reviewer is asking for.

3. **Address each comment.** For every actionable review comment:
   - Make the requested code change
   - If a comment is unclear or you disagree with it, flag it for me instead of guessing

4. **Commit and push.** Stage all changes, write a commit message like `address PR review feedback`, and push to the remote branch.

5. **Respond to review comments — drive all replies through a single pending review.** Calling `gh pr-review comments reply` *without* a `--review-id` leaves each reply as an orphan PENDING comment with no parent review, and GitHub's API has no way to attach it later (the UI's "Finish your review" button only submits pending *reviews*, which these aren't). Republishing them later means re-posting + deleting the orphans, which is wasteful.

   Right pattern: open a pending review, attach every reply to it, submit at the end.

   ```bash
   PR_ID=$(gh pr view <pr> -R <owner/repo> --json id --jq .id)
   REVIEW_ID=$(gh api graphql -f query='
     mutation($pid: ID!) {
       addPullRequestReview(input: { pullRequestId: $pid }) {
         pullRequestReview { id }
       }
     }' -F pid="$PR_ID" --jq '.data.addPullRequestReview.pullRequestReview.id')

   # For each thread you want to reply to:
   gh pr-review comments reply \
     --thread-id <THREAD_ID> \
     --body "Follow-up addressed in commit abc123" \
     --review-id "$REVIEW_ID" \
     -R <owner/repo> <pr-number>

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
   (b) opening a new pending review (step 5's mutation),
   (c) re-replying each one with `--review-id "$REVIEW_ID"`,
   (d) submitting the review,
   (e) deleting each orphan via the `deletePullRequestReviewComment` mutation with its node ID.

7. **Summary.** Give me a brief summary of what you changed and list any comments you skipped or need my input on.
