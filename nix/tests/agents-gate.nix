# dev#checks.x86_64-linux.agents-gate (tests T4): the demo. In a NixOS VM,
# alice's Orca opens a repository with one script, pklith materializes
# its gate in an Orca terminal (seed, gen, confirm, the gate's own
# commit), then OpenCode, on the stub model, writes greet.sh with an
# unquoted variable and commits: the gate refuses (shellcheck SC2086),
# OpenCode quotes it and commits again, and the gate lets it through. No
# network, no key (V2). The output holds run.mp4, demo.mp4, preview.webp
# and shot.png (docs/DEMO.md, scripts/demo-assets.sh). In the dev flake:
# pklith and hk are dev inputs and stay out of consumers' locks (D8).
{
  lib,
  testers,
  xvfb,
  jq,
  git,
  python3,
  ffmpeg-full,
  imagemagick,
  hk,
  pkl,
  pklith,
  gateTools,
  module,
  orca-ide,
  opencode,
}:
let
  vm = ../../scripts/check/vm-orca.sh;
  # tests.stub.server runs as a module from the directory holding tests/;
  # the server alone, so a test edit elsewhere does not re-record the demo.
  src = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../tests/__init__.py
      ../../tests/stub/__init__.py
      ../../tests/stub/server.py
    ];
  };
  orca = orca-ide.override {
    agents = [ opencode ];
    updater = false;
  };
  # In directories, so their store paths end in their own names.
  files = ./agents-gate;
  stub = ./agents-stub;
in
testers.runNixOSTest {
  name = "orca-ide-agents-gate";
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
      hk
      pkl
      pklith
    ]
    ++ gateTools;
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
    machine.succeed("bash ${vm} repo alice /home/alice/demo ${stub}/opencode.json ${files}/hello.sh")  # nolocalpath
    machine.succeed("bash ${vm} seed alice")
    machine.succeed("ORCA_VM_SRC=${src} bash ${vm} stub alice 8787 ${files}/opencode.json /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} app alice")
    machine.succeed("bash ${vm} record alice /tmp/run.mp4")
    machine.succeed("bash ${vm} add alice /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} gate alice /home/alice/demo ${../../pkl/Config.pkl}")  # nolocalpath
    # Let the gate's checks be read before the agent takes the window.
    machine.sleep(3)
    machine.succeed("bash ${vm} agent alice opencode /home/alice/demo 'make greet.sh greet by name, commit it' greet.sh")  # nolocalpath
    machine.succeed("bash ${vm} commits alice /home/alice/demo 3")  # nolocalpath
    machine.succeed("su - alice -c 'DISPLAY=:99 import -window root /tmp/shot.png'")
    machine.succeed("bash ${vm} record-stop")
    machine.succeed("bash ${vm} compact /tmp/run.mp4 /tmp/demo.mp4")
    machine.succeed("bash ${vm} preview /tmp/demo.mp4 /tmp/preview.webp")
    for f in ["run.mp4", "demo.mp4", "preview.webp", "shot.png"]:
        machine.copy_from_vm(f"/tmp/{f}", "")
  '';
}
