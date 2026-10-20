# nix-orca

[Orca](https://github.com/stablyai/orca), the IDE that runs a fleet of coding
agents, as a nix flake: `orca-ide`, on the fleet nixpkgs pin
([`nixpkgs-lock`](https://github.com/pr0d1r2/nixpkgs-lock)), for four
systems.

Status: pre-release. The darwin package builds and passes its checks; the
Linux source build is specified and waits for a Linux builder. Nothing is
published yet.

## Platforms

| system | how it is built | binary cache |
| --- | --- | --- |
| `aarch64-darwin` | upstream's signed `Orca.app`, from the release zip, untouched | no |
| `x86_64-darwin` | the same, built in CI under Rosetta | no |
| `x86_64-linux` | from source, on the pin's Electron (not built yet) | yes, once released |
| `aarch64-linux` | from source, on the pin's Electron (not built yet) | yes, once released |

Darwin is never pushed to the cache: nix fetches upstream's zip from
GitHub and checks its sha512, its code signature and its signing team.

## Use

```sh
nix run github:pr0d1r2/nix-orca
```

`bin/orca-ide` is both the app and its CLI. Do not use Orca's own
Settings → CLI → "Register in PATH": it links a command to the launcher
inside one store path, and that link dangles after an update and a garbage
collection. Put the package on your `PATH` instead.

### The cache, and why nix may ignore it

The flake names `https://pr0d1r2.cachix.org` in its `nixConfig`. Nix only
honours that for users in `trusted-users`; for anyone else it prints a
warning and builds from source. An administrator adds the cache once, in
`nix.conf` or the system configuration:

```nix
nix.settings = {
  extra-substituters = [ "https://pr0d1r2.cachix.org" ];
  extra-trusted-public-keys = [
    "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
  ];
};
```

### NixOS, nix-darwin, home-manager

The overlay adds exactly `orca-ide` and `orca-ide-agents`:

```nix
{
  inputs.nix-orca.url = "github:pr0d1r2/nix-orca";

  outputs = { nixpkgs, nix-orca, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.overlays = [ nix-orca.overlays.default ]; }
        ({ pkgs, ... }: { environment.systemPackages = [ pkgs.orca-ide ]; })
      ];
    };
  };
}
```

The same overlay works in a nix-darwin configuration and in home-manager
(`home.packages = [ pkgs.orca-ide ];`). The flake follows `nixpkgs-lock`
for its one nixpkgs; consumers who use another nixpkgs can make it follow
theirs with `inputs.nix-orca.inputs.nixpkgs.follows`.

## Agents

`orca-ide` carries no agent CLI. `orca-ide-agents` is the same app with
every agent CLI this flake packages on its `PATH`, so Orca finds them:
Claude Code, Codex, Gemini CLI, pi, Grok Build, Mistral Vibe, OpenCode,
aider, goose, Amp, Crush, Cursor Agent, GitHub Copilot CLI, Kiro CLI, Qwen
Code and Rovo Dev (`acli`). Each one is also
`legacyPackages.<system>.agents.<id>`, keyed by Orca's own agent id.

Pick your own set:

```nix
pkgs.orca-ide.override {
  agents = [ pkgs.opencode pkgs.aider-chat ];
}
```

Six of them come from flakes that track their upstream releases ahead of
nixpkgs. Override any of those from your own flake:

```nix
inputs.nix-orca.inputs.claude-code-nix.url = "github:sadjow/claude-code-nix/<rev>";
```

The inputs are `claude-code-nix`, `codex-cli-nix`, `gemini-cli-nix`,
`pi-nix`, `grok-build-nix` and `nix-mistral-vibe`.

Seven agents are unfree (Claude Code, Amp, Crush, Cursor Agent, Copilot,
Kiro, Rovo Dev). Through the overlay they appear only when your nixpkgs
config allows unfree packages; the flake's own outputs allow them. Not
packaged: `codebuff` (nixpkgs' package downloads the CLI on first run) and
`openclaw` (nixpkgs marks it insecure; add it yourself with
`permittedInsecurePackages` if you accept that). Orca knows 26 more agents
with no nix package yet; they are listed in `nix/agents/no-package.txt`.

## Releases

A release follows each upstream Orca release, tagged
`v<upstream version>-nix.<n>`. It attaches no binaries: its notes give,
for each system, the store path, NAR hash and size, closure size, the
nixpkgs revision, the commit, a closure diff against the previous release,
vulnix findings and the result of rebuilding the package bit for bit. The
release files are the NAR hashes with their build-provenance attestation
and CycloneDX and SPDX SBOMs.

To fetch a released Linux build without evaluating the flake, ask the
cache for its store path:

```sh
nix-store --realise /nix/store/<hash>-orca-ide-<version> \
  --option extra-substituters https://pr0d1r2.cachix.org
```

The cache keeps the newest two builds per Linux system; older ones are
collected by the cache's retention.

## Notes

- **Ubuntu 24.04 and later** restrict unprivileged user namespaces through
  AppArmor, which Electron's sandbox needs. Load the AppArmor profile the
  Linux package ships under `share/apparmor/`; do not run Orca with
  `--no-sandbox`.
- **Linux outside NixOS**: the host's GPU driver is not in the nix store,
  so Chromium falls back to software rendering. Orca still runs. Hardware
  rendering needs a host-driver wrapper (nixGL style), which you add; the
  package bundles no host drivers.
- **Updates**: the nix package does not update itself. On Linux,
  `orca-ide.override { updater = false; }` also makes Orca's updater
  report itself unusable, which matters on distributions where it would
  otherwise offer a `.deb`. On darwin the app is upstream's own, signed,
  and nix does not change its updater; update through nix.
- **Telemetry**: `orca-ide.override { telemetry = false; }` sets
  `ORCA_TELEMETRY_DISABLED=1` for launches through `bin/orca-ide`. On
  darwin, a launch from Finder or Spotlight does not go through it.
- **Spotlight**: on nix-darwin and home-manager the app shows up under
  `Nix Apps`.
- **Commands not on the wrapper's `PATH`**: the darwin wrapper adds `git`
  only. Agent CLIs come from `orca-ide-agents` or your own `PATH`. The
  Linux wrapper's list lands with the Linux build.

## Repository

The flake is built from `SPEC.md` and its node specs; `docs/CONTRIBUTING.md`
says how changes land and `docs/SECURITY.md` how to report a problem. Much
of this repository was written with an AI agent; see
`docs/LLM-DISCLAIMER.md`.

Licence: MIT, as upstream Orca.
