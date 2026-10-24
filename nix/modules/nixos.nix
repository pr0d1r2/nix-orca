# nixosModules.orca-ide (nix/modules T1, T2):
# - `programs.orca-ide` puts orca-ide on the system PATH, with its desktop
#   entry and icons, and `agents.<id>.enable` the agent CLIs on its PATH,
#   each off by default (the whole set is ~11.8 GB, nix/agents R2)
# - `services.orca-ide` runs `orca-ide serve` as a hardened system service
#   (D35): a dynamic user, state under /var/lib, loopback unless told
# The default package is this flake's, the one CI builds and the cache
# holds.
{ packages, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.orca-ide;
  service = config.services.orca-ide;
  names = import ../agents/names.nix;
  # The agents that evaluate under this system's nixpkgs config (unfree,
  # insecure, platform), keyed by id.
  available = import ../agents/default.nix {
    inherit lib pkgs inputs;
    inherit (pkgs.stdenv.hostPlatform) system;
    extra = true;
  };
  # The firewall rules for allowedClients: the serve port, from those
  # sources, on firewallInterfaces or anywhere.
  v6 = builtins.filter (lib.hasInfix ":") service.allowedClients;
  v4 = lib.subtractLists v6 service.allowedClients;
  interfaces = if service.firewallInterfaces == [ ] then [ null ] else service.firewallInterfaces;
  nftRules = lib.concatMap (
    i:
    let
      onIf = lib.optionalString (i != null) "iifname \"${i}\" ";
      set = l: "{ ${lib.concatStringsSep ", " l} }";
    in
    lib.optional (v4 != [ ]) "${onIf}ip saddr ${set v4} tcp dport ${toString service.port} accept"
    ++ lib.optional (v6 != [ ]) "${onIf}ip6 saddr ${set v6} tcp dport ${toString service.port} accept"
  ) interfaces;
  iptRules = lib.concatMap (
    i:
    let
      onIf = lib.optionalString (i != null) "-i ${i} ";
      rule =
        cmd: c:
        "${cmd} -A nixos-fw ${onIf}-p tcp --dport ${toString service.port} -s ${c} -j nixos-fw-accept";
    in
    map (rule "iptables") v4 ++ map (rule "ip6tables") v6
  ) interfaces;
  enabled = builtins.filter (id: cfg.agents.${id}.enable) (names.default ++ names.extra);
  missing = builtins.filter (id: !(available ? ${id})) enabled;
  withAgents =
    if enabled == [ ] then
      cfg.package
    else
      cfg.package.override {
        agents = map (id: available.${id}) (lib.subtractLists missing enabled);
      };
  defaultPackage = lib.mkOption {
    type = lib.types.package;
    default = packages.${pkgs.stdenv.hostPlatform.system}.orca-ide;
    defaultText = lib.literalExpression "nix-orca.packages.\${system}.orca-ide";
    example = lib.literalExpression "nix-orca.packages.\${system}.orca-ide-agents";
    description = "The orca-ide package; `orca-ide-agents` brings the agent CLIs.";
  };
in
{
  options.programs.orca-ide = {
    enable = lib.mkEnableOption "Orca, an IDE that runs a fleet of coding agents";
    package = defaultPackage;
    agents = lib.genAttrs (names.default ++ names.extra) (id: {
      enable = lib.mkEnableOption "the `${id}` agent CLI on Orca's PATH";
    });
  };

  options.services.orca-ide = {
    enable = lib.mkEnableOption "the Orca runtime server, `orca-ide serve`";
    package = defaultPackage;
    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = "TCP port `orca-ide serve` listens on.";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Literal IP address the server binds. Beyond loopback, Orca's own
        pairing is the only gate in front of it, unless `allowedClients`
        limits who reaches it.
      '';
    };
    listenInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "enp3s0";
      description = ''
        Bind the server to this interface's first IPv4 address instead of
        `listenAddress`, resolved when the service starts (waiting up to 60 s
        for it), for a LAN whose address DHCP hands out. A later address
        change needs a restart of the service.
      '';
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `port` in the firewall, on every interface, to every source.";
    };
    firewallInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "enp3s0"
        "tailscale0"
      ];
      description = ''
        Open `port` in the firewall on these interfaces only, for a LAN or a
        VPN, where `openFirewall` opens it everywhere.
      '';
    };
    allowedClients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "192.168.1.0/24"
        "fd00::/8"
      ];
      description = ''
        Open `port` in the firewall only to these sources (IPv4 or IPv6
        addresses or CIDRs), on `firewallInterfaces` when set, else on every
        interface. A firewall rule, so it limits who reaches serve and not
        where the agents it runs connect.
      '';
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/orca-ide";
      readOnly = true;
      description = ''
        The service's home: Orca's settings, the repositories it serves
        and the agents' credentials live here (systemd's StateDirectory
        for the dynamic user).
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ withAgents ];
      warnings = map (
        id:
        "programs.orca-ide.agents.${id}: not available under this system's nixpkgs config (unfree, insecure or platform), left out"
      ) missing;
    })
    (lib.mkIf service.enable {
      assertions = [
        {
          assertion = service.listenInterface == null || service.listenAddress == "127.0.0.1";
          message = "services.orca-ide: set listenInterface or listenAddress, not both";
        }
        {
          assertion =
            !(service.openFirewall && (service.firewallInterfaces != [ ] || service.allowedClients != [ ]));
          message = "services.orca-ide: openFirewall opens the port everywhere; use firewallInterfaces or allowedClients instead, not both";
        }
      ];
      networking.firewall = {
        allowedTCPPorts = lib.optional service.openFirewall service.port;
        # With allowedClients, only its rules open the port.
        interfaces = lib.mkIf (service.allowedClients == [ ] && service.firewallInterfaces != [ ]) (
          lib.genAttrs service.firewallInterfaces (_: {
            allowedTCPPorts = [ service.port ];
          })
        );
        extraInputRules = lib.mkIf (config.networking.nftables.enable && nftRules != [ ]) (
          lib.concatStringsSep "\n" nftRules
        );
        extraCommands = lib.mkIf (!config.networking.nftables.enable && iptRules != [ ]) (
          lib.concatStringsSep "\n" iptRules
        );
      };
      systemd.services.orca-ide = {
        description = "Orca runtime server (orca-ide serve)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          HOME = service.stateDir;
        }
        // lib.optionalAttrs (service.listenInterface == null) {
          ORCA_SERVE_BIND_HOST = service.listenAddress;
        };
        # serve-bind.sh resolves listenInterface's address with ip and awk.
        path = lib.mkIf (service.listenInterface != null) [
          pkgs.iproute2
          pkgs.gawk
          pkgs.coreutils
        ];
        serviceConfig = {
          ExecStart =
            lib.optionalString (
              service.listenInterface != null
            ) "${pkgs.bash}/bin/bash ${../../scripts/service/serve-bind.sh} ${service.listenInterface} -- "
            + "${lib.getExe service.package} serve --port ${toString service.port}";
          DynamicUser = true;
          StateDirectory = "orca-ide";
          WorkingDirectory = service.stateDir;
          Restart = "on-failure";

          # Settled by test (nix/modules R1): every directive below lets
          # serve start; the comments name what the stricter one broke.
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          PrivateUsers = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          # A deny list: under @system-service, even with unshare, setns,
          # @mount or @privileged added, Chromium's zygote fails to start
          # (zygote_host_impl_linux.cc:207, EINVAL).
          SystemCallFilter = [
            "~@clock"
            "~@cpu-emulation"
            "~@debug"
            "~@module"
            "~@obsolete"
            "~@raw-io"
            "~@reboot"
            "~@swap"
          ];
          SystemCallArchitectures = "native";
          # Chromium's sandbox makes user, pid and net namespaces; only
          # cgroup namespaces can go (allowing user pid net mnt ipc uts
          # alone still broke it).
          RestrictNamespaces = "~cgroup";
          # No MemoryDenyWriteExecute: V8's JIT writes executable code.
          LockPersonality = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          UMask = "0077";
        };
      };
    })
  ];
}
