# checks.<system> for the agent set (nix/agents §I): every agent ships the
# command Orca looks for, read from the pinned tag's agent table (V1), and
# answers --version (V3).
{
  lib,
  runCommand,
  src,
  agents,
}:
let
  ids =
    runCommand "orca-agent-ids" { }
      "bash ${../../scripts/agents}/tui-ids.sh ${src}/src/shared/tui-agent-config.ts > $out";
  pairs = lib.mapAttrsToList (id: drv: lib.escapeShellArg "${id}=${drv}") agents;
  commands = lib.mapAttrsToList (id: drv: lib.escapeShellArg "${id}=${lib.getExe drv}") agents;
in
{
  # Offline on Linux, where the nix sandbox holds; darwin's default
  # `sandbox = false` cannot prove it (V3).
  agents-version =
    runCommand "orca-agents-version" { }
      "bash ${../../scripts/agents}/versions.sh ${toString commands}";
  agents-commands =
    runCommand "orca-agents-commands" { }
      "bash ${../../scripts/agents}/commands.sh ${ids} ${toString pairs}";
}
