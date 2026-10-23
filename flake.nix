{
  description = "Orca (stablyai/orca) as orca-ide, on the fleet nixpkgs pin";

  # Linux builds are pushed to this cache; darwin is never pushed (root V5).
  # A user outside `trusted-users` gets a warning and builds from source;
  # README names the admin step.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE nixpkgs, `nixpkgs-lock`'s (root V1). Gate tools live in dev/flake.nix,
  # so they never reach a consumer's lock (D8).
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    # Agent CLIs ahead of the pin (nix/agents). Source only: each package.nix
    # is called with the pin's packages, so the lock keeps one nixpkgs. A
    # consumer overrides one with `inputs.nix-orca.inputs.<name>.url`.
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      flake = false;
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      flake = false;
    };
    gemini-cli-nix = {
      url = "github:sadjow/gemini-cli-nix";
      flake = false;
    };
    pi-nix = {
      url = "github:sadjow/pi-nix";
      flake = false;
    };
    grok-build-nix = {
      url = "github:AodhanHayter/grok-build-nix";
      flake = false;
    };
    nix-mistral-vibe = {
      url = "github:pr0d1r2/nix-mistral-vibe";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      sources = import ./nix/sources.nix { inherit (nixpkgs) lib; };

      # The flake's own agent outputs evaluate unfree agents (nix §C); this
      # is the one place config.allowUnfree is set, and only for agents.
      agentsFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        import ./nix/agents/default.nix {
          inherit (pkgs) lib;
          inherit pkgs inputs system;
        };

      # Per system, the packages that exist there; filled node by node (root
      # T8). A system without a package still evaluates (nix V2).
      ownPackages =
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) isDarwin system;
        in
        rec {
          orca-ide =
            if isDarwin then
              pkgs.callPackage ./nix/darwin/package.nix { inherit sources; }
            else
              pkgs.callPackage ./nix/linux/package.nix { inherit sources; };
          orca-ide-agents = orca-ide.override {
            agents = builtins.attrValues (agentsFor system);
          };
        };
      upstream = pkgs: (pkgs.callPackage ./nix/linux/sources.nix { inherit sources; }).src;
      agentIds =
        pkgs:
        import ./nix/agents/ids.nix {
          inherit (pkgs) runCommand;
          src = upstream pkgs;
        };
    in
    {
      overlays.default = import ./nix/overlay.nix { inherit inputs sources; };

      nixosModules = rec {
        orca-ide = import ./nix/modules/nixos.nix { inherit (inputs.self) packages; };
        default = orca-ide;
      };

      apps = forAll (
        pkgs:
        nixpkgs.lib.mapAttrs
          (_: drv: {
            type = "app";
            program = "${drv}/bin/orca-ide";
            meta.description = "Orca, an IDE that runs a fleet of coding agents";
          })
          (
            let
              own = ownPackages pkgs;
            in
            nixpkgs.lib.optionalAttrs (own ? orca-ide) {
              inherit (own) orca-ide;
              default = own.orca-ide;
            }
          )
      );

      legacyPackages = forAll (pkgs: {
        agents = agentsFor pkgs.stdenv.hostPlatform.system;
        agent-ids = agentIds pkgs;
      });
      packages = forAll (
        pkgs:
        let
          own = ownPackages pkgs;
        in
        own // nixpkgs.lib.optionalAttrs (own ? orca-ide) { default = own.orca-ide; }
      );
      checks = forAll (
        pkgs:
        let
          own = ownPackages pkgs;
        in
        {
          # Evaluating it runs nix/sources.nix's shape checks (nix T2).
          sources = pkgs.writeText "nix-orca-sources.json" (builtins.toJSON sources);
          # The overlay adds exactly orca-ide and orca-ide-agents (nix V1).
          overlay =
            let
              added = builtins.attrNames (import ./nix/overlay.nix { inherit inputs sources; } { } { });
            in
            assert nixpkgs.lib.assertMsg (
              added == [
                "orca-ide"
                "orca-ide-agents"
              ]
            ) "overlays.default adds ${toString added}, want orca-ide orca-ide-agents (nix V1)";
            pkgs.writeText "nix-orca-overlay" (toString added);
        }
        // import ./nix/agents/checks.nix {
          inherit (pkgs) lib runCommand;
          ids = agentIds pkgs;
          agents = agentsFor pkgs.stdenv.hostPlatform.system;
        }
        // {
          agents-stub-cli = import ./nix/tests/agents-stub-cli.nix {
            inherit (pkgs)
              lib
              stdenv
              runCommand
              python3
              cacert
              ;
            agents = agentsFor pkgs.stdenv.hostPlatform.system;
          };
        }
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
          import ./nix/linux/checks.nix {
            inherit (pkgs)
              lib
              runCommand
              closureInfo
              jq
              patchelf
              agent-browser
              sherpa-onnx
              ;
            inherit sources;
            inherit (own) orca-ide;
          }
        )
        // nixpkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          module-nixos = import ./nix/tests/module-nixos.nix {
            inherit (pkgs) testers;
            module = inputs.self.nixosModules.orca-ide;
            inherit (own) orca-ide;
            inherit (sources) version;
          };
          service-nixos = import ./nix/tests/service-nixos.nix {
            inherit (pkgs) testers;
            module = inputs.self.nixosModules.orca-ide;
            inherit (own) orca-ide;
          };
          launch = import ./nix/tests/launch.nix {
            inherit (pkgs) testers xvfb jq;
            module = inputs.self.nixosModules.orca-ide;
            inherit (own) orca-ide;
          };
          agents-stub = import ./nix/tests/agents-stub.nix {
            inherit (pkgs)
              lib
              testers
              xvfb
              jq
              git
              python3
              ffmpeg-full
              imagemagick
              opencode
              ;
            module = inputs.self.nixosModules.orca-ide;
            inherit (own) orca-ide;
          };
        }
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
          import ./nix/darwin/checks.nix {
            inherit (pkgs)
              lib
              runCommand
              diffutils
              unzip
              ;
            inherit sources;
            inherit (own) orca-ide;
          }
        )
      );
    };
}
