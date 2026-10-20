#!/usr/bin/env bats
# scripts/agents/tui-ids.sh (nix/agents V1, V5): every agent Orca knows,
# read from src/shared/tui-agent-config.ts, one line each: the id, the
# detect command, then its aliases.

bats_require_minimum_version 1.5.0

setup() {
  ids="$BATS_TEST_DIRNAME/../../../../scripts/agents/tui-ids.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  cat >config.ts <<'TS'
import { x } from './y'

const OTHER: Record<string, string> = {
  notAnAgent: { detectCmd: 'nope' }
}

const TUI_AGENT_CONFIG_SOURCE: Record<TuiAgent, TuiAgentConfigSource> = {
  claude: {
    detectCmd: 'claude',
    promptInjectionMode: 'argv'
  },
  'claude-agent-teams': {
    // Why: detection follows the Orca CLI.
    detectCmd: 'orca',
    detectCmdAliases: ['orca-dev', 'orca-ide'],
    launchCmd: 'orca claude-teams'
  },
  opencode2: {
    detectCmd: 'opencode2',
    launchCmd: 'opencode2 --standalone'
  },
  jcode: { detectCmd: 'jcode', launchCmd: 'jcode', expectedProcess: 'jcode' }
}

export const AFTER = { later: { detectCmd: 'never' } }
TS
}

@test "every agent in the config, in order, with its command and aliases" {
  run --separate-stderr "$ids" config.ts
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "claude claude" ]
  [ "${lines[1]}" = "claude-agent-teams orca orca-dev orca-ide" ]
  [ "${lines[2]}" = "opencode2 opencode2" ]
  [ "${lines[3]}" = "jcode jcode" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "a config with no agent table is refused" {
  printf 'export const nothing = 1\n' >empty.ts
  run --separate-stderr "$ids" empty.ts
  [ "$status" -eq 1 ]
  [ "$stderr" = "tui-ids: empty.ts: no agents in TUI_AGENT_CONFIG_SOURCE" ]
}

@test "anything but one file is a usage error, exit 2" {
  run --separate-stderr "$ids"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: tui-ids.sh TUI-AGENT-CONFIG-TS" ]
}
