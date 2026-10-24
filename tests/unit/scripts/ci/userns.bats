#!/usr/bin/env bats
# scripts/ci/userns.sh (nix/agents V3): on an Ubuntu 24.04 runner, AppArmor
# keeps unprivileged processes out of new user namespaces, so bwrap inside
# the nix sandbox (`rovo`, `acli`) fails `--version` with "setting up uid
# map: Permission denied". The script turns that restriction off, or does
# nothing where the kernel has no such knob. sudo and sysctl are stubs; the
# knob is a file.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  userns="$BATS_TEST_DIRNAME/../../../../scripts/ci/userns.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/sudo <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB
  cat >stubs/sysctl <<'STUB'
#!/usr/bin/env bash
echo "sysctl $*" >>"$BATS_TEST_TMPDIR/sysctl.log"
[ -n "${STUB_STUCK:-}" ] || echo 0 >"$USERNS_KNOB"
STUB
  chmod +x stubs/*
  echo 1 >knob
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export USERNS_KNOB=$BATS_TEST_TMPDIR/knob
}

@test "the AppArmor restriction is turned off" {
  run --separate-stderr "$userns"
  [ "$status" -eq 0 ]
  [ "$(cat sysctl.log)" = "sysctl -w kernel.apparmor_restrict_unprivileged_userns=0" ]
  [ "$(cat knob)" = 0 ]
}

@test "a kernel without the knob needs nothing" {
  rm knob
  run --separate-stderr "$userns"
  [ "$status" -eq 0 ]
  [ ! -e sysctl.log ]
}

@test "a knob still set after sysctl fails loudly" {
  export STUB_STUCK=1
  run --separate-stderr "$userns"
  [ "$status" -eq 1 ]
  [ "$stderr" = "userns: $BATS_TEST_TMPDIR/knob is still 1; bwrap in the nix sandbox cannot make a user namespace" ]
}

@test "any argument is a usage error, exit 2" {
  run --separate-stderr "$userns" x86_64-linux
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: userns.sh" ]
}
