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
      throw "orca-ide: the Linux package lands with nix/linux T2";
in
{
  inherit orca-ide;
  orca-ide-agents = orca-ide.override { agents = builtins.attrValues agents; };
}
