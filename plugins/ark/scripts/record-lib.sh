#!/usr/bin/env bash
# Shared by polish-state.sh and polish-record.sh: the one definition of a
# polish record. Source it; do not run it.
#
#   read_record <commit>   -> 0 iff the commit's git trailer block carries
#                             Mode: full|quick and Verdict: ready|not-ready|pending.
#                             Sets REC_MODE, REC_VERDICT, REC_REASON.
#
# Only the trailer block counts (`git interpret-trailers --parse`): a body
# that mentions "Verdict: ready" in passing, or trailers glued to the subject
# line, is not a record.
read_record() {
  local t
  t=$(git log -1 --format=%B "$1" | git interpret-trailers --parse) || return 1
  REC_MODE=$(printf '%s\n' "$t" | sed -n 's/^Mode: *//p' | tail -1)
  local vline; vline=$(printf '%s\n' "$t" | sed -n 's/^Verdict: *//p' | tail -1)
  REC_VERDICT=${vline%% *}
  REC_REASON=$(printf '%s' "$vline" | sed -n 's/^[^ ]* *(\(.*\))$/\1/p')
  [[ "$REC_MODE" =~ ^(full|quick)$ && "$REC_VERDICT" =~ ^(ready|not-ready|pending)$ ]]
}
