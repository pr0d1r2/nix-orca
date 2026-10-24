# checks.x86_64-linux.module-agents (nix/agents §I, root T18): evaluating a
# NixOS system with the module, `agents.opencode.enable` puts opencode on
# Orca's PATH, and `agents.openclaw.enable` without permitting insecure
# packages leaves it out with a warning. Evaluation only, no VM.
{
  lib,
  writeText,
  nixosSystem,
  module,
}:
let
  system = nixosSystem {
    system = "x86_64-linux";
    modules = [
      module
      {
        programs.orca-ide = {
          enable = true;
          agents.opencode.enable = true;
          agents.openclaw.enable = true;
        };
        boot.isContainer = true;
        system.stateVersion = "26.05";
      }
    ];
  };
  inherit (system) config;
  orca = lib.findFirst (
    p: (p.pname or "") == "orca-ide"
  ) (throw "no orca-ide in systemPackages") config.environment.systemPackages;
  warned = builtins.filter (w: lib.hasPrefix "programs.orca-ide.agents." w) config.warnings;
in
assert lib.assertMsg (lib.hasInfix "opencode" orca.ORCA_PATH)
  "agents.opencode.enable: opencode not on Orca's PATH (${orca.ORCA_PATH})";
assert lib.assertMsg (
  !(lib.hasInfix "openclaw" orca.ORCA_PATH)
) "agents.openclaw.enable without permittedInsecurePackages: openclaw on Orca's PATH";
assert lib.assertMsg (
  map (w: builtins.head (lib.splitString ":" w)) warned == [ "programs.orca-ide.agents.openclaw" ]
) "want one warning, for openclaw; got: ${toString warned}";
writeText "orca-ide-module-agents" orca.ORCA_PATH
