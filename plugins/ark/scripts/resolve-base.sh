#!/usr/bin/env bash
# Print the remote-tracking ref every ark skill measures against, after a
# fetch: origin/<the remote's default branch>. Always the remote ref, never
# the local branch -- a local `main` can carry an unpushed commit the feature
# branch was built on (which `main..HEAD` would silently exclude from the
# secret scan and the size measurement) or be stale.
#
#   BASE=$(bash resolve-base.sh)        # e.g. origin/main
#
# One mechanism, no cached state: the remote is asked which branch is HEAD
# (so a rename is seen immediately), and that branch is fetched into its
# remote-tracking ref explicitly (so a --single-branch clone, whose fetch
# refspec covers only the feature branch, still gets it).
#
# Exit 0 with the ref on stdout; 2 if the remote cannot be queried or the
# fetch fails.
set -uo pipefail
name=$(git ls-remote --symref origin HEAD 2>/dev/null |
  awk '/^ref: refs\/heads\// { sub("refs/heads/", "", $2); print $2; exit }')
[[ -n "$name" ]] || { echo "resolve-base: cannot determine origin's default branch (git ls-remote --symref origin HEAD)" >&2; exit 2; }
git fetch -q origin "+refs/heads/$name:refs/remotes/origin/$name" ||
  { echo "resolve-base: fetching origin/$name failed" >&2; exit 2; }
git rev-parse --verify -q "origin/$name^{commit}" >/dev/null ||
  { echo "resolve-base: 'origin/$name' does not resolve to a commit" >&2; exit 2; }
echo "origin/$name"
