#!/usr/bin/env bats
# scripts/ci/agents-pr.sh (nix/agents T4, round 9): the daily agent-input
# PR, opened for the owner to read and merge. agents-update.sh, git and gh
# are stubs that log their calls.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  pr="$BATS_TEST_DIRNAME/../../../../scripts/ci/agents-pr.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/update <<'STUB'
#!/usr/bin/env bash
echo "update" >>"$BATS_TEST_TMPDIR/calls"
STUB
  cat >stubs/git <<'STUB'
#!/usr/bin/env bash
echo "git $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in "diff --quiet -- flake.lock") [ -z "${STUB_CHANGED:-}" ] ;; esac
STUB
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in "pr view agents/update"*) [ -n "${STUB_PR:-}" ] && echo "$STUB_PR" ;; esac
STUB
  chmod +x stubs/*
  export AGENTS_UPDATE="$PWD/stubs/update" GIT="$PWD/stubs/git" GH="$PWD/stubs/gh"
}

@test "no input moved: nothing is pushed or opened" {
  run --separate-stderr "$pr"
  [ "$status" -eq 0 ]
  run ! grep -qE "^git (commit|push)|^gh pr" calls
}

@test "moved inputs go to agents/update as one PR, never auto-merged" {
  export STUB_CHANGED=1
  run --separate-stderr "$pr"
  [ "$status" -eq 0 ]
  grep -qxF "git checkout -B agents/update" calls
  grep -qxF "git commit -m chore(agents): update agent inputs -- flake.lock" calls
  grep -qxF "git push --force origin agents/update" calls
  grep -q "^gh pr create --head agents/update --title chore(agents): update agent inputs" calls
  run ! grep -q "^gh pr merge" calls
}

@test "an open agents PR is updated in place" {
  export STUB_CHANGED=1 STUB_PR=true
  run --separate-stderr "$pr"
  [ "$status" -eq 0 ]
  run ! grep -q "^gh pr create" calls
}
