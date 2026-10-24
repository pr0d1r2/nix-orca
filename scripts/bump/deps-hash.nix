# A JS deps fetch for TAG with a fake hash (scripts/bump/deps-hash.sh):
# building it fails with a hash mismatch whose `got:` is the real hash.
# `fetch` names it: pnpmDeps (the root's) or mobilePnpmDeps (mobile/'s).
{
  tag,
  srcHash,
  fetch ? "pnpmDeps",
  root ? ../..,
}:
let
  flake = builtins.getFlake (toString root);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
(pkgs.callPackage (root + "/nix/linux/sources.nix") {
  # The package's own pnpm, so the hash is the one its build fetches.
  pnpm = pkgs.callPackage (root + "/nix/linux/pnpm.nix") { inherit (flake.inputs) nix-pnpm; };
  sources = {
    inherit tag;
    version = pkgs.lib.removePrefix "v" tag;
    src.hash = srcHash;
    pnpmDeps.hash = pkgs.lib.fakeHash;
    mobilePnpmDeps.hash = pkgs.lib.fakeHash;
  };
}).${fetch}
