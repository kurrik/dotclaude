#!/usr/bin/env bash
# Exercises reset-worktree.sh against a throwaway origin + clone + worktree.
# Run directly: bash plugins/ark/scripts/reset-worktree.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reset-worktree.sh"
ROOT=$(mktemp -d)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
PASS=0; FAIL=0
hdr() { printf '\n=========== %s ===========\n' "$*"; }
ck()  { if [[ "$2" == "$3" ]]; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1 (got '$2' want '$3')"; FAIL=$((FAIL+1)); fi; }
has() { if grep -q "$2" <<<"$3"; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1 (missing '$2')"; FAIL=$((FAIL+1)); fi; }

git init -q --bare "$ROOT/origin.git"
git init -q -b main "$ROOT/seed"; cd "$ROOT/seed"
echo v1 > file.txt && git add . && git commit -qm "v1"
git remote add origin "$ROOT/origin.git" && git push -q origin main

git clone -q "$ROOT/origin.git" "$ROOT/a17k"   # primary worktree sits on main, like real life
cd "$ROOT/seed" && echo v2 > file.txt && git commit -qam "v2" && git push -q origin main
V2=$(git rev-parse HEAD)
cd "$ROOT/a17k"

hdr "TEST 1: branch does not exist yet -> created at base tip"
git worktree add -q --detach "$ROOT/a17k-01" HEAD
cd "$ROOT/a17k-01"
bash "$SCRIPT"; echo "exit=$?"
ck "branch name" "$(git rev-parse --abbrev-ref HEAD)" "worktree/a17k-01"
ck "at origin/main tip" "$(git rev-parse HEAD)" "$V2"
ck "file content" "$(cat file.txt)" "v2"

hdr "TEST 2: dirty worktree, no --force -> exit 3, nothing touched"
echo local-junk > file.txt; echo untracked > scratch.md
bash "$SCRIPT"; ec=$?; echo "exit=$ec"
ck "exit code" "$ec" "3"
ck "dirty file untouched" "$(cat file.txt)" "local-junk"

hdr "TEST 3: dirty worktree with --force -> reset"
bash "$SCRIPT" --force; ec=$?; echo "exit=$ec"
ck "exit code" "$ec" "0"
ck "file restored" "$(cat file.txt)" "v2"
ck "untracked survives (documented)" "$([[ -f scratch.md ]] && echo yes)" "yes"
rm -f scratch.md

hdr "TEST 4: existing branch with diverged commits -> reset to new base tip"
git commit -qam "worktree work" --allow-empty
cd "$ROOT/seed" && echo v3 > file.txt && git commit -qam "v3" && git push -q origin main
V3=$(git rev-parse HEAD); cd "$ROOT/a17k-01"
bash "$SCRIPT"; echo "exit=$?"
ck "reset to v3" "$(git rev-parse HEAD)" "$V3"
ck "branch unchanged" "$(git rev-parse --abbrev-ref HEAD)" "worktree/a17k-01"

hdr "TEST 5: branch was pushed (upstream set) -> upstream unset, remote kept"
git push -q -u origin worktree/a17k-01
ck "upstream present before" "$(git rev-parse --abbrev-ref 'worktree/a17k-01@{upstream}' 2>/dev/null)" "origin/worktree/a17k-01"
bash "$SCRIPT"; echo "exit=$?"
ck "upstream unset" "$(git rev-parse --abbrev-ref 'worktree/a17k-01@{upstream}' 2>/dev/null || echo none)" "none"
ck "remote branch left alone" "$(git ls-remote --heads origin worktree/a17k-01 | wc -l | tr -d ' ')" "1"

hdr "TEST 6: --base with a non-main base branch"
cd "$ROOT/seed" && git checkout -qb develop && echo dev > d.txt && git add . && git commit -qm dev && git push -q origin develop
cd "$ROOT/a17k" && git worktree add -q --detach "$ROOT/a17k-02" HEAD
cd "$ROOT/a17k-02"
bash "$SCRIPT" --base develop; echo "exit=$?"
ck "branch" "$(git rev-parse --abbrev-ref HEAD)" "worktree/a17k-02"
ck "has develop file" "$([[ -f d.txt ]] && echo yes)" "yes"

hdr "TEST 7: --prefix override and --prefix '' (bare basename)"
bash "$SCRIPT" --prefix wt --base develop --force; echo "exit=$?"
ck "custom prefix" "$(git rev-parse --abbrev-ref HEAD)" "wt/a17k-02"
bash "$SCRIPT" --prefix '' --base develop --force; echo "exit=$?"
ck "empty prefix -> bare name" "$(git rev-parse --abbrev-ref HEAD)" "a17k-02"

hdr "TEST 8: --prefix main (D/F conflict) -> clean refusal, exit 1"
out=$(bash "$SCRIPT" --prefix main 2>&1); ec=$?
echo "$out"; echo "exit=$ec"
ck "exit code" "$ec" "1"
has "explains the conflict" 'can never be created' "$out"

hdr "TEST 9: --dry-run changes nothing"
cd "$ROOT/a17k-01" && git commit -qam "dirty work" --allow-empty
B=$(git rev-parse HEAD)
bash "$SCRIPT" --dry-run; echo "exit=$?"
ck "HEAD unchanged" "$(git rev-parse HEAD)" "$B"

hdr "TEST 10: local main free (not checked out) -> direct main:main fetch"
cd "$ROOT/a17k" && git checkout -q --detach HEAD
cd "$ROOT/a17k-01" && bash "$SCRIPT" 2>&1 | grep -E 'main +-> +main|Done|Checking'
ck "reset to local main" "$(git rev-parse HEAD)" "$(git rev-parse main)"

hdr "TEST 11: nonexistent base -> clean error"
out=$(bash "$SCRIPT" --base nope 2>&1); ec=$?; echo "$out"; echo "exit=$ec"
ck "exit code" "$ec" "1"
has "clear message" "no 'nope' branch" "$out"

hdr "TEST 12: bad flag / primary worktree no-op"
bash "$SCRIPT" --bogus; ck "bad flag exit" "$?" "1"
cd "$ROOT/a17k"; out=$(bash "$SCRIPT"); ck "primary worktree exit" "$?" "0"
echo "$out"; has "no-op message" 'nothing to do' "$out"

printf '\n===== %d passed, %d failed =====\n' "$PASS" "$FAIL"
rm -rf "$ROOT"
[[ $FAIL -eq 0 ]]
