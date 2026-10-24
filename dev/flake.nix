{
  description = "nix-orca -- dev shell: gate tools pinned, git hooks installed on entry";

  # hk and the fleet tools are pushed to this cache. Without the substituter
  # every entry into the shell builds them from source.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  # ONE nixpkgs: `nixpkgs-lock`'s, and every input follows it (dev V2). This
  # flake has its own lock, so none of these inputs reach a consumer's lock
  # (D8). Fleet tools are pinned to tags, each bumped in its own commit.
  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    nix-hk = {
      url = "github:pr0d1r2/nix-hk";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };

    # Spec form and spec operations (`mth`).
    microlith = {
      url = "github:pr0d1r2/microlith/v0.7.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # SPEC-DAG federation, budgets, waves.
    sherd = {
      url = "github:pr0d1r2/sherd/v0.5.4";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Allowed characters per file type (`ctrm`).
    characterminator = {
      url = "github:pr0d1r2/characterminator/v0.1.1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Hook guardrails materialised from `.pklith` (root T6).
    pklith = {
      url = "github:pr0d1r2/pklith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # Workflows materialised from `.actlith` (`release` node).
    actlith = {
      url = "github:pr0d1r2/actlith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "nix-hk";
    };
    # One language per file, 1:1 test mirror, TDD order (`xnl`).
    xenolith = {
      url = "github:pr0d1r2/xenolith/v0.1.0";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-hk,
      microlith,
      sherd,
      characterminator,
      pklith,
      actlith,
      xenolith,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The overlay makes `pkgs.hk` nix-hk's hk: the pin ships none.
      forAll =
        f: nixpkgs.lib.genAttrs systems (s: f (nixpkgs.legacyPackages.${s}.extend nix-hk.overlays.default));

      fleet = {
        inherit
          microlith
          sherd
          characterminator
          pklith
          actlith
          xenolith
          ;
      };

      # Fleet tools with no working build on a system. Taken from actlith's
      # measurement (2026-10-14), plus actlith itself, whose flake lists no
      # x86_64-darwin package. The shell still evaluates there and names the
      # missing tools on entry; a gate that needs one fails, never skips.
      unavailable = {
        x86_64-darwin = [
          "microlith"
          "characterminator"
          "pklith"
          "actlith"
          "xenolith"
        ];
      };
      missing = system: unavailable.${system} or [ ];

      # The tools `pklith gen` names for this repository's checks, written to
      # `nix/pklith.nix` (root T6). Resolved against nixpkgs plus the fleet
      # inputs, the namespace pklith's catalog uses. Empty until it exists,
      # and on a system missing fleet tools, whose gates fail anyway.
      generated =
        pkgs: system:
        let
          file = ../nix/pklith.nix;
          catalog = pkgs // {
            microlith = microlith.packages.${system}.default;
            sherd = sherd.packages.${system}.default;
            characterminator = characterminator.packages.${system}.default;
            xenolith = xenolith.packages.${system}.default;
          };
        in
        if missing system != [ ] || !builtins.pathExists file then [ ] else import file catalog;
      present =
        system:
        map (name: fleet.${name}.packages.${system}.default) (
          builtins.filter (name: !builtins.elem name (missing system)) (builtins.attrNames fleet)
        );
    in
    {
      devShells = forAll (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          absent = missing system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              # The gate runner, and the language its config is written in.
              pkgs.hk
              pkgs.pkl
              pkgs.git
              # Shell: tests, lint, format (`docs/SHELL.md`).
              pkgs.bats
              pkgs.shellcheck
              pkgs.shfmt
              # Nix: format, lint, dead code (`docs/NIX.md`).
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              pkgs.gitleaks
              pkgs.jq
              # Cache pushes and pins, closure diffs, CVE scan, SBOM.
              pkgs.cachix
              pkgs.nvd
              pkgs.vulnix
              pkgs.sbomnix
            ]
            ++ present system
            ++ generated pkgs system;

            # Deterministic tool output across machines.
            LANG = "C.UTF-8";

            # Hooks, the darwin builder warning and the missing fleet tools
            # (dev V1, D34): scripts/dev/shell-hook.sh.
            shellHook = "bash ${../scripts/dev/shell-hook.sh} ${system} ${pkgs.lib.escapeShellArgs absent}";
          };
        }
      );

      # The demo (tests T4): a check here, not in the root flake, because it
      # needs pklith and hk, dev inputs that must stay out of consumers'
      # locks (D8). Both flakes lock the same nixpkgs, so its Orca is the
      # root flake's own build.
      checks.x86_64-linux.agents-gate =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux.extend nix-hk.overlays.default;
          sources = import ../nix/sources.nix { inherit (pkgs) lib; };
          # nix-pnpm at the revision the root flake locks, so this is the
          # root flake's own package without a second lock to drift.
          nix-pnpm = builtins.fetchTree (builtins.fromJSON (builtins.readFile ../flake.lock))
            .nodes.nix-pnpm.locked;
          orca-ide = pkgs.callPackage ../nix/linux/package.nix {
            inherit sources;
            pnpm = pkgs.callPackage ../nix/linux/pnpm.nix { inherit nix-pnpm; };
          };
        in
        import ../nix/tests/agents-gate.nix {
          inherit (pkgs)
            lib
            testers
            xvfb
            jq
            git
            python3
            ffmpeg-full
            imagemagick
            hk
            pkl
            opencode
            ;
          pklith = pklith.packages.x86_64-linux.default;
          # The tools `pklith gen` names for the demo repository's files.
          gateTools = with pkgs; [
            deadnix
            editorconfig-checker
            gnugrep
            markdownlint-cli
            nixfmt
            ripsecrets
            shellcheck
            shfmt
            statix
            typos
          ];
          module = import ../nix/modules/nixos.nix {
            packages.x86_64-linux = { inherit orca-ide; };
            # No agent options set in the demo; the agent comes in by override.
            inputs = { };
          };
          inherit orca-ide;
        };
    };
}
