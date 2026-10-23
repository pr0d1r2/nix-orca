# nix-orca

[Orca](https://github.com/stablyai/orca), the IDE that runs a fleet of coding
agents, as a nix flake: `orca-ide`, on the fleet nixpkgs pin
([`nixpkgs-lock`](https://github.com/pr0d1r2/nixpkgs-lock)), for four
systems.

Status: pre-release. The darwin package and the x86_64-linux source build
build and pass their checks; aarch64-linux evaluates and waits for CI.
Nothing is published yet.

![Orca: pklith lays a gate, OpenCode commits, the gate refuses, OpenCode fixes it](docs/demo/preview.webp)

Orca runs the agent; the gate decides what lands. In a NixOS VM, with no
network and no key, [pklith](https://github.com/pr0d1r2/pklith) lays a
repository's gate in an Orca terminal, OpenCode commits a script, the
gate refuses it (shellcheck), and OpenCode fixes it and commits again.
[`docs/DEMO.md`](docs/DEMO.md) says how it runs and how to re-record it.

## Platforms

| system | how it is built | binary cache |
| --- | --- | --- |
| `aarch64-darwin` | upstream's signed `Orca.app`, from the release zip, untouched | no |
| `x86_64-darwin` | the same, built in CI under Rosetta | no |
| `x86_64-linux` | from source, on the pin's Electron | yes, once released |
| `aarch64-linux` | from source, on the pin's Electron (not built yet) | yes, once released |

Darwin is never pushed to the cache: nix fetches upstream's zip from
GitHub and checks its sha512, its code signature and its signing team.

## Use

```sh
nix run github:pr0d1r2/nix-orca -- open
```

`bin/orca-ide` is upstream's launcher: its CLI verbs, and `orca-ide open`
to start the app (on Linux the desktop entry starts it too). Without a
verb it prints the CLI's help. Do not use Orca's own
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

On NixOS the module does the same with this flake's package, the one the
cache holds:

```nix
{
  imports = [ nix-orca.nixosModules.default ];
  programs.orca-ide.enable = true;
  # programs.orca-ide.package = nix-orca.packages.x86_64-linux.orca-ide-agents;
}
```

`services.orca-ide.enable = true` runs `orca-ide serve` as a hardened
system service: a dynamic user whose home is `/var/lib/orca-ide`, where
the repositories it serves and the agents' credentials live, listening on
`127.0.0.1:6768`. `listenAddress` and `openFirewall` expose it; past
loopback, Orca's own pairing is the only gate. The package patches Orca's
serve so it can bind one address (`ORCA_SERVE_BIND_HOST`); upstream's
binds every interface.

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
- **Telemetry**: the Linux build compiles from source without upstream's
  analytics key, so it sends no telemetry at all; upstream designed its
  build that way for third-party builds. On darwin the app is upstream's
  official build: `orca-ide.override { telemetry = false; }` sets
  `ORCA_TELEMETRY_DISABLED=1` for launches through `bin/orca-ide`, and a
  launch from Finder or Spotlight does not go through it.
- **`orca-ide serve` on Linux** runs Orca's Electron server: its lighter
  orcad server needs upstream's own Node binary, which Orca downloads
  and checks by hash, and the nix package has none. Upstream's serve
  listens on every address; the package lets `ORCA_SERVE_BIND_HOST` pin
  one (the NixOS service sets it from `listenAddress`). Serve also
  installs `~/.local/bin/orca-ide` pointing at the current store path,
  which dangles after an update and a garbage collection like the PATH
  registration above: keep the package's own `bin/orca-ide` first on your
  `PATH`.
- **Spotlight**: on nix-darwin and home-manager the app shows up under
  `Nix Apps`.
- **`PYTHONPATH`**: Orca passes your environment to the agents it
  starts, and a `PYTHONPATH` exported by a shell (a nix shell with Python
  packages, a virtualenv) loads another Python's packages into the Python
  agents: Mistral Vibe stopped with "cannot import name 'sentinel' from
  'typing_extensions'". Launch Orca from an environment without it.
- **Commands on the wrapper's `PATH`**: on Linux, after your own `PATH`:
  `git`, `ps`, `xdg-open`, `xclip`, `wl-copy`, `xdotool` and `Xvfb`; the
  darwin wrapper adds `git` only. Orca uses more when you have them, and
  the package does not add these: `ssh` and `sftp` (remote hosts),
  `tmux`, `systemd-run`, `systemctl` and `loginctl` (terminal scopes,
  `orca serve install`), `secret-tool` and `gdbus` (keyring), `gh` and
  `glab` (pull requests), `python3` with PyGObject and AT-SPI (Linux
  computer use), and the Android SDK. Agent CLIs come from
  `orca-ide-agents` or your own `PATH`.

## Repository

The flake is built from `SPEC.md` and its node specs; `docs/CONTRIBUTING.md`
says how changes land and `docs/SECURITY.md` how to report a problem. Much
of this repository was written with an AI agent; see
`docs/LLM-DISCLAIMER.md`.

Licence: MIT, as upstream Orca.
