#!/usr/bin/env bats
# scripts/ci/cache-push.sh (root V5, D40, D41): push one Linux system's
# orca-ide closure to the cache and pin it; nothing else, never darwin.
# nix, cachix and cachix-pin.sh are stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  push="$BATS_TEST_DIRNAME/../../../../scripts/ci/cache-push.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "nix $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in
*"eval"*) [ -z "${STUB_NO_PKG:-}" ] && echo true || echo false ;;
*"build"*) echo /nix/store/aaaa-orca-ide-1.4.232 ;;
esac
STUB
  cat >stubs/cachix <<'STUB'
#!/usr/bin/env bash
echo "cachix $*" >>"$BATS_TEST_TMPDIR/calls"
STUB
  cat >stubs/pin <<'STUB'
#!/usr/bin/env bash
echo "pin $*" >>"$BATS_TEST_TMPDIR/calls"
STUB
  chmod +x stubs/*
  export NIX="$PWD/stubs/nix" CACHIX="$PWD/stubs/cachix" CACHIX_PIN="$PWD/stubs/pin"
}

@test "the orca-ide closure is pushed, then pinned" {
  run --separate-stderr "$push" x86_64-linux
  [ "$status" -eq 0 ]
  grep -qxF "cachix push pr0d1r2 /nix/store/aaaa-orca-ide-1.4.232" calls
  grep -qxF "pin x86_64-linux /nix/store/aaaa-orca-ide-1.4.232" calls
}

@test "only packages.<system>.orca-ide is pushed, never the agents or orca-ide-bin" {
  run --separate-stderr "$push" x86_64-linux
  run ! grep -E "orca-ide-agents|orca-ide-bin|agents" calls
}

@test "a system with no orca-ide package pushes nothing" {
  export STUB_NO_PKG=1
  run --separate-stderr "$push" aarch64-linux
  [ "$status" -eq 0 ]
  run ! grep -q "^cachix\|^pin" calls
}

@test "darwin is refused before any call (root V5, D41)" {
  run --separate-stderr "$push" aarch64-darwin
  [ "$status" -eq 1 ]
  [ "$stderr" = "cache-push: aarch64-darwin is never pushed (root V5, D41)" ]
  [ ! -e calls ]
}

@test "anything but one system is a usage error, exit 2" {
  run --separate-stderr "$push"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: cache-push.sh SYSTEM" ]
}
