# Orca's agent table at the pinned tag, one line per agent: id, detectCmd,
# aliases (scripts/agents/tui-ids.sh). Read by the commands check (V1) and
# the new-agent watch (V5).
{ runCommand, src }:
runCommand "orca-agent-ids" { }
  "bash ${../../scripts/agents}/tui-ids.sh ${src}/src/shared/tui-agent-config.ts > $out"
