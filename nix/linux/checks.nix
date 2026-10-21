# checks.<linux> (nix/linux §I): each runs scripts/check/linux-app.sh in one
# mode against the built package or its source.
{
  lib,
  runCommand,
  closureInfo,
  jq,
  patchelf,
  agent-browser,
  sherpa-onnx,
  orca-ide,
  sources,
}:
let
  checkWith =
    env: mode: path: want:
    runCommand "orca-ide-${mode}" {
      nativeBuildInputs = [
        jq
        patchelf
      ];
      env = {
        ELECTRON_MAJOR_CHECK = "${../../scripts/check/electron-major.sh}";
      }
      // env;
    } "bash ${../../scripts/check/linux-app.sh} ${mode} ${path} ${lib.escapeShellArg want}";
  check = checkWith { };
in
{
  orca-ide-version = check "version" orca-ide sources.version;
  electron-major = check "electron-major" orca-ide.src orca-ide.electron.version;
  sherpa-load = check "sherpa-load" orca-ide sherpa-onnx.version;
  ripgrep = check "ripgrep" orca-ide "-";
  agent-browser = check "agent-browser" orca-ide agent-browser.version;
  runtime-commands = check "runtime-commands" orca-ide "git ps xdg-open xclip xdotool Xvfb wl-copy";
  # The size is closureInfo's total-nar-size: no nix daemon in a check.
  closure-budget = runCommand "orca-ide-closure-budget" {
    env = {
      CLOSURE_SIZE_FILE = "${closureInfo { rootPaths = [ orca-ide ]; }}/total-nar-size";
      CLOSURE_BUDGET = "${../../.closure-budget}";
    };
  } "bash ${../../scripts/closure-budget.sh} ${orca-ide.stdenv.hostPlatform.system} ${orca-ide}";
  closure-hygiene = checkWith {
    ORCA_CLOSURE = "${closureInfo { rootPaths = [ orca-ide ]; }}/store-paths";
  } "hygiene" orca-ide "${./closure-allow.txt}";
  updater-off = check "updater-off" (orca-ide.override { updater = false; }) "-";
}
