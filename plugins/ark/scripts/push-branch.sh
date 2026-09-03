#!/usr/bin/env bash
# The only way an ark skill pushes: scan every commit that would be
# published, then push the current branch with upstream set. Putting the
# scan inside the push means no skill can forget it, whichever path
# produced the commits (a review fix, a polish round, an inline fallback).
#
#   bash push-branch.sh <base>                          # base from resolve-base.sh
#   bash push-branch.sh <base> --override-scan "<why>"  # push despite hits
#
# --override-scan is the human's decision, never the agent's: the skills
# only pass it after showing the human the hits and being told to push. The
# reason is printed with the hits so the transcript records who decided.
#
# Exit 0 pushed; 1 secret-shaped content found and no override (hits on
# stdout, nothing pushed); 2 usage, detached HEAD, scan error, or push
# failure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE=${1:-}; shift || true
OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --override-scan) OVERRIDE=${2:-}; [[ -n "$OVERRIDE" ]] || { echo "push-branch: --override-scan needs a reason" >&2; exit 2; }; shift 2 ;;
    *) echo "push-branch: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[[ -n "$BASE" ]] || { echo "usage: push-branch.sh <base> [--override-scan <reason>]" >&2; exit 2; }
BRANCH=$(git symbolic-ref --short -q HEAD) || { echo "push-branch: HEAD is detached" >&2; exit 2; }

hits=$(bash "$HERE/scan-secrets.sh" "$BASE"); ec=$?
if [[ $ec -eq 1 ]]; then
  if [[ -z "$OVERRIDE" ]]; then
    echo "push-branch: refusing to push — secret-shaped content in $BASE..HEAD:"
    printf '%s\n' "$hits"
    exit 1
  fi
  echo "push-branch: pushing despite hits, override by human: $OVERRIDE"
  printf '%s\n' "$hits"
elif [[ $ec -ne 0 ]]; then
  echo "push-branch: scan failed (status $ec); nothing pushed" >&2; exit 2
fi
git push -u origin "$BRANCH" || { echo "push-branch: push failed" >&2; exit 2; }
