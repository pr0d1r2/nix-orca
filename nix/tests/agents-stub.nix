# checks.x86_64-linux.agents-stub (tests T4, layer 2, V3): in a NixOS VM,
# Orca opens under Xvfb for an unprivileged user, adds a repository and
# launches OpenCode on it; OpenCode asks the stub model server
# (tests/stub) and its tool call writes hello.txt. No network, no key
# (V2). The display is recorded: the output holds run.mp4, its compacted
# demo.mp4, demo.mp4 as animated WebP, preview.webp, and the last frame,
# shot.png (docs/DEMO.md, scripts/demo-assets.sh). The checks are
# scripts/check/vm-orca.sh; Python only drives the VM.
{
  testers,
  linkFarm,
  writeShellScript,
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
  # tests.stub.server runs as a module from the directory holding tests/.
  src = linkFarm "orca-stub-src" [
    {
      name = "tests";
      path = ../../tests;
    }
  ];
  orca = orca-ide.override {
    agents = [ opencode ];
    updater = false;
  };
  # The repository the agent works in; opencode.json points OpenCode at
  # the stub.
  repo = writeShellScript "agents-stub-repo" ''
    set -eu
    mkdir ~/demo
    cd ~/demo
    git init -q
    git config user.email demo@localhost
    git config user.name demo
    cat >opencode.json <<'EOF'
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "stub/stub",
      "autoupdate": false,
      "provider": {
        "stub": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "stub",
          "options": { "baseURL": "http://127.0.0.1:8787/v1", "apiKey": "stub" },
          "models": { "stub": { "name": "stub" } }
        }
      }
    }
    EOF
    echo demo >README
    git add -A
    git commit -qm init
  '';
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
    machine.succeed("su - alice -c ${repo}")
    machine.succeed("bash ${vm} seed alice")
    machine.succeed("ORCA_VM_SRC=${src} bash ${vm} stub alice 8787 opencode.json /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} app alice")
    machine.succeed("bash ${vm} record alice /tmp/run.mp4")
    machine.succeed("bash ${vm} agent alice opencode /home/alice/demo 'write hello.txt' hello.txt")  # nolocalpath
    machine.succeed("su - alice -c 'DISPLAY=:99 import -window root /tmp/shot.png'")
    machine.succeed("bash ${vm} record-stop")
    machine.succeed("bash ${vm} compact /tmp/run.mp4 /tmp/demo.mp4")
    machine.succeed("bash ${vm} preview /tmp/demo.mp4 /tmp/preview.webp")
    for f in ["run.mp4", "demo.mp4", "preview.webp", "shot.png"]:
        machine.copy_from_vm(f"/tmp/{f}", "")
  '';
}
