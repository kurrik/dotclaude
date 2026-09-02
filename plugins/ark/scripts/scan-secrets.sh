#!/usr/bin/env bash
# Scan every commit in <base>..<head> for secret-shaped paths, added lines,
# and commit messages.
#
#   bash scan-secrets.sh <base> [<head>]      (head defaults to HEAD)
#
# A push publishes history, not just the final tree, so this walks each
# commit's patch: a credential committed and deleted two commits later is
# still exposed and an endpoint diff would never show it.
#
# Exit status:
#   0  nothing secret-shaped found
#   1  at least one hit (stdout, one per line, each prefixed with its commit)
#   2  usage or git error
#
# Portable by construction: POSIX classes only ([[:space:]], never \s), no
# GNU-only grep flags, and grep's "no match" status is handled here rather
# than leaking to the caller as a failure.
set -uo pipefail

BASE=${1:-}; HEAD_REF=${2:-HEAD}
if [[ -z "$BASE" ]]; then echo "usage: scan-secrets.sh <base> [<head>]" >&2; exit 2; fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "scan-secrets: unknown base '$BASE'" >&2; exit 2; }
git rev-parse --verify -q "$HEAD_REF^{commit}" >/dev/null || { echo "scan-secrets: unknown head '$HEAD_REF'" >&2; exit 2; }

# Paths whose name alone is a hard stop.
PATH_RE='(^|/)\.env([.]|$)|\.tfvars$|secret|credential|\.pem$|\.key$|(^|/)id_(rsa|ed25519|ecdsa)($|\.)'
# Added lines that look like a credential. Quoted 8+ char values after a
# key-ish name, plus well-known token prefixes and PEM headers.
LINE_RE='-----BEGIN|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[abp]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|(api[_-]?key|secret|token|password|passwd)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}["'"'"']'

hits=0
# grep exits 1 on no match; that is the clean path, not an error. Anything
# above 1 (bad pattern, I/O error) is a scan error. Git commands run
# separately from the greps, never in the same pipeline: under pipefail a
# failed `git show` followed by a no-match grep would report status 1 and
# read as "clean".
scan_ok() { [[ $1 -le 1 ]] || { echo "scan-secrets: scan error (status $1)" >&2; exit 2; }; }
git_ok()  { [[ $1 -eq 0 ]] || { echo "scan-secrets: git failed (status $1)" >&2; exit 2; }; }

commits=$(git rev-list "$BASE..$HEAD_REF"); git_ok $?

# Walk each commit separately so every hit -- path or line -- is attributed
# to the commit that introduced it; the caller needs the SHA to tell whether
# it is already on the remote.
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  short=${sha:0:7}

  names=$(git show --format= --name-only "$sha"); git_ok $?
  # Patterns are passed with -e: LINE_RE begins with "-----BEGIN", which
  # grep would otherwise parse as an option.
  paths=$(printf '%s\n' "$names" | grep -Ei -e "$PATH_RE"); scan_ok $?
  if [[ -n "$paths" ]]; then
    while IFS= read -r p; do echo "commit $short: path: $p"; done <<<"$paths"
    hits=1
  fi

  # The commit message is published by the push too (a pasted credential in
  # a subject or an audit-trail body), and --format= above deliberately
  # hides it from the patch scan, so it gets its own pass.
  msg=$(git log -1 --format=%B "$sha"); git_ok $?
  mlines=$(printf '%s\n' "$msg" | grep -Ei -e "$LINE_RE"); scan_ok $?
  if [[ -n "$mlines" ]]; then
    while IFS= read -r l; do echo "commit $short: message: $l"; done <<<"$mlines"
    hits=1
  fi

  patch=$(git show --format= --no-color "$sha"); git_ok $?
  lines=$(printf '%s\n' "$patch" | grep -E -e '^\+' | grep -Ev -e '^\+\+\+' | grep -Ei -e "$LINE_RE"); scan_ok $?
  if [[ -n "$lines" ]]; then
    while IFS= read -r l; do echo "commit $short: ${l#+}"; done <<<"$lines"
    hits=1
  fi
done <<<"$commits"

exit "$hits"
