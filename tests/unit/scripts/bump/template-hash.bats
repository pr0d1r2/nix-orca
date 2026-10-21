#!/usr/bin/env bats
# scripts/bump/template-hash.sh (scripts T1, nix/bin T2): the hash of the
# orcad template piece cut from one Linux system's .deb, read from nix's
# hash mismatch on a fake hash. nix is a stub.

bats_require_minimum_version 1.5.0

setup() {
  template="$BATS_TEST_DIRNAME/../../../../scripts/bump/template-hash.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
case "${STUB_NIX:-mismatch}" in
mismatch)
  echo "error: hash mismatch in fixed-output derivation '/nix/store/x-orcad-template-1.4.232.drv':" >&2
  echo "         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" >&2
  echo "            got:    sha256-NlRqcRqNRsA7z6jtog9wMTmTn1IDlW6jqA5dX55jzBE=" >&2
  exit 1
  ;;
other)
  echo "error: dpkg-deb: not a Debian archive" >&2
  exit 1
  ;;
esac
STUB
  chmod +x stubs/nix
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
}

@test "the hash nix got for the system's template piece" {
  run --separate-stderr "$template" v1.4.232 aarch64-linux orca-ide_1.4.232_arm64.deb sha512-deb
  [ "$status" -eq 0 ]
  [ "$output" = "sha256-NlRqcRqNRsA7z6jtog9wMTmTn1IDlW6jqA5dX55jzBE=" ]
  grep -q "scripts/bump/template-hash.nix" nix.log
  grep -q -- "--argstr tag v1.4.232" nix.log
  grep -q -- "--argstr system aarch64-linux" nix.log
  grep -q -- "--argstr debName orca-ide_1.4.232_arm64.deb" nix.log
  grep -q -- "--argstr debHash sha512-deb" nix.log
}

@test "a failure other than a hash mismatch is refused with nix's output" {
  export STUB_NIX=other
  run --separate-stderr "$template" v1.4.232 x86_64-linux orca-ide_1.4.232_amd64.deb sha512-deb
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"error: dpkg-deb: not a Debian archive"* ]]
  [[ "$stderr" == *"template-hash: no hash mismatch from the fake-hash build of v1.4.232 x86_64-linux"* ]]
}

@test "anything but a tag, a system and the .deb's name and hash is a usage error, exit 2" {
  run --separate-stderr "$template" v1.4.232 x86_64-linux orca-ide_1.4.232_amd64.deb
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: template-hash.sh TAG SYSTEM DEB-NAME DEB-HASH" ]
  [ ! -e nix.log ]
}
