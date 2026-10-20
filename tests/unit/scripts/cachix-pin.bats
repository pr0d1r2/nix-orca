#!/usr/bin/env bats
# scripts/cachix-pin.sh (scripts T2, V3, D40, root V5, V6): pin a Linux
# orca-ide path in the fleet cache, keeping 2 revisions, never twice in a
# row and never darwin. cachix and curl are stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  pin="$BATS_TEST_DIRNAME/../../../scripts/cachix-pin.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/curl <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >>"$BATS_TEST_TMPDIR/calls"
printf '[{"name":"orca-ide-x86_64-linux","lastRevision":{"storePath":"%s","revision":4}}]' "${STUB_PINNED:-/nix/store/old-orca-ide}"
STUB
  cat >stubs/cachix <<'STUB'
#!/usr/bin/env bash
echo "cachix $*" >>"$BATS_TEST_TMPDIR/calls"
STUB
  chmod +x stubs/*
  export CURL="$BATS_TEST_TMPDIR/stubs/curl" CACHIX="$BATS_TEST_TMPDIR/stubs/cachix"
}

@test "a new path is pinned, keeping two revisions" {
  run --separate-stderr "$pin" x86_64-linux /nix/store/new-orca-ide
  [ "$status" -eq 0 ]
  grep -qxF "cachix pin pr0d1r2 orca-ide-x86_64-linux /nix/store/new-orca-ide --keep-revisions 2" calls
  grep -q "app.cachix.org/api/v1/cache/pr0d1r2/pin" calls
}

@test "the newest pinned path is not pinned again" {
  export STUB_PINNED=/nix/store/new-orca-ide
  run --separate-stderr "$pin" x86_64-linux /nix/store/new-orca-ide
  [ "$status" -eq 0 ]
  [ "$stderr" = "cachix-pin: orca-ide-x86_64-linux already pins /nix/store/new-orca-ide (scripts V3)" ]
  run ! grep -q "^cachix " calls
}

@test "a pin name never pinned before is pinned" {
  run --separate-stderr "$pin" aarch64-linux /nix/store/arm-orca-ide
  [ "$status" -eq 0 ]
  grep -qxF "cachix pin pr0d1r2 orca-ide-aarch64-linux /nix/store/arm-orca-ide --keep-revisions 2" calls
}

@test "darwin is never pinned, or pushed (root V5)" {
  run --separate-stderr "$pin" aarch64-darwin /nix/store/mac-orca-ide
  [ "$status" -eq 1 ]
  [ "$stderr" = "cachix-pin: aarch64-darwin is not cached (root V5, D41)" ]
  [ ! -e calls ]
}

@test "the script never deletes from the cache or changes its retention" {
  run grep -nE 'cachix +(remove|delete|gc)|retention|DELETE' "$pin"
  [ "$status" -eq 1 ]
}

@test "anything but a system and a path is a usage error, exit 2" {
  run --separate-stderr "$pin" x86_64-linux
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: cachix-pin.sh SYSTEM STORE-PATH" ]
}
