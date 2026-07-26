---
description: Reset the current git worktree's branch back to the base branch, or the primary clone back to a clean base checkout
argument-hint: "[--base <branch>] [--prefix <ns>] [--dry-run]"
allowed-tools: Bash(bash:*), Bash(git status:*), Bash(git stash:*)
---

Get back to a clean state on top of the repo's base branch. In a linked worktree that means the worktree's own branch; in the primary working tree it means the base branch itself.

The work is done by `${CLAUDE_PLUGIN_ROOT}/scripts/reset-worktree.sh`. Your job is to run it and handle the one decision it deliberately refuses to make on its own: discarding uncommitted work.

Extra arguments from the user (if any): `$ARGUMENTS` — pass them through to the script verbatim.

1. **Run the script:**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/reset-worktree.sh" $ARGUMENTS
   ```

   It fetches the base branch (`main` unless `--base` says otherwise), then behaves according to where it ran:

   - **Linked worktree** — checks out the worktree's branch (`worktree/<directory-name>`, so a worktree at `~/workspace/a17k-01` owns `worktree/a17k-01`), hard-resets it to the base branch, and unsets its upstream. The branch is created at the base branch if it doesn't exist yet.
   - **Primary working tree** — checks out the base branch itself and hard-resets it to the fetched tip. The upstream is left alone (`main` is meant to track `origin/main`) and `--prefix` is ignored.

2. **Handle the exit code:**

   - **0** — done. Report what the script printed: which mode it ran in, the branch, the commit it now points at, whether an upstream was unset, and any untracked files it noted as remaining.
   - **3** — the working tree has uncommitted changes and the script refused to discard them. Show the user the dirty-file list from the script's output and **ask** whether to discard it. Only if they confirm, re-run with `--force`:

     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/reset-worktree.sh" --force $ARGUMENTS
     ```

     If they decline, stop and leave the working tree untouched. Offer `git stash --include-untracked` as the alternative.
   - **anything else** — report the script's error output as-is and stop. Don't paper over it with ad-hoc git commands; a non-zero exit here means an assumption is wrong (no `origin`, missing base branch, a prefix that collides with an existing branch name).

## Notes

- `git reset --hard` does not remove untracked files. The script lists any that survive; mention them, and only run `git clean` if the user explicitly asks.
- In a worktree, the script unsets the branch's local upstream but never deletes the remote copy. Deleting a remote branch is the user's call — bring it up only if they ask.
- Running in the primary clone leaves whatever branch you were on in place — it is only switched away from, never deleted. Say so in the report if the user was on a feature branch.
- `--prefix` overrides the `worktree/` namespace (linked worktrees only); `--prefix ''` gives a bare `a17k-01`. It must not be an existing branch name — git stores refs as filesystem paths, so with a `main` branch present the ref `main/a17k-01` is impossible to create (`cannot lock ref ... 'refs/heads/main' exists`). The script checks this up front and explains it.
