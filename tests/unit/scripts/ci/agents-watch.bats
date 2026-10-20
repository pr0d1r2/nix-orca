#!/usr/bin/env bats
# scripts/ci/agents-watch.sh (nix/agents V5, round 11): one issue per Orca
# agent id nobody has decided on; never fails the build. nix, unknown.sh
# and gh are stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  watch="$BATS_TEST_DIRNAME/../../../../scripts/ci/agents-watch.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
case "$*" in
*agent-ids*) echo /nix/store/x-orca-agent-ids ;;
*agents*) echo '["claude","cursor"]' ;;
esac
STUB
  cat >stubs/unknown <<'STUB'
#!/usr/bin/env bash
echo "unknown $*" >>"$BATS_TEST_TMPDIR/calls"
printf '%s\n' ${STUB_NEW:-}
STUB
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in "issue list"*) case "$*" in *"${STUB_OPEN:-none}"*) echo 1 ;; *) echo 0 ;; esac ;; esac
STUB
  chmod +x stubs/*
  export NIX="$PWD/stubs/nix" UNKNOWN="$PWD/stubs/unknown" GH="$PWD/stubs/gh"
}

@test "nothing new: no issue" {
  run --separate-stderr "$watch" x86_64-linux
  [ "$status" -eq 0 ]
  grep -q "^unknown /nix/store/x-orca-agent-ids .*no-package.txt claude cursor$" calls
  run ! grep -q "issue create" calls
}

@test "each new agent gets one issue" {
  export STUB_NEW="newbie other"
  run --separate-stderr "$watch" x86_64-linux
  [ "$status" -eq 0 ]
  grep -q "^gh issue create --title new Orca agent: newbie --body" calls
  grep -q "^gh issue create --title new Orca agent: other --body" calls
}

@test "an agent with an open issue is not reported twice" {
  export STUB_NEW="newbie" STUB_OPEN="newbie"
  run --separate-stderr "$watch" x86_64-linux
  [ "$status" -eq 0 ]
  run ! grep -q "issue create" calls
}

@test "anything but one system is a usage error, exit 2" {
  run --separate-stderr "$watch"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: agents-watch.sh SYSTEM" ]
}
