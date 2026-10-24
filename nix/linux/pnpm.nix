# pnpm 12 for the deps fetch and the build (nix/linux §C, root T18): the
# nix-pnpm flake's package, called with the caller's pkgs so it builds on
# the same nixpkgs. Upstream's package.json pins pnpm 12; the pin ships
# 11.27.0, which read its lockfile only by luck (R2).
{ callPackage, nix-pnpm }: callPackage "${nix-pnpm}/pkgs/pnpm/package.nix" { }
