#!/usr/bin/env bats
# scripts/build/template-ripgrep.sh (nix/linux §C, root T18): the orcad
# template manifest with the Linux rg hashes rewritten to the pin's
# builds, every other entry as it was.

bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/template-ripgrep.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  echo x64 >rg-x64
  echo arm64 >rg-arm64
  cat >manifest.json <<'EOF'
{
  "schemaVersion": 4,
  "commonSha256": {"orcad.js": "c0"},
  "targets": {
    "darwin-arm64": {"files": {"ripgrep/darwin-arm64/rg": "d0", "orcad.js": "c0"}},
    "linux-x64-glibc": {"files": {"ripgrep/linux-x64/rg": "old-x64", ".server-target": "s1"}, "packagedRipgrep": true},
    "linux-x64-musl": {"files": {"ripgrep/linux-x64/rg": "old-x64"}, "packagedRipgrep": true},
    "linux-arm64-glibc": {"files": {"ripgrep/linux-arm64/rg": "old-arm64"}, "packagedRipgrep": true},
    "win32-x64": {"files": {"ripgrep/win32-x64/rg.exe": "w0"}, "packagedRipgrep": true}
  }
}
EOF
  x64=$(sha256sum <rg-x64 | cut -d' ' -f1)
  arm64=$(sha256sum <rg-arm64 | cut -d' ' -f1)
}

@test "every Linux target's rg hash is the given binary's" {
  run --separate-stderr "$script" manifest.json rg-x64 rg-arm64
  [ "$status" -eq 0 ]
  [ "$(jq -r '.targets["linux-x64-glibc"].files["ripgrep/linux-x64/rg"]' <<<"$output")" = "$x64" ]
  [ "$(jq -r '.targets["linux-x64-musl"].files["ripgrep/linux-x64/rg"]' <<<"$output")" = "$x64" ]
  [ "$(jq -r '.targets["linux-arm64-glibc"].files["ripgrep/linux-arm64/rg"]' <<<"$output")" = "$arm64" ]
}

@test "darwin, win32 and every other entry stay as they were" {
  run --separate-stderr "$script" manifest.json rg-x64 rg-arm64
  [ "$status" -eq 0 ]
  strip='del(.targets[].files["ripgrep/linux-x64/rg"], .targets[].files["ripgrep/linux-arm64/rg"])'
  [ "$(jq -S "$strip" <<<"$output")" = "$(jq -S "$strip" manifest.json)" ]
}

@test "a manifest without a Linux rg entry fails: upstream changed its layout" {
  jq 'del(.targets["linux-arm64-glibc"])' manifest.json >m2.json
  run --separate-stderr "$script" m2.json rg-x64 rg-arm64
  [ "$status" -eq 1 ]
  [ "$stderr" = "template-ripgrep: m2.json names no ripgrep/linux-arm64/rg" ]
}

@test "a missing binary fails" {
  run --separate-stderr "$script" manifest.json rg-x64 nope
  [ "$status" -eq 1 ]
  [ "$stderr" = "template-ripgrep: no file nope" ]
}

@test "anything but three arguments is a usage error, exit 2" {
  run --separate-stderr "$script" manifest.json
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: template-ripgrep.sh MANIFEST RG-LINUX-X64 RG-LINUX-ARM64" ]
}
