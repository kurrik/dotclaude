#!/usr/bin/env bash
# Exercises scan-secrets.sh against a throwaway repo.
# Run directly: bash plugins/ark/scripts/scan-secrets.test.sh
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
TOKEN="ghp_$(printf 'a%.0s' $(seq 36))"          # GitHub PAT shape, 36 chars after the prefix

git init -q -b main "$ROOT/repo" || fatal "cannot init"
cd "$ROOT/repo" || fatal "cannot cd"
echo base > a.txt && git add . && git commit -qm base

hdr "TEST 1: ordinary code, fixtures, templates -> exit 0 (precision over recall)"
git checkout -qb clean
printf 'password: process.env.PW\nconst TEST_SECRET = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";\nclientSecret: "plain-secret",\nTAILSCALE_OAUTH_CLIENT_SECRET: "tskey-client-...",\n' > src.ts
printf 'DATABASE_URL=\n' > .env.template
printf 'project = ""\n' > production.template.tfvars
mkdir -p docs && printf '# Secrets\nsee infra/secrets.md\n' > docs/secrets.md
printf -- '-----BEGIN CERTIFICATE-----\nMIIC\n-----END CERTIFICATE-----\n' > ca.pem
git add -A && git commit -qm clean
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "0"
ck "no output" "$out" ""

hdr "TEST 2: token added then deleted -> still found, attributed to its commit and file"
git checkout -qb leaked main
printf 'GITHUB_TOKEN = "%s"\n' "$TOKEN" > c.txt && git add . && git commit -qm add
SHA=$(git rev-parse --short=7 HEAD)
printf 'clean\n' > c.txt && git commit -qam rm
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "hit names the commit and file" "commit $SHA: c.txt: GITHUB_TOKEN" "$out"
ck "endpoint diff would have missed it" "$(git diff main...HEAD | grep -c ghp_)" "0"

hdr "TEST 3: credential-store filename -> found by name, attributed, even after deletion"
git checkout -qb envfile main
mkdir -p infra && echo 'nothing' > infra/.env && git add -f infra/.env && git commit -qm env
ENVSHA=$(git rev-parse --short=7 HEAD)
git rm -q infra/.env && git commit -qm "remove env"
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "path reported with its commit" "commit $ENVSHA: path: infra/.env" "$out"

hdr "TEST 4: private key header and AWS key id in a source file"
git checkout -qb pem main
printf -- '-----BEGIN RSA PRIVATE KEY-----\nMIIB\n' > k.txt && printf 'id = "AKIAABCDEFGHIJKLMNOP"\n' > aws.tf && git add . && git commit -qm keys
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "pem header" "k.txt: -----BEGIN RSA PRIVATE KEY" "$out"
has "aws key id" "aws.tf: id = \"AKIA" "$out"

hdr "TEST 4b: non-ASCII filename is addressed literally, not C-quoted"
git checkout -qb utf8 main
printf 'x = "%s"\n' "$TOKEN" > 'café.txt' && git add . && git commit -qm utf8
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "hit names the literal path" "café.txt: x = " "$out"

hdr "TEST 5: credential in a commit message, clean tree -> found"
git checkout -qb msg main
echo ok > m.txt && git add . && git commit -qm "note: token $TOKEN"
MSGSHA=$(git rev-parse --short=7 HEAD)
out=$(bash "$SCRIPT" main); ec=$?
ck "exit code" "$ec" "1"
has "message hit attributed" "commit $MSGSHA: message: note: token" "$out"

hdr "TEST 6: .ark-scan-ignore from the committed tree skips fixtures"
git checkout -qb ignored main
mkdir -p tools/fixtures && printf 'expect("%s")\n' "$TOKEN" > tools/fixtures/tokens.txt && printf 'tools/fixtures/*\n' > .ark-scan-ignore
git add -A && git commit -qm fixtures
out=$(bash "$SCRIPT" main); ec=$?
ck "ignored path -> exit 0" "$ec" "0"
printf 'x = "%s"\n' "$TOKEN" > elsewhere.txt && git add . && git commit -qm leak
out=$(bash "$SCRIPT" main); ec=$?
ck "same token outside the ignored path -> 1" "$ec" "1"
ck "only the unignored hit reported" "$(grep -c "$TOKEN" <<<"$out")" "1"

hdr "TEST 7: explicit head ref and usage errors"
out=$(bash "$SCRIPT" main clean); ec=$?
ck "clean head by name" "$ec" "0"
bash "$SCRIPT" >/dev/null 2>&1; ck "no args -> 2" "$?" "2"
bash "$SCRIPT" nope >/dev/null 2>&1; ck "bad base -> 2" "$?" "2"

rm -rf "$ROOT"
printf '\n===== %d passed, %d failed =====\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
