#!/usr/bin/env bats
# scripts/bump/sherpa-diff.sh (D25, nix/linux §C): whether sherpa-onnx's C
# API header changed between the version upstream bundles and the pin's.
# gh is a stub over the compare API.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  diff="$BATS_TEST_DIRNAME/../../../../scripts/bump/sherpa-diff.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
printf '{"files":[{"filename":"README.md"}%s]}' "${STUB_HEADER:+,{\"filename\":\"sherpa-onnx/c-api/c-api.h\"}}"
STUB
  chmod +x stubs/gh
  export GH="$PWD/stubs/gh"
}

@test "an unchanged header: exit 0, the pin's libraries can be used" {
  run --separate-stderr "$diff" 1.12.37 1.12.38
  [ "$status" -eq 0 ]
  [ "$output" = "sherpa-onnx c-api.h unchanged from 1.12.37 to 1.12.38" ]
  grep -q "repos/k2-fsa/sherpa-onnx/compare/v1.12.37...v1.12.38" calls
}

@test "a changed header: exit 3, keep the bundled libraries" {
  export STUB_HEADER=1
  run --separate-stderr "$diff" 1.12.37 1.12.38
  [ "$status" -eq 3 ]
  [ "$output" = "sherpa-onnx c-api.h changed from 1.12.37 to 1.12.38; keep the bundled libraries (D25)" ]
}

@test "the same version needs no call" {
  run --separate-stderr "$diff" 1.12.38 1.12.38
  [ "$status" -eq 0 ]
  [ ! -e calls ]
}

@test "anything but two versions is a usage error, exit 2" {
  run --separate-stderr "$diff" 1.12.37
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: sherpa-diff.sh BUNDLED-VERSION PIN-VERSION" ]
}
