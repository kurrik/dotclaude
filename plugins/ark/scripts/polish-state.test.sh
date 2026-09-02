#!/usr/bin/env bash
# Exercises polish-state.sh, polish-record.sh, resolve-base.sh and
# push-branch.sh against a throwaway origin + clone.
# Run directly: bash plugins/ark/scripts/polish-state.test.sh
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT=$(mktemp -d)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
PASS=0; FAIL=0
hdr() { printf '\n=========== %s ===========\n' "$*"; }
ck()  { if [[ "$2" == "$3" ]]; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1 (got '$2' want '$3')"; FAIL=$((FAIL+1)); fi; }
fatal() { printf '\nFIXTURE ERROR: %s\n' "$*" >&2; rm -rf "$ROOT"; exit 1; }
kv() { sed -n "s/^$1=//p" <<<"$2"; }

git init -q --bare -b main "$ROOT/origin.git" || fatal init
git init -q -b main "$ROOT/seed" && cd "$ROOT/seed" || fatal seed
echo v1 > f && git add . && git commit -qm v1 && git remote add origin "$ROOT/origin.git" && git push -q origin main
git clone -q "$ROOT/origin.git" "$ROOT/w" && cd "$ROOT/w" || fatal clone

hdr "resolve-base: remote default branch, with origin/ prefix"
ck "base" "$(bash "$D/resolve-base.sh")" "origin/main"

hdr "state: fresh branch, no record"
git checkout -qb feat && echo a > a && git add . && git commit -qm a
S=$(bash "$D/polish-state.sh" origin/main)
ck "state" "$(kv state "$S")" "unreviewed"; ck "record" "$(kv record "$S")" "none"
ck "unreviewed_from" "$(kv unreviewed_from "$S")" "origin/main"; ck "unreviewed_commits" "$(kv unreviewed_commits "$S")" "1"

hdr "state: a plain 'polish:' subject is not a record"
echo b > b && git add . && git commit -qm 'polish: something ordinary'
ck "state" "$(kv state "$(bash "$D/polish-state.sh" origin/main)")" "unreviewed"

hdr "record: round commit (pending) then amended to ready/quick -> unverified at head"
echo c > c && git add . && git commit -qm $'polish: address round 1\n\n- fix\n\nReviewers: x\nMode: quick\nVerdict: pending'
PEND=$(git rev-parse HEAD)
ck "pending reads as not-ready" "$(kv state "$(bash "$D/polish-state.sh" origin/main)")" "not-ready"
bash "$D/polish-record.sh" --mode quick --verdict ready >/dev/null || fatal record
ck "amended in place (same parent)" "$(git rev-parse HEAD^)" "$(git rev-parse "$PEND^")"
S=$(bash "$D/polish-state.sh" origin/main)
ck "state" "$(kv state "$S")" "unverified"; ck "at_head" "$(kv at_head "$S")" "yes"
ck "round_start = parent of the record" "$(kv round_start "$S")" "$(git rev-parse HEAD^)"

hdr "round_start walks back through adjacent record commits"
echo d > d && git add . && git commit -qm $'polish: address round 1 (second group)\n\nMode: quick\nVerdict: pending'
bash "$D/polish-record.sh" --mode quick --verdict ready >/dev/null
S=$(bash "$D/polish-state.sh" origin/main)
ck "round_start = parent of earliest adjacent record" "$(kv round_start "$S")" "$(git rev-parse HEAD~2)"

hdr "state: ready record with a commit after it -> unreviewed from the record"
REC=$(git rev-parse HEAD)
echo e > e && git add . && git commit -qm e
S=$(bash "$D/polish-state.sh" origin/main)
ck "state" "$(kv state "$S")" "unreviewed"; ck "unreviewed_from" "$(kv unreviewed_from "$S")" "$REC"; ck "count" "$(kv unreviewed_commits "$S")" "1"

hdr "record: no commit this run -> empty record commit; not-ready sticks past later commits"
printf 'parked: the thing\n' > "$ROOT/body"
bash "$D/polish-record.sh" --mode full --verdict not-ready --reason "needs a decision" --body-file "$ROOT/body" >/dev/null
S=$(bash "$D/polish-state.sh" origin/main)
ck "state" "$(kv state "$S")" "not-ready"; ck "reason" "$(kv reason "$S")" "needs a decision"
ck "body carried" "$(git log -1 --format=%B | grep -c 'parked: the thing')" "1"
echo g > g && git add . && git commit -qm followup
ck "still not-ready after a follow-up" "$(kv state "$(bash "$D/polish-state.sh" origin/main)")" "not-ready"

hdr "record: full ready at head -> covered; pushed record is never amended"
bash "$D/polish-record.sh" --mode full --verdict ready >/dev/null
ck "state" "$(kv state "$(bash "$D/polish-state.sh" origin/main)")" "covered"
git push -q -u origin feat; BEFORE=$(git rev-parse HEAD)
bash "$D/polish-record.sh" --mode full --verdict ready >/dev/null
ck "new commit, not amend" "$([[ $(git rev-parse HEAD^) == "$BEFORE" ]] && echo yes)" "yes"

hdr "state: dirty tree is reported"
echo x > x
ck "dirty" "$(kv dirty "$(bash "$D/polish-state.sh" origin/main)")" "yes"; rm x

hdr "push-branch: refuses on a secret, pushes when clean"
git checkout -qb leak && echo 'API_KEY = "abcdefghijklmnop"' > k && git add . && git commit -qm k
bash "$D/push-branch.sh" origin/main >/dev/null; ck "refused" "$?" "1"
ck "nothing pushed" "$(git ls-remote --heads origin leak | wc -l | tr -d ' ')" "0"
git checkout -q feat && echo h > h && git add . && git commit -qm h
bash "$D/push-branch.sh" origin/main >/dev/null 2>&1; ck "pushed" "$?" "0"
ck "remote has tip" "$(git ls-remote origin refs/heads/feat | cut -f1)" "$(git rev-parse HEAD)"
git checkout -q --detach; bash "$D/push-branch.sh" origin/main >/dev/null 2>&1; ck "detached -> 2" "$?" "2"

rm -rf "$ROOT"
printf '\n===== %d passed, %d failed =====\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
