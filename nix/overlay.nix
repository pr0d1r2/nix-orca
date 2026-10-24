# overlays.default (nix §I): adds exactly orca-ide and orca-ide-agents (V1)
# and touches nothing else. Built from the consumer's own package set, so
# their config decides which unfree agents exist (nix §C).
{ inputs, sources }:
final: _prev:
let
  inherit (final.stdenv.hostPlatform) system isDarwin;
  agents = import ./agents/default.nix {
    inherit (final) lib;
    pkgs = final;
    inherit inputs system;
  };
  orca-ide =
    if isDarwin then
      final.callPackage ./darwin/package.nix { inherit sources; }
    else
      final.callPackage ./linux/package.nix {
        inherit sources;
        pnpm = final.callPackage ./linux/pnpm.nix { inherit (inputs) nix-pnpm; };
      };
in
{
  inherit orca-ide;
  orca-ide-agents = orca-ide.override { agents = builtins.attrValues agents; };
}
