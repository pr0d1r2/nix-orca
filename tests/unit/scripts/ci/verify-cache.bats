#!/usr/bin/env bats
# scripts/ci/verify-cache.sh (`release` §C round 8, D20): before a release,
# every Linux orca-ide store path answers from the cache. nix and curl are
# stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  verify="$BATS_TEST_DIRNAME/../../../../scripts/ci/verify-cache.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
case "$*" in
*x86_64-linux*) echo -n /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-orca-ide-1.4.232 ;;
*aarch64-linux*) [ -z "${STUB_NO_ARM:-}" ] && echo -n /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-orca-ide-1.4.232 ;;
esac
STUB
  cat >stubs/curl <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in *"${STUB_MISSING:-none}"*) exit 22 ;; esac
STUB
  chmod +x stubs/*
  export NIX="$PWD/stubs/nix" CURL="$PWD/stubs/curl"
}

@test "every Linux path answers from the cache" {
  run --separate-stderr "$verify" x86_64-linux aarch64-linux
  [ "$status" -eq 0 ]
  grep -q "https://pr0d1r2.cachix.org/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.narinfo" calls
  grep -q "https://pr0d1r2.cachix.org/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.narinfo" calls
}

@test "a path missing from the cache stops the release" {
  export STUB_MISSING=bbbbbbbb
  run --separate-stderr "$verify" x86_64-linux aarch64-linux
  [ "$status" -eq 1 ]
  [ "$stderr" = "verify-cache: aarch64-linux /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-orca-ide-1.4.232 is not in pr0d1r2.cachix.org; no release" ]
}

@test "a Linux system with no orca-ide package stops the release" {
  export STUB_NO_ARM=1
  run --separate-stderr "$verify" x86_64-linux aarch64-linux
  [ "$status" -eq 1 ]
  [ "$stderr" = "verify-cache: aarch64-linux has no orca-ide package; no release" ]
}

@test "darwin is never expected in the cache (root V5)" {
  run --separate-stderr "$verify" aarch64-darwin
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: verify-cache.sh LINUX-SYSTEM..." ]
}
