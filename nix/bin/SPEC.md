# SPEC

## §G GOAL

`orca-ide-bin` on Linux: upstream `.deb` repackage w/ bundled Electron, fallback ∀ source build failure | Electron major ahead of pin; & fixed-output pieces from `.deb` shared w/ `nix/linux`.

## §N NAV

rel|path|lens
up|.|-
up|nix|flake outputs, `nix/sources.json`; packages & modules in children
self|nix/bin|`orca-ide-bin` & fixed-output pieces from `.deb`
sib|nix/linux|Linux `orca-ide` from source on pin Electron
sib|nix/darwin|darwin `orca-ide` from upstream signed zip
sib|nix/agents|agent CLI set, `orca-ide-agents`, agent inputs
sib|nix/modules|NixOS, nix-darwin, home-manager modules; `orca-ide.sb`; `.exposure`

## §C CONSTRAINTS

- fetch `.deb` w/ SRI `sha512` from `latest-linux*.yml`; missing entry | size ≠ → bump refuses (D12).
- `autoPatchelf` ∀ except `orcad-template`; ⊥ `chrome-sandbox` (D21, numtide notes).
- stable subtrees as fixed-output derivations, recursive NAR hash by bump (`nix hash path`) in `nix/sources.json`: `orcad-template/targets`, `node_modules` w/o sherpa, `onboarding`, `app.asar.unpacked/resources` (D33). symlinked into `resources/`; piece failing a `realpath` containment check → copied instead.
- `orcad-template/targets` piece also used by `nix/linux` (D38), taken from each Linux system's own `.deb` (hash per system in `nix/sources.json`). amd64 `.deb` `v1.4.230` carries 9 targets (`darwin-{arm64,x64}`, `linux-arm64-{glibc,musl}`, `linux-x64-{glibc,glibc217,musl}`, `win32-{arm64,x64}`); check reports when amd64 & arm64 trees differ (round 7).
- built & checked in CI, ⊥ cached, ⊥ released (D38).
- size swaps of `nix/linux` §C apply here too (ripgrep, agent-browser, sherpa).

## §I INTERFACES

- pkg: `orca-ide-bin` (Linux).
- pkg: `orcad-targets` (internal, fixed-output piece).

## §R RESEARCH

id|topic|finding|src
R1|`.deb` `v1.4.230` amd64 size|680 MB unpacked: Electron 318, `resources/` 363 (UI copies ~158, `orcad-template` 84, 15 `ripgrep` copies 72, `node_modules` 53, `cloud/` 6.5); 57 MB duplicate files|`du -sk`, file hashes of unpacked `.deb`
R2|`v1.4.229` → `v1.4.230`|514 of 663 MB files byte-identical; stable: `orcad-template/targets` 58.5 MB 91.5%, `node_modules` w/o sherpa ~20 MB 99.8%, `onboarding` 10.9 MB, `app.asar.unpacked/resources` 4.1 MB|hash ∀ file of both `.deb`s, group by `resources/` entry

## §V INVARIANTS

V1: `orcad-template` byte-for-byte upstream's; SSH upload from it to 2nd VM accepted by Orca's own sha256 check (D16, D33).
V2: unchanged subtree between releases keeps its store path.
V3: `orca-ide-bin` passes `nix/linux` launch test.

## §T TASKS

id|status|task|cites
T1|.|`.deb` repackage x86_64-linux|V3
T2|.|fixed-output pieces + bump hash step|V1,V2

## §B BUGS

id|date|cause|fix
