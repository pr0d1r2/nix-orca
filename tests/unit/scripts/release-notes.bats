#!/usr/bin/env bats
# scripts/release-notes.sh (scripts T3, V4, root §I release, D13, D14, D15,
# D29): the release notes, text only. nix, nvd, vulnix and git are stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  notes="$BATS_TEST_DIRNAME/../../../scripts/release-notes.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
path=${@: -1}
case "$*" in
*"path-info --json"*) printf '{"%s":{"narHash":"sha256-NAR","narSize":1000}}' "$path" ;;
*"path-info -S"*) printf '%s\t5000\n' "$path" ;;
esac
STUB
  cat >stubs/nvd <<'STUB'
#!/usr/bin/env bash
echo "<<< $2"
echo ">>> $3"
echo "Version changes: orca-ide 1.4.230 -> 1.4.232"
STUB
  cat >stubs/vulnix <<'STUB'
#!/usr/bin/env bash
echo '[{"name":"libfoo-1.0","affected_by":["CVE-2026-1"],"cvssv3_basescore":{"CVE-2026-1":9.8}}]'
exit 2
STUB
  cat >stubs/git <<'STUB'
#!/usr/bin/env bash
echo 0123456789abcdef0123456789abcdef01234567
STUB
  chmod +x stubs/*
  printf '{"nodes":{"nixpkgs":{"locked":{"rev":"f3a73bcf5d1c5b75a66cf35a48957e30d41d647a"}}}}' >flake.lock
  export NIX="$PWD/stubs/nix" NVD="$PWD/stubs/nvd" VULNIX="$PWD/stubs/vulnix" GIT="$PWD/stubs/git"
  export FLAKE_LOCK="$PWD/flake.lock" ORCA_VERSION=1.4.232
}

@test "per system: store path, NAR hash and size, closure, pin, commit" {
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232
  [ "$status" -eq 0 ]
  [[ "$output" == *"## x86_64-linux"* ]]
  [[ "$output" == *"- store path: \`/nix/store/abc-orca-ide-1.4.232\`"* ]]
  [[ "$output" == *"- NAR hash: \`sha256-NAR\`, NAR size: 1000 bytes"* ]]
  [[ "$output" == *"- closure size: 5000 bytes"* ]]
  [[ "$output" == *"- nixpkgs: \`f3a73bcf5d1c5b75a66cf35a48957e30d41d647a\`"* ]]
  [[ "$output" == *"- commit: \`0123456789abcdef0123456789abcdef01234567\`"* ]]
}

@test "a previous path brings the nvd closure diff" {
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232:/nix/store/old-orca-ide-1.4.230
  [[ "$output" == *"Version changes: orca-ide 1.4.230 -> 1.4.232"* ]]
}

@test "no previous path says so" {
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232
  [[ "$output" == *"- closure diff: first release, nothing to compare"* ]]
}

@test "vulnix findings are listed, report-only, and never fail the notes" {
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232
  [ "$status" -eq 0 ]
  [[ "$output" == *"- vulnix (report-only): 1 finding"* ]]
  [[ "$output" == *"  - libfoo-1.0: CVE-2026-1 (CVSS 9.8)"* ]]
}

@test "the rebuild result and Electron lag come from CI" {
  export REBUILD_x86_64_linux=bit-identical ELECTRON_UPSTREAM=43.8.0 ELECTRON_PIN=43.7.11
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232
  [[ "$output" == *"- \`--rebuild\`: bit-identical"* ]]
  [[ "$output" == *"Electron: upstream 43.8.0, pin 43.7.11 (report-only, D15)"* ]]
}

@test "darwin notes say the app is upstream's signed zip and never cached" {
  run --separate-stderr "$notes" aarch64-darwin=/nix/store/mac-orca-ide-1.4.232
  [[ "$output" == *"upstream's signed Orca.app; not in the binary cache, nix fetches the zip from GitHub (D41)"* ]]
}

@test "the notes never attach or upload a binary (V4)" {
  run --separate-stderr "$notes" x86_64-linux=/nix/store/abc-orca-ide-1.4.232
  [[ "$output" == *"This release attaches no binaries"* ]]
  run grep -nE 'gh release (upload|create)|--attach|curl .*-T ' "$notes"
  [ "$status" -eq 1 ]
}

@test "no system is a usage error, exit 2" {
  run --separate-stderr "$notes"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: release-notes.sh SYSTEM=PATH[:PREVIOUS]..." ]
}
