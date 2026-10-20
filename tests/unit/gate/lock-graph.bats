#!/usr/bin/env bats
# gate/lock-graph.sh (gate:V1, root V1): a flake.lock holds exactly one
# nixpkgs node, and every input with a nixpkgs input follows it.

bats_require_minimum_version 1.5.0

setup() {
  guard="$BATS_TEST_DIRNAME/../../../gate/lock-graph.sh"
  lock="$BATS_TEST_DIRNAME/../../../dev/flake.lock"
  cd "$BATS_TEST_TMPDIR"
}

@test "the dev shell's lock passes, quietly" {
  run --separate-stderr "$guard" "$lock"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "a second nixpkgs, locked by an input of its own, is refused twice over" {
  jq '.nodes.nixpkgs_2 = .nodes.nixpkgs | .nodes.sherd.inputs.nixpkgs = "nixpkgs_2"' "$lock" >flake.lock
  run --separate-stderr "$guard" flake.lock
  [ "$status" -eq 1 ]
  [ "${stderr_lines[0]}" = "lock-graph: flake.lock: 2 nixpkgs nodes, want 1: nixpkgs, nixpkgs_2 (root V1)" ]
  [ "${stderr_lines[1]}" = "lock-graph: flake.lock: sherd locks its own nixpkgs (node nixpkgs_2); make it follow (root V1)" ]
  [ "${#stderr_lines[@]}" -eq 2 ]
}

@test "no nixpkgs at all is refused" {
  jq 'del(.nodes.nixpkgs)' "$lock" >flake.lock
  run --separate-stderr "$guard" flake.lock
  [ "$status" -eq 1 ]
  [[ "${stderr_lines[0]}" == "lock-graph: flake.lock: 0 nixpkgs nodes, want 1:"* ]]
}

@test "a file that is no lock is refused" {
  printf 'not json\n' >flake.lock
  run --separate-stderr "$guard" flake.lock
  [ "$status" -eq 1 ]
  [ "$stderr" = "lock-graph: flake.lock: not a flake lock (root V1)" ]
}

@test "anything but one file is a usage error, exit 2" {
  run --separate-stderr "$guard"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: lock-graph.sh FLAKE-LOCK" ]
}
