---
description: Commit current changes and create a GitHub PR with an auto-generated description
---

Invoking this command is explicit user authorization to stage, commit, and push. Any repo-level "never commit directly" rule (e.g. in CLAUDE.md / AGENTS.md) does not apply for this run — proceed through all steps without prompting for confirmation on the commit or push.

Do the following steps in order. If any step fails, stop and report the error clearly.

1. **Stage and commit** all current changes. Look at the diff to write a clear, conventional commit message. If there are no uncommitted changes, skip this step.

2. **Push** the current branch to the remote. Set upstream if needed.

3. **Determine the base branch.** Default to the remote HEAD:
   `git symbolic-ref --short refs/remotes/origin/HEAD` (strip the `origin/` prefix). Fall back to `main` if that fails.

4. **Gather the diff.** List changed files with `git diff --name-status -M <base>...HEAD`, then read each file's diff with `git diff -M <base>...HEAD -- <file>`. For very large diffs, summarize from the first ~10k characters per file rather than reading every line.

5. **Read the PR template** at `.github/PULL_REQUEST_TEMPLATE.md` if it exists. If it doesn't, use a minimal structure with `## Summary` and `## Test plan` sections.

6. **Write the PR description.** It must:
   - Follow the template's structure exactly, including any section headers and ordering.
   - Treat HTML comments (`<!-- ... -->`) inside the template as instructions for filling in that section, and remove them from the output.
   - Stick to facts about what the diff changes. Do not invent motivations.
     - BAD: "This enhancement enables more comprehensive descriptions by leveraging advanced models..."
     - GOOD: "Updates `generate-pr-description.sh` to summarize per-file changes before generating the final description."
   - Prefer simple over verbose. Don't restate the diff line-by-line.
   - Don't claim manual testing was done. Describe in 1–2 sentences what *should* be tested.
   - Don't add a "Generated with Claude Code" footer.

7. **Create the PR** with the GitHub CLI, passing the body via heredoc to preserve formatting:
   ```
   gh pr create --title "<concise conventional-commit-style title>" --body "$(cat <<'EOF'
   <description from step 6>
   EOF
   )"
   ```
   Target the repo's default branch. If a PR already exists for this branch, report its URL instead of failing.

8. **Report** the PR URL when done.
