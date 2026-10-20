#!/usr/bin/env bats
# scripts/bump/source.sh (scripts T1, round 9): the commit an upstream tag
# points at, annotated tags dereferenced, and the source hash nix fetches
# for it. gh and nix are stubs.

bats_require_minimum_version 1.5.0

setup() {
  source_sh="$BATS_TEST_DIRNAME/../../../../scripts/bump/source.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
case "$2" in
*/git/ref/tags/v1.4.230) echo '{"object":{"type":"tag","sha":"aaaa"}}' ;;
*/git/tags/aaaa) echo '{"object":{"type":"commit","sha":"c0ffee"}}' ;;
*/git/ref/tags/v9.9.9) echo '{"object":{"type":"commit","sha":"beef"}}' ;;
*) exit 1 ;;
esac
STUB
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
echo '{"hash":"sha256-up9LF/UQd2LAf/Jd40TO9dEYScKM9HK0vB6qTUf5XRw=","locked":{}}'
STUB
  chmod +x stubs/*
  export GH="$BATS_TEST_TMPDIR/stubs/gh" NIX="$BATS_TEST_TMPDIR/stubs/nix"
}

@test "an annotated tag resolves to its commit, with the source hash" {
  run --separate-stderr "$source_sh" v1.4.230
  [ "$status" -eq 0 ]
  [ "$(jq -r .commit <<<"$output")" = "c0ffee" ]
  [ "$(jq -r .hash <<<"$output")" = "sha256-up9LF/UQd2LAf/Jd40TO9dEYScKM9HK0vB6qTUf5XRw=" ]
  grep -q "flake prefetch --json github:stablyai/orca/v1.4.230" nix.log
}

@test "a lightweight tag is its commit" {
  run --separate-stderr "$source_sh" v9.9.9
  [ "$status" -eq 0 ]
  [ "$(jq -r .commit <<<"$output")" = "beef" ]
}

@test "a tag that does not exist is refused" {
  run --separate-stderr "$source_sh" v0.0.1
  [ "$status" -eq 1 ]
  [ "$stderr" = "source: stablyai/orca has no tag v0.0.1" ]
}

@test "anything but one tag is a usage error, exit 2" {
  run --separate-stderr "$source_sh"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: source.sh TAG" ]
}
