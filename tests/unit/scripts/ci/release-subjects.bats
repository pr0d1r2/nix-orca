#!/usr/bin/env bats
# scripts/ci/release-subjects.sh (root §I release, D30): the attestation
# subjects, one NAR hash per system in sha256sum form, for
# attest-build-provenance's subject-checksums. nix is a stub.

bats_require_minimum_version 1.5.0

setup() {
  subjects="$BATS_TEST_DIRNAME/../../../../scripts/ci/release-subjects.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
case "$*" in
"path-info --json --json-format 1 /nix/store/a-orca-ide") echo '{"/nix/store/a-orca-ide":{"narHash":"sha256-AAA="}}' ;;
"path-info --json --json-format 1 /nix/store/b-orca-ide") echo '{"/nix/store/b-orca-ide":{"narHash":"sha256-BBB="}}' ;;
"hash convert --to base16 sha256-AAA=") echo 00aa ;;
"hash convert --to base16 sha256-BBB=") echo 00bb ;;
*) exit 1 ;;
esac
STUB
  chmod +x stubs/nix
  export NIX="$PWD/stubs/nix"
}

@test "one sha256sum line per system, named for the store path" {
  run --separate-stderr "$subjects" x86_64-linux=/nix/store/a-orca-ide aarch64-darwin=/nix/store/b-orca-ide
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "00aa  orca-ide-x86_64-linux.nar" ]
  [ "${lines[1]}" = "00bb  orca-ide-aarch64-darwin.nar" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "a path nix does not know fails" {
  run --separate-stderr "$subjects" x86_64-linux=/nix/store/c-orca-ide
  [ "$status" -ne 0 ]
}

@test "no system is a usage error, exit 2" {
  run --separate-stderr "$subjects"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: release-subjects.sh SYSTEM=PATH..." ]
}
