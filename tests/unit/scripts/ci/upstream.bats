#!/usr/bin/env bats
# scripts/ci/upstream.sh (`release` T1, scripts §C rounds 8, 9, D10): the
# daily upstream run. bump.sh, git and gh are stubs that log their calls.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  upstream="$BATS_TEST_DIRNAME/../../../../scripts/ci/upstream.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  printf '{"version":"1.4.230"}\n' >sources.json
  cat >stubs/bump <<'STUB'
#!/usr/bin/env bash
echo "bump" >>"$BATS_TEST_TMPDIR/calls"
[ "${STUB_BUMP:-0}" = 0 ] && printf '{"version":"1.4.232"}\n' >"$SOURCES"
[ "${STUB_BUMP:-0}" = 4 ] && echo "bump: v1.4.230 now points at x, pinned y; upstream moved a released tag (round 9)" >&2
exit "${STUB_BUMP:-0}"
STUB
  cat >stubs/git <<'STUB'
#!/usr/bin/env bash
echo "git $*" >>"$BATS_TEST_TMPDIR/calls"
STUB
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in
"pr view bump/orca-ide"*) [ -n "${STUB_PR:-}" ] && echo "$STUB_PR" ;;
"issue list"*) echo "${STUB_ISSUES:-0}" ;;
esac
STUB
  chmod +x stubs/*
  export BUMP="$PWD/stubs/bump" GIT="$PWD/stubs/git" GH="$PWD/stubs/gh" SOURCES="$PWD/sources.json"
}

@test "up to date: nothing is pushed, opened or merged" {
  export STUB_BUMP=3
  run --separate-stderr "$upstream"
  [ "$status" -eq 0 ]
  [ "$(cat calls)" = "bump" ]
}

@test "a new version goes to bump/orca-ide as one PR that merges itself" {
  run --separate-stderr "$upstream"
  [ "$status" -eq 0 ]
  grep -qxF "git checkout -B bump/orca-ide" calls
  grep -qxF "git commit -m chore(bump): orca-ide 1.4.230 -> 1.4.232 -- nix/sources.json" calls
  grep -qxF "git push --force origin bump/orca-ide" calls
  grep -q "^gh pr create --head bump/orca-ide --title chore(bump): orca-ide 1.4.230 -> 1.4.232" calls
  grep -qxF "gh pr merge bump/orca-ide --auto --merge" calls
}

@test "the next run updates the open PR in place" {
  export STUB_PR=true
  run --separate-stderr "$upstream"
  [ "$status" -eq 0 ]
  run ! grep -q "^gh pr create" calls
  grep -q "^gh pr edit bump/orca-ide --title chore(bump): orca-ide 1.4.230 -> 1.4.232" calls
}

@test "a merged or closed bump PR is not edited; a new one opens" {
  export STUB_PR=false
  run --separate-stderr "$upstream"
  [ "$status" -eq 0 ]
  grep -q "^gh pr create --head bump/orca-ide" calls
  run ! grep -q "^gh pr edit" calls
}

@test "a moved upstream tag opens one issue and fails the run" {
  export STUB_BUMP=4
  run --separate-stderr "$upstream"
  [ "$status" -eq 1 ]
  grep -q "^gh issue create --title upstream moved a released tag or asset --body" calls
  run ! grep -q "^git " calls
}

@test "an issue already open is not opened twice" {
  export STUB_BUMP=4 STUB_ISSUES=1
  run --separate-stderr "$upstream"
  [ "$status" -eq 1 ]
  run ! grep -q "^gh issue create" calls
}

@test "any other bump failure fails the run and touches nothing" {
  export STUB_BUMP=1
  run --separate-stderr "$upstream"
  [ "$status" -eq 1 ]
  [ "$(cat calls)" = "bump" ]
}
