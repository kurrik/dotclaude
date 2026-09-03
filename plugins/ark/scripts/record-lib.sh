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
  # The whole value must have the generated shape: exactly `ready` or
  # `pending`, or `not-ready` with at most one parenthesised reason. A
  # human trailer such as "Verdict: ready for QA" is not a record.
  if [[ "$vline" =~ ^(ready|pending)$ ]]; then
    REC_VERDICT=$vline; REC_REASON=""
  elif [[ "$vline" =~ ^not-ready(\ \((.*)\))?$ ]]; then
    REC_VERDICT=not-ready; REC_REASON=${BASH_REMATCH[2]}
  else
    REC_VERDICT=""; REC_REASON=""; return 1
  fi
  [[ "$REC_MODE" =~ ^(full|quick)$ ]]
}
