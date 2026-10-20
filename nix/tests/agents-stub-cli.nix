# checks.<system>.agents-stub-cli (tests T4, D44 layer 2, without Orca):
# every agent with a recipe in tests/stub/runs.json that exists on the
# system runs against the stub model server and writes its file. In the
# Linux sandbox this proves it needs no network and no account (tests V2).
{
  lib,
  stdenv,
  runCommand,
  python3,
  agents,
}:
let
  tests = lib.fileset.toSource {
    root = ../..;
    fileset = ../../tests;
  };
  recipes = builtins.attrNames (lib.importJSON ../../tests/stub/runs.json);
  # codex 0.163.0 reads macOS managed preferences (MDM) at start and stops,
  # "Failed to synchronize managed preferences", when the darwin build user
  # cannot: it passes the same run outside a nix build. Linux runs it.
  skip = lib.optionals stdenv.hostPlatform.isDarwin [ "codex" ];
  present = builtins.filter (id: agents ? ${id} && !builtins.elem id skip) recipes;
in
runCommand "orca-agents-stub-cli"
  {
    nativeBuildInputs = [ python3 ] ++ map (id: agents.${id}) present;
  }
  "cd ${tests} && python3 -m tests.stub.run ${lib.escapeShellArgs present} --timeout 180 && touch $out"
