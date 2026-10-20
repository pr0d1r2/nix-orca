#!/usr/bin/env bats
# scripts/ci/release-files.sh (`release` T1, root §I release): the notes and
# SBOMs for the systems linked in a release directory. release-notes.sh
# and sbom.sh are stubs in RELEASE_TOOLS.

bats_require_minimum_version 1.5.0

setup() {
  files="$BATS_TEST_DIRNAME/../../../../scripts/ci/release-files.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p tools release store/x-orca-ide store/a-orca-ide
  ln -s "$PWD/store/x-orca-ide" release/x86_64-linux
  ln -s "$PWD/store/a-orca-ide" release/aarch64-linux
  cat >tools/release-notes.sh <<'STUB'
#!/usr/bin/env bash
echo "notes $*"
STUB
  cat >tools/sbom.sh <<'STUB'
#!/usr/bin/env bash
echo "sbom $*" >>"$BATS_TEST_TMPDIR/calls"
STUB
  chmod +x tools/*
  export RELEASE_TOOLS="$PWD/tools"
}

@test "notes cover every linked system, one SBOM pair each" {
  run --separate-stderr "$files" release
  [ "$status" -eq 0 ]
  [ "$(cat release/notes.md)" = "notes aarch64-linux=$PWD/store/a-orca-ide x86_64-linux=$PWD/store/x-orca-ide" ]
  grep -qxF "sbom aarch64-linux $PWD/store/a-orca-ide release" calls
  grep -qxF "sbom x86_64-linux $PWD/store/x-orca-ide release" calls
}

@test "a directory with no system links is refused" {
  mkdir empty
  run --separate-stderr "$files" empty
  [ "$status" -eq 1 ]
  [ "$stderr" = "release-files: empty links no system's orca-ide" ]
}

@test "anything but one directory is a usage error, exit 2" {
  run --separate-stderr "$files"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: release-files.sh DIR" ]
}
