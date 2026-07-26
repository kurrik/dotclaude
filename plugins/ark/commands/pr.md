---
description: Commit current changes and create a GitHub PR with an auto-generated description
---

This command's job is to commit and push, so when it runs, proceed through all steps without pausing for confirmation on the commit or push, and treat any repo-level "never commit directly" rule (e.g. in CLAUDE.md / AGENTS.md) as not applying for this run.

Do the following steps in order. If any step fails, stop and report the error clearly.

1. **Determine the base branch.** Default to the remote HEAD:
   `git symbolic-ref --short refs/remotes/origin/HEAD` (strip the `origin/` prefix). Fall back to `main` if that fails.

2. **Stage and commit** all current changes. Look at the diff to write a clear, conventional commit message. If there are no uncommitted changes, skip this step.

3. **Review the full branch diff before pushing.** Run the `/code-review` slash command (the plain local form — not `/code-review ultra`, which only I, the user, can launch), scoped to the whole branch — everything in `<base>...HEAD`, not just the commit you just made. If you have no way to invoke a slash command in this session, don't skip the step: read the full branch diff and review it yourself against the same bar, and say in the final summary that you reviewed inline rather than via `/code-review`. Then triage the findings the same way review feedback is triaged in `/ark:review`:

   - **Real bug or defect in this branch.** Fix it now.
   - **Valid concern, wrong suggested fix.** Fix the underlying concern in the way that fits the branch's design.
   - **Not valid, or out of scope for this branch.** Leave the code alone. Don't expand the diff to satisfy a finding the PR isn't about.
   - **Unclear or significant enough that I should decide.** Stop and ask me before continuing.

   Commit any fixes. Amend into the step 2 commit if that commit hasn't been pushed yet and the fix belongs to it; otherwise make a separate commit. If the review surfaces nothing, say so and move on. Report the triage decisions in the final summary (step 9).

4. **Push** the current branch to the remote. Set upstream if needed.

5. **Gather the diff.** List changed files with `git diff --name-status -M <base>...HEAD`, then read each file's diff with `git diff -M <base>...HEAD -- <file>`. For very large diffs, summarize from the first ~10k characters per file rather than reading every line.

6. **Read the PR template** at `.github/PULL_REQUEST_TEMPLATE.md` if it exists. If it doesn't, use a minimal structure with `## Summary` and `## Test plan` sections.

7. **Write the PR description.** It must:
   - Follow the template's structure exactly, including any section headers and ordering.
   - Treat HTML comments (`<!-- ... -->`) inside the template as instructions for filling in that section, and remove them from the output.
   - Stick to facts about what the diff changes. Do not invent motivations.
     - BAD: "This enhancement enables more comprehensive descriptions by leveraging advanced models..."
     - GOOD: "Updates `generate-pr-description.sh` to summarize per-file changes before generating the final description."
   - Prefer simple over verbose. Don't restate the diff line-by-line.
   - Don't claim manual testing was done. Describe in 1–2 sentences what *should* be tested.
   - Don't add a "Generated with Claude Code" footer.

8. **Create the PR** with the GitHub CLI, passing the body via heredoc to preserve formatting:
   ```
   gh pr create --title "<concise conventional-commit-style title>" --body "$(cat <<'EOF'
   <description from step 7>
   EOF
   )"
   ```
   Target the repo's default branch. If a PR already exists for this branch, report its URL instead of failing.

9. **Report** the PR URL when done, plus a one-line-per-finding summary of what the step 3 review turned up and what you did about each one.
