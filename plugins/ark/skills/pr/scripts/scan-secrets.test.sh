#!/usr/bin/env bash
# Exercises scan-secrets.sh against a throwaway repo.
# Run directly: bash plugins/ark/skills/pr/scripts/scan-secrets.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scan-secrets.sh"
ROOT=$(mktemp -d)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
PASS=0; FAIL=0
hdr() { printf '\n=========== %s ===========\n' "$*"; }
ck()  { if [[ "$2" == "$3" ]]; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1 (got '$2' want '$3')"; FAIL=$((FAIL+1)); fi; }
has() { if grep -q "$2" <<<"$3"; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1 (missing '$2')"; FAIL=$((FAIL+1)); fi; }
fatal() { printf '\nFIXTURE ERROR: %s\n' "$*" >&2; rm -rf "$ROOT"; exit 1; }

git init -q -b main "$ROOT/repo" || fatal "cannot init"
cd "$ROOT/repo" || fatal "cannot cd"
echo base > a.txt && git add . && git commit -qm base

hdr "TEST 1: clean branch -> exit 0, no output (grep's no-match is not a failure)"
git checkout -qb clean
printf 'password: process.env.PW\nconst token = readToken();\n' > src.ts && git add . && git commit -qm clean
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "0"
ck "no output" "$out" ""

hdr "TEST 2: secret added then deleted -> still found, attributed to its commit"
git checkout -qb leaked main
printf 'API_KEY = "abcdefghijklmnop"\n' > c.txt && git add . && git commit -qm add
SHA=$(git rev-parse --short=7 HEAD)
printf 'clean\n' > c.txt && git commit -qam rm
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "hit names the commit" "commit $SHA: API_KEY" "$out"
ck "endpoint diff would have missed it" "$(git diff main...HEAD | grep -c API_KEY)" "0"

hdr "TEST 3: secret-shaped path -> found even with harmless content"
git checkout -qb envfile main
mkdir -p infra && echo 'nothing' > infra/.env && git add -f infra/.env && git commit -qm env
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "path reported" "path: infra/.env" "$out"

hdr "TEST 4: spaces around = and single quotes (portable whitespace class)"
git checkout -qb spaced main
printf "password   =   'long-secret-value'\n" > cfg.py && git add . && git commit -qm cfg
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "line reported" "password" "$out"

hdr "TEST 5: explicit head ref and usage errors"
out=$(bash "$SCRIPT" main clean); ec=$?
ck "clean head by name" "$ec" "0"
bash "$SCRIPT" >/dev/null 2>&1; ck "no args -> 2" "$?" "2"
bash "$SCRIPT" nope >/dev/null 2>&1; ck "bad base -> 2" "$?" "2"

rm -rf "$ROOT"
printf '\n===== %d passed, %d failed =====\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
