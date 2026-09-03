#!/usr/bin/env bash
# Scan every commit in <base>..<head> for content that is almost certainly a
# credential: private-key headers, provider token formats, and files whose
# exact name is a credential store. A push publishes history, not just the
# final tree, so each commit's paths, added lines, and message are walked.
#
#   bash scan-secrets.sh <base> [<head>]      (head defaults to HEAD)
#
# Precision over recall, deliberately: a generic "password = '...'" pattern
# matched 60 files of test fixtures and docs in the repo this was built for,
# and a scanner that refuses routine pushes gets bypassed. What is here
# matches formats with essentially no legitimate use in a diff.
#
# Repo-level ignore: a `.ark-scan-ignore` file at the root of <head>'s tree
# lists bash glob patterns, one per line (`#` comments), for paths the scan
# skips entirely -- fixtures, or this scanner's own source. It is read from
# the committed tree, not the working copy.
#
# Exit status:
#   0  nothing found
#   1  at least one hit (stdout, one per line, each prefixed with its commit)
#   2  usage or git error
set -uo pipefail

BASE=${1:-}; HEAD_REF=${2:-HEAD}
if [[ -z "$BASE" ]]; then echo "usage: scan-secrets.sh <base> [<head>]" >&2; exit 2; fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "scan-secrets: unknown base '$BASE'" >&2; exit 2; }
git rev-parse --verify -q "$HEAD_REF^{commit}" >/dev/null || { echo "scan-secrets: unknown head '$HEAD_REF'" >&2; exit 2; }

# Exact credential-store filenames. `.env` and `.env.<anything>` except the
# documented template/example forms; keystores; cloud credential files.
# Not `.pem`: public certificates and CA bundles use it too, and a private
# key inside one is caught by its header in the line scan.
PATH_RE='(^|/)\.env(\.[^/]+)?$|\.tfvars$|\.p12$|\.pfx$|\.jks$|(^|/)id_(rsa|dsa|ecdsa|ed25519)$|(^|/)credentials\.json$|(^|/)service-account[^/]*\.json$|(^|/)kubeconfig$|\.kubeconfig$|\.tfstate(\.backup)?$'
PATH_EXCLUDE_RE='\.env\.(template|example|sample|dist|schema)$|\.(template|example)\.tfvars$'
# Formats that are credentials by construction.
# Token prefixes are guarded by a non-identifier boundary: "disk-reclamation"
# must not match the "sk-" family.
B='(^|[^A-Za-z0-9_])'
LINE_RE="-----BEGIN [A-Z ]*PRIVATE KEY-----|${B}AKIA[0-9A-Z]{16}|${B}gh[pousr]_[A-Za-z0-9]{36}|${B}github_pat_[A-Za-z0-9_]{22,}|${B}glpat-[A-Za-z0-9_-]{20}|${B}xox[abpr]-[A-Za-z0-9-]{10,}|${B}sk-(ant-|proj-)?[A-Za-z0-9_-]{24,}|${B}sk_live_[A-Za-z0-9]{24}|${B}tskey-(api|auth|client)-[A-Za-z0-9]{6,}-[A-Za-z0-9]{10,}|${B}AIza[0-9A-Za-z_-]{35}|${B}npm_[A-Za-z0-9]{36}|${B}SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}"

# grep exits 1 on no match; that is the clean path, not an error. Anything
# above 1 is a scan error. Git commands run separately from the greps: under
# pipefail a failed git followed by a no-match grep would read as "clean".
scan_ok() { [[ $1 -le 1 ]] || { echo "scan-secrets: scan error (status $1)" >&2; exit 2; }; }
git_ok()  { [[ $1 -eq 0 ]] || { echo "scan-secrets: git failed (status $1)" >&2; exit 2; }; }

ignore_patterns=()
if git cat-file -e "$HEAD_REF:.ark-scan-ignore" 2>/dev/null; then
  while IFS= read -r line; do
    line=${line%%#*}; line=${line## }; line=${line%% }
    [[ -n "$line" ]] && ignore_patterns+=("$line")
  done < <(git show "$HEAD_REF:.ark-scan-ignore")
fi
ignored() { local p=$1 pat; for pat in "${ignore_patterns[@]-}"; do [[ -n "$pat" && "$p" == $pat ]] && return 0; done; return 1; }

hits=0
commits=$(git rev-list "$BASE..$HEAD_REF"); git_ok $?

while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  short=${sha:0:7}

  # The commit message is published too, and a pasted credential in a
  # subject or an audit-trail body is invisible to a patch scan.
  msg=$(git log -1 --format=%B "$sha"); git_ok $?
  mlines=$(printf '%s\n' "$msg" | grep -E -e "$LINE_RE"); scan_ok $?
  if [[ -n "$mlines" ]]; then
    while IFS= read -r l; do echo "commit $short: message: $l"; done <<<"$mlines"
    hits=1
  fi

  # -z: NUL-delimited literal paths. Without it git C-quotes names with
  # non-ASCII or control characters ("caf\303\251.txt"), which then fail to
  # address the file and its patch scans as empty.
  names=$(git show --format= --name-only -z "$sha" | tr '\0' '\n'); git_ok "${PIPESTATUS[0]}"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    ignored "$f" && continue
    if printf '%s\n' "$f" | grep -Eq -e "$PATH_RE" && ! printf '%s\n' "$f" | grep -Eq -e "$PATH_EXCLUDE_RE"; then
      echo "commit $short: path: $f"; hits=1
    fi
    # Patterns are passed with -e: LINE_RE begins with "-----BEGIN", which
    # grep would otherwise parse as an option.
    # --literal-pathspecs: a name such as ":(top)x.txt" is a filename here,
    # not pathspec magic.
    patch=$(git --literal-pathspecs show --format= --no-color "$sha" -- "$f"); git_ok $?
    lines=$(printf '%s\n' "$patch" | grep -E -e '^\+' | grep -Ev -e '^\+\+\+' | grep -E -e "$LINE_RE"); scan_ok $?
    if [[ -n "$lines" ]]; then
      while IFS= read -r l; do echo "commit $short: $f: ${l#+}"; done <<<"$lines"
      hits=1
    fi
  done <<<"$names"
done <<<"$commits"

exit "$hits"
