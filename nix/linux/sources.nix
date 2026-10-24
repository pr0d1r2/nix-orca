# The upstream tag and its JS dependencies (nix/linux T1), both fixed-output
# and hashed in nix/sources.json. The deps fetch is the whole pnpm store for
# every platform (fetchPnpmDeps passes --force), 1.84 GB, build-time only:
# never in the runtime closure and never pushed (root V5).
{
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  sources,
}:
let
  # pnpm 12 leaves an empty v11/links/ in the store on darwin, not on Linux,
  # even with the global virtual store off; empty, it holds nothing, but it
  # makes the fixed-output hash depend on the platform (measured 2026-10-24,
  # pnpm 12.15.0). rmdir only removes it while it is empty.
  dropEmptyLinks = ''
    rmdir "$storePath/v11/links" 2>/dev/null || true
  '';
in
rec {
  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    inherit (sources) tag;
    inherit (sources.src) hash;
  };

  # pnpm is nix-pnpm's 12, the major upstream's `packageManager` pins
  # (nix/linux/pnpm.nix, root T18).
  pnpmDeps = fetchPnpmDeps {
    pname = "orca-ide";
    inherit (sources) version;
    inherit src pnpm;
    inherit (sources.pnpmDeps) hash;
    fetcherVersion = 4;
    # Upstream's config/pnpmfile.cjs (since v1.4.232) turns on pnpm's global
    # virtual store outside CI; it unpacks packages into the store, and the
    # fetcher's fixup then fails on their JSONC tsconfig files. Off, as
    # upstream's own CI runs it.
    ORCA_PNPM_GLOBAL_VIRTUAL_STORE = "0";
    postInstall = dropEmptyLinks;
  };

  # `mobile/` has its own lockfile; the desktop app ships its web build
  # (`out/mobile-web`), so its deps are a second fetch (R3).
  mobilePnpmDeps = fetchPnpmDeps {
    pname = "orca-ide-mobile";
    inherit (sources) version;
    inherit src pnpm;
    inherit (sources.mobilePnpmDeps) hash;
    fetcherVersion = 4;
    preInstall = "cd mobile";
    postInstall = dropEmptyLinks;
  };
}
