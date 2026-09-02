#!/usr/bin/env bash
# Print the remote-tracking ref every ark skill measures against, after a
# fetch: origin/<the remote's default branch>. Always the remote ref, never
# the local branch -- a local `main` can carry an unpushed commit the feature
# branch was built on (which `main..HEAD` would silently exclude from the
# secret scan and the size measurement) or be stale.
#
#   BASE=$(bash resolve-base.sh)        # e.g. origin/main
#
# Exit 0 with the ref on stdout; 2 if the fetch fails or the ref does not
# resolve to a commit.
set -uo pipefail
git fetch -q origin || { echo "resolve-base: git fetch origin failed" >&2; exit 2; }
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null ||
  git ls-remote --symref origin HEAD 2>/dev/null |
  awk '/^ref:/ { sub("refs/heads/", "origin/", $2); print $2 }')
BASE=${BASE:-origin/main}
git rev-parse --verify -q "$BASE^{commit}" >/dev/null ||
  { echo "resolve-base: '$BASE' does not resolve to a commit" >&2; exit 2; }
echo "$BASE"
