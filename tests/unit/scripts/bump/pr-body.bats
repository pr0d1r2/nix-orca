#!/usr/bin/env bats
# scripts/bump/pr-body.sh (scripts §C round 9): the bump PR body, the
# dependency report between two upstream tags. gh and lock-diff.sh are
# stubs.

bats_require_minimum_version 1.5.0

setup() {
  body="$BATS_TEST_DIRNAME/../../../../scripts/bump/pr-body.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
echo "content of $2"
STUB
  cat >stubs/lock-diff <<'STUB'
#!/usr/bin/env bash
for f in "$@"; do echo "diff input: $(cat "$f")"; done
STUB
  chmod +x stubs/*
  export GH="$PWD/stubs/gh" LOCK_DIFF="$PWD/stubs/lock-diff"
}

@test "the report compares both tags' lockfiles and workspaces" {
  run --separate-stderr "$body" v1.4.230 v1.4.232
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Upstream v1.4.230 -> v1.4.232"* ]]
  [[ "$output" == *"diff input: content of repos/stablyai/orca/contents/pnpm-lock.yaml?ref=v1.4.230"* ]]
  [[ "$output" == *"diff input: content of repos/stablyai/orca/contents/pnpm-lock.yaml?ref=v1.4.232"* ]]
  [[ "$output" == *"diff input: content of repos/stablyai/orca/contents/pnpm-workspace.yaml?ref=v1.4.230"* ]]
  [[ "$output" == *"diff input: content of repos/stablyai/orca/contents/pnpm-workspace.yaml?ref=v1.4.232"* ]]
  grep -q -- "-H Accept: application/vnd.github.raw" calls
}

@test "anything but two tags is a usage error, exit 2" {
  run --separate-stderr "$body" v1.4.230
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: pr-body.sh FROM-TAG TO-TAG" ]
}
