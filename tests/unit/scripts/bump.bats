#!/usr/bin/env bats
# scripts/bump.sh (scripts T1, V1, V2, D12, round 9): the upstream bump.
# Its tools (latest-tag, source, deps-hash, template-hash, manifest) are
# stubs in
# BUMP_TOOLS; nix/sources.json is a fixture copy.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  bump="$BATS_TEST_DIRNAME/../../../scripts/bump.sh"
  # A fixed v1.4.230 pin, not the live file a real bump moves.
  cp "$BATS_TEST_DIRNAME/fixtures/sources-1.4.230.json" "$BATS_TEST_TMPDIR/sources.json"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir tools
  cat >tools/latest-tag.sh <<'STUB'
#!/usr/bin/env bash
echo "${STUB_LATEST:-v1.4.230}"
STUB
  cat >tools/source.sh <<'STUB'
#!/usr/bin/env bash
case "$1" in
v1.4.230) echo "{\"commit\":\"${STUB_PINNED_COMMIT:-b2879bd5aaac5d27c101ccf4171faa25d9f0bb1e}\",\"hash\":\"sha256-old\"}" ;;
*) echo '{"commit":"1111111111111111111111111111111111111111","hash":"sha256-newsrc"}' ;;
esac
STUB
  cat >tools/deps-hash.sh <<'STUB'
#!/usr/bin/env bash
echo "deps-hash $*" >>"$BATS_TEST_TMPDIR/tools.log"
case "${3:-pnpmDeps}" in
pnpmDeps) echo "sha256-newdeps" ;;
mobilePnpmDeps) echo "sha256-newmobile" ;;
esac
STUB
  cat >tools/template-hash.sh <<'STUB'
#!/usr/bin/env bash
echo "template-hash $*" >>"$BATS_TEST_TMPDIR/tools.log"
echo "sha256-template-$2"
STUB
  cat >tools/manifest.sh <<'STUB'
#!/usr/bin/env bash
echo "manifest $*" >>"$BATS_TEST_TMPDIR/tools.log"
[ "$3" = "${STUB_MISSING:-}" ] && { echo "manifest: $2 at $1 lists no $3 (D12)" >&2; exit 1; }
hash=sha512-new-$3
if [ "$1" = v1.4.230 ]; then
  hash=$(jq -r --arg a "$3" '[.linux[], .darwin[] | objects | .[] | select(.name == $a) | .hash][0]' "$BATS_TEST_TMPDIR/sources.json")
  [ "$3" = "${STUB_CHANGED:-}" ] && hash=sha512-swapped
fi
jq -n --arg n "$3" --arg h "$hash" '{name: $n, size: 7, hash: $h}'
STUB
  chmod +x tools/*
  export BUMP_TOOLS="$BATS_TEST_TMPDIR/tools" SOURCES="$BATS_TEST_TMPDIR/sources.json"
  cp sources.json before.json
}

@test "the pinned version is still the latest: exit 3, nothing written" {
  run --separate-stderr "$bump"
  [ "$status" -eq 3 ]
  cmp sources.json before.json
}

@test "a moved upstream tag stops the bump: exit 4, nothing written" {
  export STUB_PINNED_COMMIT=2222222222222222222222222222222222222222 STUB_LATEST=v1.4.232
  run --separate-stderr "$bump"
  [ "$status" -eq 4 ]
  [ "$stderr" = "bump: v1.4.230 now points at 2222222222222222222222222222222222222222, pinned b2879bd5aaac5d27c101ccf4171faa25d9f0bb1e; upstream moved a released tag (round 9)" ]
  cmp sources.json before.json
}

@test "a pinned asset whose hash changed stops the bump: exit 4" {
  export STUB_CHANGED=Orca-1.4.230-mac.zip STUB_LATEST=v1.4.232
  run --separate-stderr "$bump"
  [ "$status" -eq 4 ]
  [ "$stderr" = "bump: Orca-1.4.230-mac.zip changed under v1.4.230; upstream replaced a released asset (round 9)" ]
  cmp sources.json before.json
}

@test "a new version rewrites nix/sources.json, keeping the team pin" {
  export STUB_LATEST=v1.4.232
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  [ "$(jq -r .version sources.json)" = "1.4.232" ]
  [ "$(jq -r .tag sources.json)" = "v1.4.232" ]
  [ "$(jq -r .commit sources.json)" = "1111111111111111111111111111111111111111" ]
  [ "$(jq -r .src.hash sources.json)" = "sha256-newsrc" ]
  [ "$(jq -r .pnpmDeps.hash sources.json)" = "sha256-newdeps" ]
  [ "$(jq -r '.linux."x86_64-linux".deb.name' sources.json)" = "orca-ide_1.4.232_amd64.deb" ]
  [ "$(jq -r '.linux."aarch64-linux".deb.hash' sources.json)" = "sha512-new-orca-ide_1.4.232_arm64.deb" ]
  [ "$(jq -r '.darwin."aarch64-darwin".zip.name' sources.json)" = "Orca-1.4.232-arm64-mac.zip" ]
  [ "$(jq -r '.darwin."x86_64-darwin".zip.name' sources.json)" = "Orca-1.4.232-mac.zip" ]
  [ "$(jq -r .darwin.teamIdentifier sources.json)" = "6CX3WHS9HZ" ]
  grep -q "deps-hash v1.4.232 sha256-newsrc" tools.log
}

@test "a new version pins mobile/'s deps and each system's template piece" {
  export STUB_LATEST=v1.4.232
  run --separate-stderr "$bump"
  [ "$status" -eq 0 ]
  [ "$(jq -r .mobilePnpmDeps.hash sources.json)" = "sha256-newmobile" ]
  [ "$(jq -r '.linux."x86_64-linux".orcadTemplate.hash' sources.json)" = "sha256-template-x86_64-linux" ]
  [ "$(jq -r '.linux."aarch64-linux".orcadTemplate.hash' sources.json)" = "sha256-template-aarch64-linux" ]
  grep -qxF "deps-hash v1.4.232 sha256-newsrc mobilePnpmDeps" tools.log
  grep -qxF "template-hash v1.4.232 x86_64-linux orca-ide_1.4.232_amd64.deb sha512-new-orca-ide_1.4.232_amd64.deb" tools.log
  grep -qxF "template-hash v1.4.232 aarch64-linux orca-ide_1.4.232_arm64.deb sha512-new-orca-ide_1.4.232_arm64.deb" tools.log
}

@test "a pin that carries piece hashes still checks only its released assets" {
  jq '.linux[].orcadTemplate = {hash: "sha256-template"}' before.json >sources.json
  run --separate-stderr "$bump"
  [ "$status" -eq 3 ]
  run ! grep -q "manifest v1.4.230 .* null" tools.log
}

@test "an asset missing from the new manifest leaves nix/sources.json alone" {
  export STUB_LATEST=v1.4.232 STUB_MISSING=Orca-1.4.232-mac.zip
  run --separate-stderr "$bump"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"lists no Orca-1.4.232-mac.zip"* ]]
  cmp sources.json before.json
}
