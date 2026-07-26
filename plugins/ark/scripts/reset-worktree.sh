#!/usr/bin/env bash
#
# Reset a git worktree's own branch back to the repo's base branch.
#
# Convention: a worktree owns the branch `worktree/<its-directory-name>`, so a
# worktree at ~/workspace/a17k-01 owns the branch `worktree/a17k-01`. Override the
# namespace with --prefix, or pass --prefix '' for a bare `a17k-01`. The prefix
# cannot be an existing branch name -- git stores refs as paths, so `refs/heads/main`
# being a file makes the branch `main/a17k-01` impossible to create.
#
# Steps: fetch the base branch, check out the worktree's branch, hard-reset it to
# the base branch, and unset its upstream so it isn't accidentally pushed again.
#
# No-ops (exit 0) when not run from a linked worktree.
# Exits 3 when the worktree is dirty and --force was not passed.
#
# Usage: reset-worktree.sh [--force] [--base <branch>] [--prefix <ns>] [--dry-run]

set -euo pipefail

FORCE=0
DRY_RUN=0
BASE=main
PREFIX=worktree

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  would run: %s\n' "$*"
  else
    printf '  + %s\n' "$*"
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --base)
      [[ $# -ge 2 ]] || die "--base requires a branch name"
      BASE="$2"; shift 2 ;;
    --base=*) BASE="${1#--base=}"; shift ;;
    --prefix)
      [[ $# -ge 2 ]] || die "--prefix requires a value"
      PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#--prefix=}"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$BASE" ]] || die "--base must not be empty"
PREFIX="${PREFIX%/}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

# A linked worktree has its own .git dir distinct from the repo's common dir.
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd -P)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
if [[ "$git_dir" == "$common_dir" ]]; then
  echo "Not a linked git worktree (this is the primary working tree) — nothing to do."
  exit 0
fi

worktree_root=$(git rev-parse --show-toplevel)
worktree_name=$(basename "$worktree_root")
branch="${PREFIX:+$PREFIX/}$worktree_name"

# Git refs live on a filesystem-like path, so `foo` and `foo/bar` can't coexist.
if [[ -n "$PREFIX" ]] && git show-ref --verify --quiet "refs/heads/$PREFIX"; then
  die "cannot use prefix '$PREFIX': a branch named '$PREFIX' already exists, so
       the branch '$branch' can never be created. Pick a prefix that isn't an
       existing branch name (e.g. --prefix wt), or pass --prefix '' for a
       bare branch name with no namespace."
fi

printf 'Worktree : %s\n' "$worktree_root"
printf 'Branch   : %s\n' "$branch"
printf 'Base     : %s\n\n' "$BASE"

if [[ "$branch" == "$BASE" ]]; then
  die "worktree branch and base branch are both '$BASE' — refusing to reset the base branch onto itself"
fi

# Refuse to clobber uncommitted work unless explicitly forced.
dirty=$(git status --porcelain)
if [[ -n "$dirty" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    echo "Worktree is dirty; --force given, discarding tracked changes:"
    printf '%s\n\n' "$dirty"
  else
    echo "Worktree has uncommitted changes:" >&2
    printf '%s\n' "$dirty" >&2
    echo >&2
    echo "Refusing to reset. Re-run with --force to discard these changes." >&2
    exit 3
  fi
fi

# Update the local base branch. `git fetch origin <base>:<base>` fails when the
# base branch is checked out in another worktree (commonly the primary one), so
# fall back to fetching the remote-tracking ref and resetting to that.
echo "Fetching $BASE from origin..."
fetch_err=""
if [[ $DRY_RUN -eq 1 ]]; then
  printf '  would run: git fetch origin %s:%s\n' "$BASE" "$BASE"
  target="$BASE"
elif fetch_err=$(git fetch origin "$BASE:$BASE" 2>&1); then
  [[ -n "$fetch_err" ]] && printf '%s\n' "$fetch_err"
  target="$BASE"
elif ! git ls-remote --exit-code --heads origin "$BASE" >/dev/null 2>&1; then
  die "origin has no '$BASE' branch"
else
  printf '  local %s could not be fast-forwarded (checked out in another worktree?)\n' "$BASE"
  printf '  falling back to origin/%s\n' "$BASE"
  run git fetch origin "$BASE"
  target="origin/$BASE"
fi

git rev-parse --verify --quiet "$target^{commit}" >/dev/null ||
  die "cannot resolve base ref '$target'"

echo
if git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "Checking out $branch and resetting to $target..."
  run git checkout "$branch"
  run git reset --hard "$target"
else
  echo "Branch $branch does not exist; creating it at $target..."
  run git checkout -B "$branch" "$target"
fi

# These branches are local scratch space. If one was pushed at some point, drop
# the upstream link so a later bare `git push` doesn't update the remote copy.
# The remote branch itself is left alone — delete it manually if you want it gone.
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null || true)
echo
if [[ -n "$upstream" ]]; then
  printf 'Unsetting upstream (%s)...\n' "$upstream"
  run git branch --unset-upstream "$branch"
else
  echo "No upstream configured for $branch — nothing to unset."
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete; nothing was changed."
else
  printf 'Done. %s is at %s (%s).\n' "$branch" "$target" "$(git rev-parse --short HEAD)"
  remaining=$(git status --porcelain)
  if [[ -n "$remaining" ]]; then
    echo
    echo "Note: untracked files remain (reset --hard does not remove them):"
    printf '%s\n' "$remaining"
  fi
fi
