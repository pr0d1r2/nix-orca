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
rec {
  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    inherit (sources) tag;
    inherit (sources.src) hash;
  };

  # pnpm stays the pin's 11.27.0; inside the fetcher it does not switch to
  # upstream's `packageManager` 12.8.1 (nix/linux R2).
  pnpmDeps = fetchPnpmDeps {
    pname = "orca-ide";
    inherit (sources) version;
    inherit src pnpm;
    inherit (sources.pnpmDeps) hash;
    fetcherVersion = 4;
  };
}
