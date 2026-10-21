# orca-ide on Linux (nix/linux T2): built from the upstream tag with the
# pin's Node, pnpm and Electron. The phases are scripts in scripts/build/.
{
  lib,
  stdenv,
  callPackage,
  bash,
  pnpm,
  pnpmConfigHook,
  nodejs_24,
  node-gyp,
  python3,
  jq,
  electron_43,
  wayland,
  agent-browser,
  sherpa-onnx,
  patchelf,
  wrapGAppsHook3,
  makeWrapper,
  writableTmpDirAsHomeHook,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  sources,
  agents ? [ ],
}:
let
  electron = electron_43;
  upstream = callPackage ./sources.nix { inherit sources; };
  orcadTemplate = callPackage ../bin/orcad-template.nix { inherit sources; };
in
stdenv.mkDerivation {
  pname = "orca-ide";
  inherit (sources) version;
  inherit (upstream) src pnpmDeps mobilePnpmDeps;

  nativeBuildInputs = [
    pnpm
    pnpmConfigHook
    nodejs_24
    node-gyp
    python3
    jq
    patchelf
    wrapGAppsHook3
    makeWrapper
    writableTmpDirAsHomeHook
  ];
  # bash: the launcher's interpreter; under strictDeps patchShebangs looks
  # for it here. wayland: the clipboard helper's header. The rest: the GApps
  # environment the pin's electron wrapper sets, without gtk4: Electron runs
  # GTK 3 unless told `--gtk-version=4`, and gtk4's schemas cost 1 GB of
  # closure.
  buildInputs = [
    bash
    wayland
    gsettings-desktop-schemas
    glib
    gtk3
  ];
  dontWrapGApps = true;
  strictDeps = true;
  # Fixup would shrink Electron's RUNPATH, dropping the libraries it dlopens
  # (libglvnd, vulkan, pipewire, pulseaudio, libsecret, libnotify), and point
  # every script at the store's Node, the WSL relays included. The install
  # script patches the one shebang that runs here.
  dontPatchELF = true;
  dontStrip = true;
  dontPatchShebangs = true;

  env = {
    ORCA_COMMIT = sources.commit;
    ORCA_ARCH = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
    ORCA_TEMPLATE = orcadTemplate;
    ORCA_PNPM_GLOBAL_VIRTUAL_STORE = "0";
    pnpm_config_verify_deps_before_run = "false";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    ELECTRON_DIST = electron.dist;
    ELECTRON_HEADERS = electron.headers;
    ELECTRON_VERSION = electron.version;
    ELECTRON_MAJOR_CHECK = "${../../scripts/check/electron-major.sh}";
    ORCA_PATH = lib.makeBinPath agents;
    ORCA_HELPER_RPATH = lib.makeLibraryPath [
      wayland
      gtk3
    ];
    ORCA_AGENT_BROWSER = lib.getExe agent-browser;
    ORCA_AGENT_BROWSER_VERSION = agent-browser.version;
    ORCA_SHERPA_RPATH = lib.makeLibraryPath [
      sherpa-onnx
      stdenv.cc.cc.lib
    ];
  };

  postPatch = ". ${../../scripts/build/linux-patch.sh}";
  buildPhase = ". ${../../scripts/build/linux-build.sh}";
  installPhase = ". ${../../scripts/build/linux-install.sh}";

  passthru = { inherit electron orcadTemplate; };

  meta = {
    description = "Orca, an IDE that runs a fleet of coding agents (built from source)";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "orca-ide";
  };
}
