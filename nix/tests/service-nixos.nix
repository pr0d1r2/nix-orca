# checks.x86_64-linux.service-nixos (nix/modules T2): services.orca-ide in a
# NixOS VM: the hardened unit starts, `serve` listens on loopback only, and
# systemd's exposure score stays within .exposure (V1). The checks are
# scripts/check/vm-orca.sh; Python only drives the VM.
{
  testers,
  module,
  orca-ide,
}:
testers.runNixOSTest {
  name = "orca-ide-service-nixos";
  nodes.machine = {
    imports = [ module ];
    services.orca-ide = {
      enable = true;
      package = orca-ide;
    };
    virtualisation = {
      memorySize = 4096;
      cores = 4;
    };
  };
  testScript = ''
    machine.wait_for_unit("orca-ide.service")
    machine.wait_for_open_port(6768, timeout=120)
    machine.succeed("bash ${../../scripts/check/vm-orca.sh} listening 6768 127.0.0.1")
    machine.succeed("bash ${../../scripts/check/vm-orca.sh} exposure orca-ide.service ${../../.exposure}")
  '';
}
