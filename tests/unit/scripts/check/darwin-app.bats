#!/usr/bin/env bats
# scripts/check/darwin-app.sh (nix/darwin T1, V1, V2, V3, V5): checks on the
# store Orca.app. codesign, lipo, PlistBuddy and unzip are stubs named by
# the script's env seams.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/check/darwin-app.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p app/Orca.app/Contents/MacOS zipped/Orca.app/Contents/MacOS stubs
  printf 'binary\n' >app/Orca.app/Contents/MacOS/Orca
  printf 'binary\n' >zipped/Orca.app/Contents/MacOS/Orca
  cat >stubs/codesign <<'STUB'
#!/usr/bin/env bash
case "$1" in
--verify) [ "${STUB_VERIFY:-ok}" = ok ] || { echo "Orca.app: invalid signature" >&2; exit 1; } ;;
-dv) echo "TeamIdentifier=${STUB_TEAM:-6CX3WHS9HZ}" >&2 ;;
esac
STUB
  cat >stubs/lipo <<'STUB'
#!/usr/bin/env bash
echo "${STUB_ARCHS:-arm64}"
STUB
  cat >stubs/plistbuddy <<'STUB'
#!/usr/bin/env bash
echo "${STUB_VERSION:-1.4.230}"
STUB
  cat >stubs/unzip <<'STUB'
#!/usr/bin/env bash
# unzip -q ZIP -d DIR: copies the fixture tree instead.
cp -R "$BATS_TEST_TMPDIR/zipped/." "$4/"
STUB
  chmod +x stubs/*
  export CODESIGN="$BATS_TEST_TMPDIR/stubs/codesign"
  export LIPO="$BATS_TEST_TMPDIR/stubs/lipo"
  export PLISTBUDDY="$BATS_TEST_TMPDIR/stubs/plistbuddy"
  export UNZIP="$BATS_TEST_TMPDIR/stubs/unzip"
  export out="$BATS_TEST_TMPDIR/out"
}

@test "a valid signature from the pinned team passes and writes \$out" {
  run --separate-stderr "$check" codesign app/Orca.app 6CX3WHS9HZ
  [ "$status" -eq 0 ]
  [ -f "$out" ]
}

@test "a broken signature fails" {
  export STUB_VERIFY=bad
  run --separate-stderr "$check" codesign app/Orca.app 6CX3WHS9HZ
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"darwin-app: codesign --verify --deep --strict failed (nix/darwin V1)"* ]]
  [ ! -e "$out" ]
}

@test "another signing team fails and asks for human review" {
  export STUB_TEAM=ZZZZZZZZZZ
  run --separate-stderr "$check" codesign app/Orca.app 6CX3WHS9HZ
  [ "$status" -eq 1 ]
  [ "$stderr" = "darwin-app: TeamIdentifier ZZZZZZZZZZ, pinned 6CX3WHS9HZ; review before re-pinning (nix/darwin V5)" ]
}

@test "arch matches the system, or fails naming both" {
  run "$check" arch app/Orca.app arm64
  [ "$status" -eq 0 ]
  export STUB_ARCHS=x86_64
  run --separate-stderr "$check" arch app/Orca.app arm64
  [ "$status" -eq 1 ]
  [ "$stderr" = "darwin-app: Contents/MacOS/Orca is x86_64, want arm64 (nix/darwin V2)" ]
}

@test "the bundle version is the pinned one" {
  run "$check" version app/Orca.app 1.4.230
  [ "$status" -eq 0 ]
  export STUB_VERSION=1.4.229
  run --separate-stderr "$check" version app/Orca.app 1.4.230
  [ "$status" -eq 1 ]
  [ "$stderr" = "darwin-app: Info.plist says 1.4.229, want 1.4.230" ]
}

@test "the store tree equals the zip byte for byte" {
  run "$check" tree app/Orca.app upstream.zip
  [ "$status" -eq 0 ]
  printf 'patched\n' >app/Orca.app/Contents/MacOS/Orca
  run --separate-stderr "$check" tree app/Orca.app upstream.zip
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"darwin-app: Orca.app differs from upstream's zip (nix/darwin V3)"* ]]
}

@test "an unknown mode is a usage error, exit 2" {
  run --separate-stderr "$check" sideways app/Orca.app x
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: darwin-app.sh codesign|arch|version|tree APP EXPECTED" ]
}
