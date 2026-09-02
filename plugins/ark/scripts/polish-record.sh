#!/usr/bin/env bash
# Write a polish run's final verdict where polish-state.sh will find it: the
# `Mode:` and `Verdict:` trailers of the commit at HEAD.
#
#   bash polish-record.sh --mode <full|quick> --verdict <ready|not-ready> \
#        [--reason "<one line>"] [--body-file <path>]
#
# If HEAD already carries a Verdict: trailer (this run's own round commit,
# written with `Verdict: pending`) and is not on any remote branch, the
# trailer is rewritten in place with `git commit --amend` -- nothing shared
# is rewritten, and the check is enforced here, not left to the caller.
# Otherwise (the run committed nothing, or HEAD is a pushed record from an
# earlier run) an empty commit is created so the verdict travels with the
# branch: --body-file supplies its body (the parked findings, for a
# not-ready verdict). Every polish run therefore ends with a record at HEAD.
#
# Exit 0 on success, 2 on usage error or git failure.
set -uo pipefail
MODE=""; VERDICT=""; REASON=""; BODY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE=${2:-}; shift 2 ;;
    --verdict) VERDICT=${2:-}; shift 2 ;;
    --reason) REASON=${2:-}; shift 2 ;;
    --body-file) BODY_FILE=${2:-}; shift 2 ;;
    *) echo "polish-record: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case "$MODE" in full|quick) ;; *) echo "polish-record: --mode must be full or quick" >&2; exit 2 ;; esac
case "$VERDICT" in ready|not-ready) ;; *) echo "polish-record: --verdict must be ready or not-ready" >&2; exit 2 ;; esac
[[ -z "$BODY_FILE" || -r "$BODY_FILE" ]] || { echo "polish-record: cannot read '$BODY_FILE'" >&2; exit 2; }

vline="Verdict: $VERDICT"; [[ -z "$REASON" ]] || vline="$vline ($REASON)"
head_body=$(git log -1 --format=%B HEAD) || exit 2

if printf '%s\n' "$head_body" | grep -Eq '^Verdict: ' && [[ -z "$(git branch -r --contains HEAD)" ]]; then
  new=$(printf '%s\n' "$head_body" | grep -Ev '^(Verdict|Mode): ')
  new=$(printf '%s\nMode: %s\n%s\n' "$new" "$MODE" "$vline")
  git commit -q --amend -m "$new" || exit 2
  echo "amended $(git rev-parse --short HEAD): $vline"
else
  body=""; [[ -z "$BODY_FILE" ]] || body=$(cat "$BODY_FILE")
  msg=$(printf 'polish: record — %s\n\n%s\n\nMode: %s\n%s\n' "$VERDICT" "$body" "$MODE" "$vline")
  git commit -q --allow-empty -m "$msg" || exit 2
  echo "recorded $(git rev-parse --short HEAD): $vline"
fi
