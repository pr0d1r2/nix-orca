#!/usr/bin/env bats
# scripts/check/linux-app.sh (nix/linux T2): checks on the Linux orca-ide.
# Each mode compares one fact with its pinned value and writes $out on a
# pass, so a check derivation is one call. The package is a small fake.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/check/linux-app.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p pkg/bin src
  cat >pkg/bin/orca-ide <<'STUB'
#!/usr/bin/env bash
[ "$1" = --version ] && echo "${STUB_VERSION:-1.4.232}"
STUB
  chmod +x pkg/bin/orca-ide
  printf '{"devDependencies": {"electron": "43.7.8"}}\n' >src/package.json
  export out=$BATS_TEST_TMPDIR/out
}

@test "version: bin/orca-ide --version prints the pinned version" {
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "version: another version fails and names V4" {
  export STUB_VERSION=1.4.230
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: bin/orca-ide --version printed 1.4.230, want 1.4.232 (nix/linux V4)" ]
  [ ! -e "$out" ]
}

@test "electron-major: upstream's package.json against the pin's Electron" {
  run --separate-stderr "$check" electron-major src 43.7.11
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "electron-major: another major fails with the guard's message" {
  run --separate-stderr "$check" electron-major src 44.0.0
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"orca-ide-bin"* ]]
  [ ! -e "$out" ]
}

@test "without out set, a pass writes nothing" {
  unset out
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 0 ]
}

@test "an unknown mode or wrong arguments are a usage error, exit 2" {
  run --separate-stderr "$check" colour pkg 1
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: linux-app.sh version|electron-major PATH EXPECTED" ]
  run --separate-stderr "$check" version pkg
  [ "$status" -eq 2 ]
}
