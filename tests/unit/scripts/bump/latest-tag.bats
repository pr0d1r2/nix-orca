#!/usr/bin/env bats
# scripts/bump/latest-tag.sh (scripts V2, D7): the newest stable upstream
# release tag. gh is a stub that prints a fixture releases page.

bats_require_minimum_version 1.5.0

setup() {
  latest="$BATS_TEST_DIRNAME/../../../../scripts/bump/latest-tag.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/gh.log"
cat "$BATS_TEST_TMPDIR/releases.json"
STUB
  chmod +x stubs/gh
  export GH="$BATS_TEST_TMPDIR/stubs/gh"
}

release() {
  printf '{"tag_name":"%s","draft":%s,"prerelease":%s}' "$1" "$2" "$3"
}

@test "the highest stable version wins, whatever the page order" {
  printf '[%s,%s,%s]' "$(release v1.4.229 false false)" "$(release v1.4.231 false false)" "$(release v1.4.230 false false)" >releases.json
  run --separate-stderr "$latest"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.4.231" ]
  grep -q "repos/stablyai/orca/releases" gh.log
}

@test "release candidates, prereleases and drafts are never picked" {
  printf '[%s,%s,%s,%s]' "$(release v1.4.232-rc.1 false false)" "$(release v1.4.233 false true)" "$(release v1.4.234 true false)" "$(release v1.4.230 false false)" >releases.json
  run --separate-stderr "$latest"
  [ "$status" -eq 0 ]
  [ "$output" = "v1.4.230" ]
}

@test "versions compare as numbers, not text" {
  printf '[%s,%s]' "$(release v1.4.99 false false)" "$(release v1.4.100 false false)" >releases.json
  run --separate-stderr "$latest"
  [ "$output" = "v1.4.100" ]
}

@test "no stable release is refused" {
  printf '[%s]' "$(release v1.5.0-rc.1 false false)" >releases.json
  run --separate-stderr "$latest"
  [ "$status" -eq 1 ]
  [ "$stderr" = "latest-tag: stablyai/orca has no stable release (scripts V2)" ]
}

@test "ORCA_REPO names another repository" {
  printf '[%s]' "$(release v2.0.0 false false)" >releases.json
  ORCA_REPO=me/fork run --separate-stderr "$latest"
  [ "$output" = "v2.0.0" ]
  grep -q "repos/me/fork/releases" gh.log
}
