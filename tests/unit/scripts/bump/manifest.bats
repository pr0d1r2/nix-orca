#!/usr/bin/env bats
# scripts/bump/manifest.sh (scripts T1, D12): one release asset's entry in
# upstream's latest-*.yml, as nix/sources.json wants it, checked against the
# size GitHub reports. curl and gh are stubs over fixtures.

bats_require_minimum_version 1.5.0

setup() {
  manifest="$BATS_TEST_DIRNAME/../../../../scripts/bump/manifest.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >latest-mac.yml <<'YML'
version: 1.4.230
files:
  - url: Orca-1.4.230-mac.zip
    sha512: yM0kG6TfKsfVUH/ZxRyacMlu9EKwYFmy/UTbnXWG1QhVwZlX5AS1/O/zJLI978gk62/q/ykPugwQY/ORfFtcZw==
    size: 314602541
  - url: Orca-1.4.230-arm64-mac.zip
    sha512: MSuK78MnWwZwHQUwhqu81FdPWOLAzHJT8U36OsnTi8I+4BEvVk3wiu94HVwJ36y46XrUWoApHAfJp1S6oLvhTw==
    size: 305374137
path: Orca-1.4.230-mac.zip
sha512: yM0kG6TfKsfVUH/ZxRyacMlu9EKwYFmy/UTbnXWG1QhVwZlX5AS1/O/zJLI978gk62/q/ykPugwQY/ORfFtcZw==
YML
  printf '{"assets":[{"name":"Orca-1.4.230-arm64-mac.zip","size":305374137},{"name":"Orca-1.4.230-mac.zip","size":1}]}' >release.json
  cat >stubs/curl <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/curl.log"
cat "$BATS_TEST_TMPDIR/latest-mac.yml"
STUB
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
cat "$BATS_TEST_TMPDIR/release.json"
STUB
  chmod +x stubs/*
  export CURL="$BATS_TEST_TMPDIR/stubs/curl" GH="$BATS_TEST_TMPDIR/stubs/gh"
}

@test "an asset's entry, as nix/sources.json holds it" {
  run --separate-stderr "$manifest" v1.4.230 latest-mac.yml Orca-1.4.230-arm64-mac.zip
  [ "$status" -eq 0 ]
  [ "$(jq -r .name <<<"$output")" = "Orca-1.4.230-arm64-mac.zip" ]
  [ "$(jq -r .size <<<"$output")" = "305374137" ]
  [ "$(jq -r .hash <<<"$output")" = "sha512-MSuK78MnWwZwHQUwhqu81FdPWOLAzHJT8U36OsnTi8I+4BEvVk3wiu94HVwJ36y46XrUWoApHAfJp1S6oLvhTw==" ]
  grep -q "releases/download/v1.4.230/latest-mac.yml" curl.log
}

@test "an asset the manifest does not list is refused" {
  run --separate-stderr "$manifest" v1.4.230 latest-mac.yml Orca-1.4.230-universal-mac.zip
  [ "$status" -eq 1 ]
  [ "$stderr" = "manifest: latest-mac.yml at v1.4.230 lists no Orca-1.4.230-universal-mac.zip (D12)" ]
}

@test "a size that differs from GitHub's is refused" {
  run --separate-stderr "$manifest" v1.4.230 latest-mac.yml Orca-1.4.230-mac.zip
  [ "$status" -eq 1 ]
  [ "$stderr" = "manifest: Orca-1.4.230-mac.zip: latest-mac.yml says 314602541 bytes, GitHub says 1 (D12)" ]
}

@test "anything but three arguments is a usage error, exit 2" {
  run --separate-stderr "$manifest" v1.4.230
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: manifest.sh TAG MANIFEST ASSET" ]
}
