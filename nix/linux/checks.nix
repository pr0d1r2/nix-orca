# checks.<linux> (nix/linux §I): each runs scripts/check/linux-app.sh in one
# mode against the built package or its source.
{
  lib,
  runCommand,
  jq,
  agent-browser,
  sherpa-onnx,
  orca-ide,
  sources,
}:
let
  check =
    mode: path: want:
    runCommand "orca-ide-${mode}" {
      nativeBuildInputs = [ jq ];
      env.ELECTRON_MAJOR_CHECK = "${../../scripts/check/electron-major.sh}";
    } "bash ${../../scripts/check/linux-app.sh} ${mode} ${path} ${lib.escapeShellArg want}";
in
{
  orca-ide-version = check "version" orca-ide sources.version;
  electron-major = check "electron-major" orca-ide.src orca-ide.electron.version;
  sherpa-load = check "sherpa-load" orca-ide sherpa-onnx.version;
  ripgrep = check "ripgrep" orca-ide "-";
  agent-browser = check "agent-browser" orca-ide agent-browser.version;
  runtime-commands = check "runtime-commands" orca-ide "git ps xdg-open xclip xdotool Xvfb wl-copy";
  updater-off = check "updater-off" (orca-ide.override { updater = false; }) "-";
}
