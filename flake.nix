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
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      sources = import ./nix/sources.nix { inherit (nixpkgs) lib; };

      # Per system, the packages that exist there; filled node by node (root
      # T8). A system without a package still evaluates (nix V2).
      ownPackages =
        pkgs:
        nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          orca-ide = pkgs.callPackage ./nix/darwin/package.nix { inherit sources; };
        };
    in
    {
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
