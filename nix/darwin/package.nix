# orca-ide on darwin: upstream's signed Orca.app from the release zip,
# never patched, re-signed or stripped (D38), plus bin/orca-ide (D5).
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  gitMinimal,
  sources,
  telemetry ? true,
  agents ? [ ],
}:
let
  zip = sources.darwin.${stdenvNoCC.hostPlatform.system}.zip;
in
stdenvNoCC.mkDerivation {
  pname = "orca-ide";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/${sources.tag}/${zip.name}";
    inherit (zip) hash;
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  # The zip holds Orca.app at its top; stay above it.
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Fixup would patch shebangs and strip inside the signed bundle.
  dontFixup = true;

  env = {
    # gitMinimal: 159 MB closure against git's 1.6 GB (python3 pulls the
    # apple-sdk and llvm); Orca drives plain git verbs, not perl or python ones.
    ORCA_PATH = lib.makeBinPath ([ gitMinimal ] ++ agents);
    ORCA_TELEMETRY = lib.boolToString telemetry;
  };
  installPhase = ". ${../../scripts/build/darwin-install.sh}";

  passthru = { inherit zip; };

  meta = {
    description = "Orca, an IDE that runs a fleet of coding agents (upstream's signed app)";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "orca-ide";
  };
}
