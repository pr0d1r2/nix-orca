# checks.<linux> (nix/linux §I): each runs scripts/check/linux-app.sh in one
# mode against the built package or its source.
{
  lib,
  runCommand,
  jq,
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
}
