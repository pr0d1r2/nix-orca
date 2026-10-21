# nixosModules.orca-ide (nix/modules T1): `programs.orca-ide` puts orca-ide
# on the system PATH, with its desktop entry and icons. The default package
# is this flake's, the one CI builds and the cache holds.
{ packages }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.orca-ide;
in
{
  options.programs.orca-ide = {
    enable = lib.mkEnableOption "Orca, an IDE that runs a fleet of coding agents";
    package = lib.mkOption {
      type = lib.types.package;
      default = packages.${pkgs.stdenv.hostPlatform.system}.orca-ide;
      defaultText = lib.literalExpression "nix-orca.packages.\${system}.orca-ide";
      example = lib.literalExpression "nix-orca.packages.\${system}.orca-ide-agents";
      description = "The orca-ide package; `orca-ide-agents` brings the agent CLIs.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
