# The orcad deployment template (nix/bin T2, D33, D38): upstream's own
# `resources/orcad-template`, cut from this system's `.deb` as a fixed-output
# path. Byte for byte upstream's (V1): nothing patched, stripped or signed,
# so Orca's sha256 manifest inside it still holds. Unchanged between
# releases, it keeps its store path (V2); amd64 and arm64 cut the same tree.
{
  stdenvNoCC,
  fetchurl,
  dpkg,
  sources,
  # Not `system`: callPackage would fill that from pkgs' deprecated alias.
  debSystem ? stdenvNoCC.hostPlatform.system,
}:
let
  linux = sources.linux.${debSystem};
in
stdenvNoCC.mkDerivation {
  pname = "orcad-template";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/${sources.tag}/${linux.deb.name}";
    inherit (linux.deb) hash;
  };

  nativeBuildInputs = [ dpkg ];
  env.ORCA_PIECE = "opt/Orca/resources/orcad-template";

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ". ${../../scripts/build/deb-piece.sh}";
  dontFixup = true;

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = linux.orcadTemplate.hash;
}
