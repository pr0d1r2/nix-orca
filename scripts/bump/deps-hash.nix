# The JS deps fetch for TAG with a fake hash (scripts/bump/deps-hash.sh):
# building it fails with a hash mismatch whose `got:` is the real hash.
{
  tag,
  srcHash,
  root ? ../..,
}:
let
  flake = builtins.getFlake (toString root);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
(pkgs.callPackage (root + "/nix/linux/sources.nix") {
  sources = {
    inherit tag;
    version = pkgs.lib.removePrefix "v" tag;
    src.hash = srcHash;
    pnpmDeps.hash = pkgs.lib.fakeHash;
  };
}).pnpmDeps
