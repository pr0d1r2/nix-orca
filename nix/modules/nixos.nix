# nixosModules.orca-ide (nix/modules T1, T2):
# - `programs.orca-ide` puts orca-ide on the system PATH, with its desktop
#   entry and icons
# - `services.orca-ide` runs `orca-ide serve` as a hardened system service
#   (D35): a dynamic user, state under /var/lib, loopback unless told
# The default package is this flake's, the one CI builds and the cache
# holds.
{ packages }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.orca-ide;
  service = config.services.orca-ide;
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
        pairing is the only gate in front of it.
      '';
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `port` in the firewall.";
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
      environment.systemPackages = [ cfg.package ];
    })
    (lib.mkIf service.enable {
      networking.firewall.allowedTCPPorts = lib.optional service.openFirewall service.port;
      systemd.services.orca-ide = {
        description = "Orca runtime server (orca-ide serve)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          HOME = service.stateDir;
          ORCA_SERVE_BIND_HOST = service.listenAddress;
        };
        serviceConfig = {
          ExecStart = "${lib.getExe service.package} serve --port ${toString service.port}";
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
