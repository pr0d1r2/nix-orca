#!/usr/bin/env bats
# scripts/bump/lock-diff.sh (scripts §C round 9): the bump PR body's
# dependency report, npm packages added, removed and version-changed
# between two pnpm-lock.yaml files, and install scripts newly allowed in
# pnpm-workspace.yaml. Report-only.

bats_require_minimum_version 1.5.0

setup() {
  diff="$BATS_TEST_DIRNAME/../../../../scripts/bump/lock-diff.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  cat >old-lock.yaml <<'YML'
lockfileVersion: '9.0'

packages:

  left-pad@1.0.0:
    resolution: {integrity: sha512-x}

  '@scope/kept@2.0.0':
    resolution: {integrity: sha512-x}

  gone@0.1.0:
    resolution: {integrity: sha512-x}

snapshots:

  left-pad@1.0.0: {}
YML
  cat >new-lock.yaml <<'YML'
lockfileVersion: '9.0'

importers:
  .:
    dependencies: {}

packages:

  left-pad@1.1.0:
    resolution: {integrity: sha512-y}

  '@scope/kept@2.0.0':
    resolution: {integrity: sha512-x}

  fresh@3.0.0:
    resolution: {integrity: sha512-z}

snapshots:

  fresh@3.0.0: {}
YML
  printf 'packages:\n  - src\nallowBuilds:\n  esbuild: true\n  ssh2: false\n  msw: false\n' >old-ws.yaml
  printf 'packages:\n  - src\nallowBuilds:\n  esbuild: true\n  ssh2: true\n  msw: false\n  newthing: true\n  quiet: false\n' >new-ws.yaml
}

@test "added, removed and changed packages, and newly allowed install scripts" {
  run --separate-stderr "$diff" old-lock.yaml new-lock.yaml old-ws.yaml new-ws.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"- added: \`fresh@3.0.0\`"* ]]
  [[ "$output" == *"- removed: \`gone@0.1.0\`"* ]]
  [[ "$output" == *"- changed: \`left-pad\` 1.0.0 -> 1.1.0"* ]]
  [[ "$output" == *"- install scripts newly allowed: \`newthing\`, \`ssh2\`"* ]]
  [[ "$output" != *"@scope/kept"* ]]
  [[ "$output" != *"quiet"* ]]
}

@test "identical inputs report no change" {
  run --separate-stderr "$diff" old-lock.yaml old-lock.yaml old-ws.yaml old-ws.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"No npm package changed."* ]]
  [[ "$output" == *"No install script newly allowed."* ]]
}

@test "anything but four files is a usage error, exit 2" {
  run --separate-stderr "$diff" old-lock.yaml
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: lock-diff.sh OLD-LOCK NEW-LOCK OLD-WORKSPACE NEW-WORKSPACE" ]
}
