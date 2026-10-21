# The orcad template piece of SYSTEM's .deb at TAG with a fake hash
# (scripts/bump/template-hash.sh): building it fails with a hash mismatch
# whose `got:` is the real hash. The piece is cut on the host's system;
# the .deb it cuts is SYSTEM's.
{
  tag,
  system,
  debName,
  debHash,
  root ? ../..,
}:
let
  flake = builtins.getFlake (toString root);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
pkgs.callPackage (root + "/nix/bin/orcad-template.nix") {
  debSystem = system;
  sources = {
    inherit tag;
    version = pkgs.lib.removePrefix "v" tag;
    linux.${system} = {
      deb = {
        name = debName;
        hash = debHash;
      };
      orcadTemplate.hash = pkgs.lib.fakeHash;
    };
  };
}
