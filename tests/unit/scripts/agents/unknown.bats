#!/usr/bin/env bats
# scripts/agents/unknown.sh (nix/agents V5, round 11): Orca agent ids that
# are neither packaged nor on the no-package list, one per line.

bats_require_minimum_version 1.5.0

setup() {
  unknown="$BATS_TEST_DIRNAME/../../../../scripts/agents/unknown.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  printf 'claude claude\ncursor cursor-agent\nkilo kilo\nnewbie newbie-cli\nclaude-agent-teams orca\n' >ids
  printf '# comment\nkilo\n\n' >no-package
}

@test "an id neither packaged nor listed is reported" {
  run --separate-stderr "$unknown" ids no-package claude cursor
  [ "$status" -eq 0 ]
  [ "$output" = "newbie" ]
}

@test "Orca's own claude-agent-teams is never reported" {
  run --separate-stderr "$unknown" ids no-package claude cursor newbie
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "too few arguments is a usage error, exit 2" {
  run --separate-stderr "$unknown" ids
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: unknown.sh IDS-FILE NO-PACKAGE-FILE PACKAGED-ID..." ]
}
