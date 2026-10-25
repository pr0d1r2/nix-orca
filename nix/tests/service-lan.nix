# checks.x86_64-linux.service-lan (nix/modules T7, V7): services.orca-ide
# for a LAN, in three NixOS VMs on the test VLAN. The server binds eth1's
# address (listenInterface) and opens the port on eth1 to one client only
# (firewallInterfaces, allowedClients): `allowed` connects, `denied` is
# refused by the firewall. `wide` binds 0.0.0.0, upstream's default, with
# the same firewall (V8): the firewall alone keeps `denied` out, and the
# unit's mount namespace hides /home and keeps / read-only. The checks are
# scripts/check/vm-orca.sh and nc; Python only drives the VMs.
{
  testers,
  netcat,
  module,
  orca-ide,
}:
let
  client = {
    environment.systemPackages = [ netcat ];
    virtualisation.memorySize = 512;
  };
  vm = {
    memorySize = 4096;
    cores = 4;
  };
in
testers.runNixOSTest {
  name = "orca-ide-service-lan";
  nodes = {
    server =
      { nodes, ... }:
      {
        imports = [ module ];
        services.orca-ide = {
          enable = true;
          package = orca-ide;
          listenInterface = "eth1";
          firewallInterfaces = [ "eth1" ];
          allowedClients = [ "${nodes.allowed.networking.primaryIPAddress}/32" ];
        };
        virtualisation = vm;
      };
    wide =
      { nodes, ... }:
      {
        imports = [ module ];
        services.orca-ide = {
          enable = true;
          package = orca-ide;
          listenAddress = "0.0.0.0";
          firewallInterfaces = [ "eth1" ];
          allowedClients = [ "${nodes.allowed.networking.primaryIPAddress}/32" ];
        };
        virtualisation = vm;
      };
    allowed = client;
    denied = client;
  };
  testScript = ''
    start_all()
    server.wait_for_unit("orca-ide.service")
    server.wait_until_succeeds("ss -ltnH 'sport = :6768' | grep -q .", timeout=180)
    address = server.succeed("ip -4 -o addr show dev eth1 | awk '{ sub(\"/.*\", \"\", $4); print $4; exit }'").strip()
    server.succeed(f"bash ${../../scripts/check/vm-orca.sh} listening 6768 {address}")
    allowed_ip = allowed.succeed("ip -4 -o addr show dev eth1 | awk '{ sub(\"/.*\", \"\", $4); print $4; exit }'").strip()
    server.succeed(f"iptables -S nixos-fw | grep -qF -- '-s {allowed_ip}/32 -i eth1 -p tcp -m tcp --dport 6768 -j nixos-fw-accept'")
    allowed.wait_for_unit("network.target")
    denied.wait_for_unit("network.target")
    allowed.succeed(f"nc -z -w 5 {address} 6768")
    denied.fail(f"nc -z -w 5 {address} 6768")
    wide.wait_for_unit("orca-ide.service")
    wide.wait_until_succeeds("ss -ltnH 'sport = :6768' | grep -q .", timeout=180)
    wide.succeed("bash ${../../scripts/check/vm-orca.sh} listening 6768 0.0.0.0")
    wide_address = wide.succeed("ip -4 -o addr show dev eth1 | awk '{ sub(\"/.*\", \"\", $4); print $4; exit }'").strip()
    allowed.succeed(f"nc -z -w 5 {wide_address} 6768")
    denied.fail(f"nc -z -w 5 {wide_address} 6768")
    wide.succeed("mkdir -p /home/alice && touch /home/alice/secret")  # nolocalpath: a fixture in the VM
    wide.succeed("bash ${../../scripts/check/vm-orca.sh} isolated orca-ide.service /home/alice/secret")  # nolocalpath: a fixture in the VM
  '';
}
