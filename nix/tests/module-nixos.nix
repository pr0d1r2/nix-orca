# checks.x86_64-linux.module-nixos (nix/modules T1): a NixOS VM with
# programs.orca-ide enabled gives an unprivileged user orca-ide on PATH,
# its desktop entry and its icons. The checks are
# scripts/check/vm-orca.sh; Python only drives the VM. x86_64-linux only:
# aarch64-linux VM checks wait for KVM on the arm runner (tests §C).
{
  testers,
  module,
  orca-ide,
  version,
}:
testers.runNixOSTest {
  name = "orca-ide-module-nixos";
  nodes.machine = {
    imports = [ module ];
    programs.orca-ide = {
      enable = true;
      package = orca-ide;
    };
    users.users.alice.isNormalUser = true;
    virtualisation.memorySize = 2048;
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("bash ${../../scripts/check/vm-orca.sh} module alice ${version}")
  '';
}
