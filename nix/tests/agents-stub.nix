# checks.x86_64-linux.agents-stub (tests T4, layer 2, V3): in a NixOS VM,
# Orca opens under Xvfb for an unprivileged user, adds a repository and
# launches OpenCode on it; OpenCode asks the stub model server
# (tests/stub) and its tool call writes hello.txt. No network, no key
# (V2). The display is recorded: the output holds run.mp4, its compacted
# demo.mp4, demo.mp4 as animated WebP, preview.webp, and the last frame,
# shot.png (docs/DEMO.md, scripts/demo-assets.sh). The checks are
# scripts/check/vm-orca.sh; Python only drives the VM.
{
  lib,
  testers,
  xvfb,
  jq,
  git,
  python3,
  ffmpeg-full,
  imagemagick,
  module,
  orca-ide,
  opencode,
}:
let
  vm = ../../scripts/check/vm-orca.sh;
  # tests.stub.server runs as a module from the directory holding tests/;
  # the server and its script alone, so other test edits leave it built.
  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../tests/__init__.py
      ../../tests/stub/__init__.py
      ../../tests/stub/server.py
      ../../tests/stub/scripts/opencode.json
    ];
  };
  orca = orca-ide.override {
    agents = [ opencode ];
    updater = false;
  };
in
testers.runNixOSTest {
  name = "orca-ide-agents-stub";
  nodes.machine = {
    imports = [ module ];
    programs.orca-ide = {
      enable = true;
      package = orca;
    };
    environment.systemPackages = [
      xvfb
      jq
      git
      python3
      ffmpeg-full
      imagemagick
    ];
    # A monospace font for the terminal.
    fonts.enableDefaultPackages = true;
    users.users.alice.isNormalUser = true;
    virtualisation = {
      memorySize = 6144;
      cores = 4;
    };
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    # The repository the agent works in; opencode.json points OpenCode at
    # the stub.
    machine.succeed("bash ${vm} repo alice /home/alice/demo ${./agents-stub}/opencode.json")  # nolocalpath
    machine.succeed("bash ${vm} seed alice")
    machine.succeed("ORCA_VM_SRC=${src} bash ${vm} stub alice 8787 opencode.json /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} app alice")
    machine.succeed("bash ${vm} record alice /tmp/run.mp4")
    machine.succeed("bash ${vm} add alice /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} agent alice opencode /home/alice/demo 'write hello.txt' hello.txt")  # nolocalpath
    machine.succeed("su - alice -c 'DISPLAY=:99 import -window root /tmp/shot.png'")
    machine.succeed("bash ${vm} record-stop")
    machine.succeed("bash ${vm} compact /tmp/run.mp4 /tmp/demo.mp4")
    machine.succeed("bash ${vm} preview /tmp/demo.mp4 /tmp/preview.webp")
    for f in ["run.mp4", "demo.mp4", "preview.webp", "shot.png"]:
        machine.copy_from_vm(f"/tmp/{f}", "")
  '';
}
