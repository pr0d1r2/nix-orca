#!/usr/bin/env bats
# scripts/ci/release-tag.sh (`release` §C rounds 7 and 8, root V4): the tag
# a release run publishes, or none. git is a stub listing tags.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  tag="$BATS_TEST_DIRNAME/../../../../scripts/ci/release-tag.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  printf '{"version":"1.4.232"}\n' >sources.json
  cat >stubs/git <<'STUB'
#!/usr/bin/env bash
printf '%s\n' ${STUB_TAGS:-}
STUB
  chmod +x stubs/git
  export GIT="$PWD/stubs/git" SOURCES="$PWD/sources.json"
}

@test "a merge with a new upstream version releases -nix.1" {
  export STUB_TAGS="v1.4.230-nix.1 v1.4.230-nix.2"
  run --separate-stderr "$tag" push
  [ "$status" -eq 0 ]
  [ "$output" = "v1.4.232-nix.1" ]
}

@test "a merge that keeps the version finds its tag and releases nothing" {
  export STUB_TAGS="v1.4.232-nix.1"
  run --separate-stderr "$tag" push
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "an owner dispatch releases the next packaging fix" {
  export STUB_TAGS="v1.4.232-nix.1 v1.4.232-nix.2 v1.4.230-nix.9"
  run --separate-stderr "$tag" workflow_dispatch
  [ "$status" -eq 0 ]
  [ "$output" = "v1.4.232-nix.3" ]
}

@test "a dispatch before any release of the version still starts at -nix.1" {
  run --separate-stderr "$tag" workflow_dispatch
  [ "$output" = "v1.4.232-nix.1" ]
}

@test "packaging fix numbers compare as numbers" {
  export STUB_TAGS="v1.4.232-nix.9 v1.4.232-nix.10"
  run --separate-stderr "$tag" workflow_dispatch
  [ "$output" = "v1.4.232-nix.11" ]
}

@test "any other event is a usage error, exit 2" {
  run --separate-stderr "$tag" schedule
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: release-tag.sh push|workflow_dispatch" ]
}
