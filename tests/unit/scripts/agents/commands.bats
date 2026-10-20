#!/usr/bin/env bats
# scripts/agents/commands.sh (nix/agents V1): every packaged agent puts
# Orca's detect command, or one of its aliases, in its bin/.

bats_require_minimum_version 1.5.0

setup() {
  commands="$BATS_TEST_DIRNAME/../../../../scripts/agents/commands.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  printf 'cursor cursor-agent\ncodebuddy codebuddy cbc\nclaude claude\n' >ids
  mkdir -p cursor/bin codebuddy/bin claude/bin
  touch cursor/bin/cursor-agent codebuddy/bin/cbc claude/bin/claude-code
  export out="$BATS_TEST_TMPDIR/out"
}

@test "each agent's bin/ holds its detect command or an alias" {
  run --separate-stderr "$commands" ids cursor="$PWD/cursor" codebuddy="$PWD/codebuddy"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
}

@test "an agent without its command is refused, naming what Orca looks for" {
  run --separate-stderr "$commands" ids cursor="$PWD/cursor" claude="$PWD/claude"
  [ "$status" -eq 1 ]
  [ "$stderr" = "commands: claude: $PWD/claude/bin has none of: claude (nix/agents V1)" ]
  [ ! -e "$out" ]
}

@test "an id Orca does not know is refused" {
  run --separate-stderr "$commands" ids cursor-cli="$PWD/cursor"
  [ "$status" -eq 1 ]
  [ "$stderr" = "commands: cursor-cli: not an agent id in Orca's table (nix/agents V1)" ]
}

@test "no agents is a usage error, exit 2" {
  run --separate-stderr "$commands" ids
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: commands.sh IDS-FILE ID=STORE-PATH..." ]
}
