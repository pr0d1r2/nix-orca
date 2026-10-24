# dev#checks.x86_64-linux.onboarding (tests T4): the onboarding video. In
# a NixOS VM, alice's Orca starts fresh, with only tips, tours, the star
# prompt and the telemetry banner seeded away, and the wizard runs:
# default agent (OpenCode, detected), look, GitHub tasks, notifications,
# each step held a moment. Its last step opens a folder picker, which the
# check closes; the repository comes in through `orca-ide repo add`
# instead. The output holds run.mp4, demo.mp4, preview.webp and shot.png
# (docs/DEMO.md, scripts/demo-assets.sh). Not required: the wizard
# changes between Orca releases, and the demo is not a gate.
{
  testers,
  xvfb,
  jq,
  git,
  ffmpeg-full,
  imagemagick,
  xdotool,
  sqlite,
  module,
  orca-ide,
  opencode,
}:
let
  vm = ../../scripts/check/vm-orca.sh;
  orca = orca-ide.override {
    agents = [ opencode ];
    updater = false;
  };
in
testers.runNixOSTest {
  name = "orca-ide-onboarding";
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
      ffmpeg-full
      imagemagick
      xdotool
      sqlite
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
    machine.succeed("bash ${vm} repo alice /home/alice/demo")  # nolocalpath
    machine.succeed("bash ${vm} seed alice onboarding")
    machine.succeed("bash ${vm} app alice")
    machine.succeed("bash ${vm} record alice /tmp/run.mp4")
    # The wizard's four steps; Ctrl+Enter is its Continue. A press during a
    # step's transition is lost, so press until Orca records the wizard
    # closed, at most six times.
    # Orca keeps onboarding in its SQLite profile state, not orca-data.json.
    closed = "su - alice -c \"sqlite3 ~/.config/orca/profiles/*/profile-state.db \\\"select count(*) from profile_state_documents where payload like '%lastCompletedStep%' and payload not like '%closedAt\\\\\\\":null%'\\\"\" | grep -qx 1"
    for _ in range(6):
        if machine.execute(closed)[0] == 0:
            break
        machine.succeed("ORCA_VM_KEY_PAUSE=4 bash ${vm} keys alice ctrl+Return")
    machine.succeed(closed)
    # Its last step opens a folder picker: close it, add the repository.
    machine.succeed("bash ${vm} keys alice Escape")
    machine.succeed("bash ${vm} add alice /home/alice/demo")  # nolocalpath
    machine.sleep(4)
    machine.succeed("su - alice -c 'DISPLAY=:99 import -window root /tmp/shot.png'")
    machine.succeed("bash ${vm} record-stop")
    machine.succeed("bash ${vm} compact /tmp/run.mp4 /tmp/demo.mp4")
    machine.succeed("bash ${vm} preview /tmp/demo.mp4 /tmp/preview.webp")
    for f in ["run.mp4", "demo.mp4", "preview.webp", "shot.png"]:
        machine.copy_from_vm(f"/tmp/{f}", "")
  '';
}
