#!/usr/bin/env bats
# scripts/check/electron-major.sh (nix/linux T2, D21): the source build
# stops when upstream's Electron major is not the pin's, and names the
# fallback package.

bats_require_minimum_version 1.5.0

setup() {
  guard="$BATS_TEST_DIRNAME/../../../../scripts/check/electron-major.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
}

manifest() {
  printf '{"devDependencies": {"electron": "%s"}}\n' "$1" >package.json
}

@test "the same major passes, whatever the minor and patch" {
  manifest 43.7.8
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "a range prefix is read as its version" {
  manifest '^43.2.0'
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 0 ]
}

@test "upstream ahead of the pin fails and names orca-ide-bin" {
  manifest 44.0.1
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"upstream wants Electron 44.0.1, the pin has 43.7.11"* ]]
  [[ "$stderr" == *"orca-ide-bin"* ]]
}

@test "the pin ahead of upstream fails too" {
  manifest 42.1.0
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 1 ]
}

@test "electron under dependencies counts" {
  printf '{"dependencies": {"electron": "43.0.0"}}\n' >package.json
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 0 ]
}

@test "a package.json without electron is refused" {
  printf '{"devDependencies": {}}\n' >package.json
  run --separate-stderr "$guard" package.json 43.7.11
  [ "$status" -eq 1 ]
  [ "$stderr" = "electron-major: package.json names no electron dependency" ]
}

@test "anything but a manifest and a version is a usage error, exit 2" {
  run --separate-stderr "$guard" package.json
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: electron-major.sh PACKAGE-JSON PIN-ELECTRON-VERSION" ]
}
