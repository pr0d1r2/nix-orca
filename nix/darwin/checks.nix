# checks.<darwin> (nix/darwin §I): each runs scripts/check/darwin-app.sh in
# one mode against the store Orca.app. They call /usr/bin/codesign, lipo and
# /usr/libexec/PlistBuddy, which darwin's default `sandbox = false` allows;
# `__impureHostDeps` would need the host's nix.conf to allow them.
{
  lib,
  runCommand,
  diffutils,
  unzip,
  orca-ide,
  sources,
}:
let
  app = "${orca-ide}/Applications/Orca.app";
  arch =
    {
      aarch64-darwin = "arm64";
      x86_64-darwin = "x86_64";
    }
    .${orca-ide.stdenv.hostPlatform.system};
  check =
    mode: want:
    runCommand "orca-ide-${mode}" {
      nativeBuildInputs = [
        diffutils
        unzip
      ];
    } "bash ${../../scripts/check/darwin-app.sh} ${mode} ${app} ${lib.escapeShellArg want}";
in
{
  codesign = check "codesign" sources.darwin.teamIdentifier;
  arch = check "arch" arch;
  orca-ide-version = check "version" sources.version;
  tree = check "tree" "${orca-ide.src}";
}
