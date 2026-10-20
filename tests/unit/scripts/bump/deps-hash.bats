#!/usr/bin/env bats
# scripts/bump/deps-hash.sh (scripts T1): the JS deps hash for a tag, read
# from nix's hash mismatch on a fake hash. nix is a stub.

bats_require_minimum_version 1.5.0

setup() {
  deps="$BATS_TEST_DIRNAME/../../../../scripts/bump/deps-hash.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
case "${STUB_NIX:-mismatch}" in
mismatch)
  echo "error: hash mismatch in fixed-output derivation '/nix/store/x-orca-ide-pnpm-deps.drv':" >&2
  echo "         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" >&2
  echo "            got:    sha256-r/JS7KYjMDdBcbb67eiriz+0SmyPwIf5tYLoop0u//o=" >&2
  exit 1
  ;;
other)
  echo "error: pnpm install failed" >&2
  exit 1
  ;;
esac
STUB
  chmod +x stubs/nix
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
}

@test "the hash nix got for the deps fetch" {
  run --separate-stderr "$deps" v1.4.230 sha256-up9LF/UQd2LAf/Jd40TO9dEYScKM9HK0vB6qTUf5XRw=
  [ "$status" -eq 0 ]
  [ "$output" = "sha256-r/JS7KYjMDdBcbb67eiriz+0SmyPwIf5tYLoop0u//o=" ]
  grep -q -- "--argstr tag v1.4.230" nix.log
  grep -q -- "--argstr srcHash sha256-up9LF/UQd2LAf/Jd40TO9dEYScKM9HK0vB6qTUf5XRw=" nix.log
  grep -q "scripts/bump/deps-hash.nix" nix.log
}

@test "a failure other than a hash mismatch is refused with nix's output" {
  export STUB_NIX=other
  run --separate-stderr "$deps" v1.4.230 sha256-x
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"error: pnpm install failed"* ]]
  [[ "$stderr" == *"deps-hash: no hash mismatch from the fake-hash build of v1.4.230"* ]]
}

@test "anything but a tag and a source hash is a usage error, exit 2" {
  run --separate-stderr "$deps" v1.4.230
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: deps-hash.sh TAG SRC-HASH" ]
}
