# Running `orca-ide serve`

`orca-ide serve` runs Orca's runtime as a server that other Orca clients
pair with. A paired client can open terminals and launch agents, so it
runs code as the user serve runs as. This page shows how the NixOS
module `services.orca-ide` deploys it, why, and how to check it.

The configuration below is NixOS, but the unit and the firewall rule it
generates work on any systemd distribution.

## Two layers

- **The firewall** decides who reaches serve at all: its HTTP and
  WebSocket parsing, the pairing endpoint and the web client, all of which
  answer before pairing.
- **The systemd unit** decides what serve, and every terminal and agent it
  starts, can touch. A paired client runs code; the unit is the boundary
  around that code.

Upstream's serve binds every interface (`0.0.0.0`) and has no option to
change that ([stablyai/orca#31387](https://github.com/stablyai/orca/issues/31387)).
This package adds one: `ORCA_SERVE_BIND_HOST` pins serve to one address,
through the runtime's own `pinnedBindHost`, which pairing never widens
([`scripts/build/linux-patch.sh`](../scripts/build/linux-patch.sh)). The
module sets it from `listenAddress`, to `127.0.0.1` by default.

## Profiles

### Loopback (the default)

```nix
services.orca-ide.enable = true;
```

Serve listens on `127.0.0.1:6768` and no port is opened. Reach it from
another machine through SSH:

```sh
ssh -L 6768:127.0.0.1:6768 host
```

### LAN

```nix
services.orca-ide = {
  enable = true;
  listenInterface = "enp3s0";             # its address, from DHCP
  firewallInterfaces = [ "enp3s0" ];      # the port opens there only
  allowedClients = [ "192.168.1.0/24" ];  # and only to these sources
};
```

`listenInterface` binds that interface's first IPv4 address, waiting up
to 60 s for DHCP to hand one out
([`scripts/service/serve-bind.sh`](../scripts/service/serve-bind.sh)). A
later address change needs a restart of the service. `listenAddress`
binds a fixed address instead; set one or the other. `allowedClients`
limits who reaches serve, not where the agents connect. `openFirewall`
opens the port on every interface to everyone, and combines with neither
list.

### VPN

```nix
services.orca-ide = {
  enable = true;
  listenInterface = "tailscale0";         # or a WireGuard wg0
  firewallInterfaces = [ "tailscale0" ];
};
```

Beyond the LAN, put serve on a VPN interface rather than opening a port
to the internet.

### Upstream's default, `0.0.0.0`

```nix
services.orca-ide = {
  enable = true;
  listenAddress = "0.0.0.0";
  firewallInterfaces = [ "enp3s0" ];
  allowedClients = [ "192.168.1.0/24" ];
};
```

This is what stock Orca does, so it is how to harden a deployment without
this package's patch: serve listens everywhere and the firewall alone
limits who reaches it. Leave both lists empty and the port stays closed:
only the host itself reaches serve.

Reachability then rests entirely on the host firewall. A host with no
firewall, or one that is disabled, open, or bypassed (some container
runtimes insert their own rules), exposes serve on every interface.

## The unit

`services.orca-ide` runs serve as this unit
([`nix/modules/nixos.nix`](../nix/modules/nixos.nix)):

```ini
[Service]
ExecStart=/nix/store/...-orca-ide/bin/orca-ide serve --port 6768
Environment=HOME=/var/lib/orca-ide
Environment=ORCA_SERVE_BIND_HOST=127.0.0.1

# Identity: a throwaway user, not a login user. Its only writable,
# persistent place is /var/lib/orca-ide: the repositories it serves,
# the agents' credentials and Orca's settings.
DynamicUser=yes
StateDirectory=orca-ide
UMask=0077

# Filesystem: the OS read-only; /home, /root and /run/user empty, so no
# user's SSH keys or browser profiles; a private /tmp and /dev.
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes

# Privilege: no capabilities, no setuid or setgid, its own user
# namespace.
NoNewPrivileges=yes
CapabilityBoundingSet=
RestrictSUIDSGID=yes
PrivateUsers=yes

# Kernel surface
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
LockPersonality=yes
RestrictRealtime=yes
SystemCallArchitectures=native
# A deny list: under @system-service, Chromium's zygote fails to start
# (EINVAL), even with unshare, setns, @mount or @privileged added.
SystemCallFilter=~@clock ~@cpu-emulation ~@debug ~@module ~@obsolete ~@raw-io ~@reboot ~@swap

# Sockets and namespaces
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
# Chromium's sandbox makes user, pid and net namespaces; only cgroup
# namespaces can go.
RestrictNamespaces=~cgroup
# No MemoryDenyWriteExecute: V8's JIT writes executable code.
```

Each directive was bisected in a NixOS VM; the comments name what the
stricter setting broke. `systemd-analyze security orca-ide.service`
scores 2.2, and a check fails if a change raises it
([`.exposure`](../.exposure)).

The unit does not limit outbound network traffic. `IPAddressDeny=` would
also cut off the agents, which need their model APIs. So the unit
contains filesystem, privilege and kernel access; it does not stop what
is in `/var/lib/orca-ide` from leaving the host.

The firewall rule for the LAN profile, as the module writes it for
nftables (an input chain whose policy drops):

```text
iifname "enp3s0" ip saddr { 192.168.1.0/24 } tcp dport 6768 accept
```

and for iptables:

```sh
iptables -A nixos-fw -i enp3s0 -p tcp --dport 6768 -s 192.168.1.0/24 -j nixos-fw-accept
```

## Check it

On the host:

```sh
ss -ltn 'sport = :6768'                        # the address serve is bound on
systemd-analyze security orca-ide.service      # the exposure score
nft list ruleset | grep 6768                   # or: iptables -S nixos-fw | grep 6768
pid=$(systemctl show -p MainPID --value orca-ide.service)
nsenter -t "$pid" -m ls /home                  # empty: the unit sees no home
nsenter -t "$pid" -m touch /probe              # fails: / is read-only
```

The flake checks these in NixOS VMs on every change:

| check | what it shows |
| --- | --- |
| [`service-nixos`](../nix/tests/service-nixos.nix) | the unit starts; serve listens on `127.0.0.1` only; exposure within `.exposure` |
| [`service-lan`](../nix/tests/service-lan.nix) | two servers, one on `listenInterface` and one on `0.0.0.0`, and two clients. The allowed client connects to both, the other is refused by both; the `0.0.0.0` unit sees no `/home` and cannot write `/` |

## Not covered

- **macOS**: this flake has no launchd service for serve yet. Plain
  `orca-ide serve` there binds every interface.
- **Plain `orca-ide serve`** run by hand, outside the unit, gets neither
  layer.
- **Whether Orca encrypts pairing traffic on a plain network** is not
  checked here.

When upstream ships its own bind option, the module will map
`listenAddress` and `listenInterface` onto it and drop the patch
([`nix/linux/SPEC.md`](../nix/linux/SPEC.md) T9).
