#!/usr/bin/env bash
# The only way an ark skill pushes: scan every commit that would be
# published, then push the current branch with upstream set. Putting the
# scan inside the push means no skill can forget it, whichever path
# produced the commits (a review fix, a polish round, an inline fallback).
#
#   bash push-branch.sh <base>          # base from resolve-base.sh
#
# Exit 0 pushed; 1 secret-shaped content found (hits on stdout, nothing
# pushed); 2 usage, detached HEAD, scan error, or push failure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE=${1:-}
[[ -n "$BASE" ]] || { echo "usage: push-branch.sh <base>" >&2; exit 2; }
BRANCH=$(git symbolic-ref --short -q HEAD) || { echo "push-branch: HEAD is detached" >&2; exit 2; }

hits=$(bash "$HERE/scan-secrets.sh" "$BASE"); ec=$?
if [[ $ec -eq 1 ]]; then
  echo "push-branch: refusing to push — secret-shaped content in $BASE..HEAD:"
  printf '%s\n' "$hits"
  exit 1
elif [[ $ec -ne 0 ]]; then
  echo "push-branch: scan failed (status $ec); nothing pushed" >&2; exit 2
fi
git push -u origin "$BRANCH" || { echo "push-branch: push failed" >&2; exit 2; }
