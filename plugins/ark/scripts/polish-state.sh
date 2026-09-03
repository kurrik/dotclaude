#!/usr/bin/env bash
# Report the polish state of a branch tip as key=value lines. This is the one
# implementation of "has this tip been polished, and what did polish say?" --
# ark:polish and ark:pr both read it, neither re-derives it.
#
#   bash polish-state.sh <base> [<head>]     (head defaults to HEAD)
#
# The record is the newest commit in <base>..<head> whose git trailer block
# (the final paragraph, as `git interpret-trailers --parse` reads it) carries
# both `Mode: full|quick` and `Verdict: ready|not-ready|pending` -- the pair
# polish-record.sh writes. A subject that merely starts with "polish:", or a
# body that mentions "Verdict: ready" in passing, is not a record. Output:
#
#   dirty=yes|no                 working tree or index has changes
#   record=<sha>|none            the record commit
#   mode=full|quick|none         its Mode: trailer
#   verdict=ready|not-ready|pending|none
#   reason=<text>                the parenthesised part of a not-ready verdict
#   at_head=yes|no               the record commit is <head>
#   round_start=<sha>|none       parent of the earliest of the consecutive
#                                record commits ending at <head> (only when
#                                at_head=yes) -- where a verification round
#                                or a quick->full upgrade diffs from
#   unreviewed_from=<rev>        record sha when one exists, else <base>
#   unreviewed_commits=<n>       commits in unreviewed_from..<head>
#   state=covered|unverified|not-ready|unreviewed
#
# state: a not-ready or pending verdict anywhere on the branch is not-ready
# (the verdict belongs to the branch until a later run replaces it); a ready
# verdict at head is covered (full) or unverified (quick); a ready verdict
# with commits after it, or no record, is unreviewed.
#
# Exit 0 normally, 2 on a usage or git error.
set -uo pipefail
BASE=${1:-}; HEAD_REF=${2:-HEAD}
[[ -n "$BASE" ]] || { echo "usage: polish-state.sh <base> [<head>]" >&2; exit 2; }
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "polish-state: unknown base '$BASE'" >&2; exit 2; }
HEAD_SHA=$(git rev-parse --verify -q "$HEAD_REF^{commit}") || { echo "polish-state: unknown head '$HEAD_REF'" >&2; exit 2; }

# shellcheck source=record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/record-lib.sh"

dirty=no; [[ -z "$(git status --porcelain)" ]] || dirty=yes
record=none; mode=none; verdict=none; reason=""; at_head=no; round_start=none
candidates=$(git log --grep='^Verdict: ' --format=%H "$BASE..$HEAD_REF") || exit 2
while IFS= read -r c; do
  [[ -n "$c" ]] || continue
  if read_record "$c"; then record=$c; break; fi
done <<<"$candidates"
if [[ "$record" != none ]]; then
  mode=$REC_MODE; verdict=$REC_VERDICT; reason=$REC_REASON
  if [[ "$record" == "$HEAD_SHA" ]]; then
    at_head=yes
    cur=$HEAD_SHA
    while read_record "$cur"; do
      parent=$(git rev-parse -q --verify "$cur^" 2>/dev/null) || break
      # stop at the base: never walk past the branch range
      git merge-base --is-ancestor "$parent" "$BASE" && { round_start=$parent; break; }
      round_start=$parent; cur=$parent
    done
  fi
fi
unreviewed_from=$BASE; [[ "$record" == none ]] || unreviewed_from=$record
unreviewed_commits=$(git rev-list --count "$unreviewed_from..$HEAD_REF") || exit 2

case "$verdict" in
  not-ready|pending) state=not-ready ;;
  ready) if [[ $at_head == yes ]]; then
           [[ $mode == quick ]] && state=unverified || state=covered
         else state=unreviewed; fi ;;
  *) state=unreviewed ;;
esac

printf 'dirty=%s\nrecord=%s\nmode=%s\nverdict=%s\nreason=%s\nat_head=%s\nround_start=%s\nunreviewed_from=%s\nunreviewed_commits=%s\nstate=%s\n' \
  "$dirty" "$record" "$mode" "$verdict" "$reason" "$at_head" "$round_start" "$unreviewed_from" "$unreviewed_commits" "$state"
