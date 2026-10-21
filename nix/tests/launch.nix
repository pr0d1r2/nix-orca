# checks.x86_64-linux.launch (tests T1, D16): in a NixOS VM, orca-ide opens
# its window under Xvfb for an unprivileged user and its runtime answers;
# `orca-ide serve` runs headless for another user and listens. The checks
# are scripts/check/vm-orca.sh; Python only drives the VM. x86_64-linux
# only, as module-nixos.
{
  testers,
  xvfb,
  jq,
  module,
  orca-ide,
}:
testers.runNixOSTest {
  name = "orca-ide-launch";
  nodes.machine = {
    imports = [ module ];
    programs.orca-ide = {
      enable = true;
      package = orca-ide;
    };
    environment.systemPackages = [
      xvfb
      jq
    ];
    users.users.alice.isNormalUser = true;
    users.users.bob.isNormalUser = true;
    virtualisation = {
      memorySize = 4096;
      cores = 4;
    };
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("bash ${../../scripts/check/vm-orca.sh} app alice")
    machine.succeed("bash ${../../scripts/check/vm-orca.sh} serve bob 6769")
    machine.wait_for_open_port(6769)
  '';
}
