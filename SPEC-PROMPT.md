DRAFT INPUT. This file is the prompt for the first ck:spec run. When that
run lands SPEC.md, mark this file HISTORICAL INPUT in its own commit; from
then on SPEC.md and the node specs it federates are the law, and where they
differ from this file, they win.

Paradigm: paradigm (`github.com/pr0d1r2/paradigm`), commit e5605a3 (no
tag yet), with the language pages `docs/NIX.md` and `docs/SHELL.md`. This
repository conforms to the paradigm process in full (decision 9). Process,
guardrail roster and shared conventions come from there; this file states
only the product and its deviations.

nix-orca

Orca, the desktop app for running a fleet of coding agents side by side
(`stablyai/orca`), as a Nix flake on the fleet's pinned nixpkgs, for all
four systems the fleet uses, cached on cachix and released on GitHub every
day.

# Problem and goals

Orca is not in nixpkgs. The `orca` attribute in nixpkgs is the GNOME screen
reader, a different program. Five public flakes and three NUR repositories
package Orca (survey below), but none of them fits the fleet:

- none follows `nixpkgs-lock`, so each one brings its own nixpkgs and a
  machine that attaches Orca to its system closure resolves a second
  nixpkgs, with no shared cache entry. This is the path multiplication
  `nixpkgs-lock` exists to stop.
- none builds `x86_64-darwin`, and only two build `aarch64-darwin`.
- none publishes its built outputs anywhere a consumer can check: there
  are no GitHub releases of nix outputs and no public cache for them.
- upstream releases often (51 stable releases in 70 days), so a hand-bumped
  package falls behind within days.

Goals:
- one flake that exposes Orca as `packages.<system>.orca-ide` and through
  `overlays.default`, so a NixOS, nix-darwin or home-manager configuration
  adds it to its closure with one input that follows `nixpkgs-lock`
- all four fleet systems, `aarch64-darwin`, `x86_64-darwin`,
  `x86_64-linux` and `aarch64-linux`, built by CI with nix, every one
  pushed to cachix
- a daily scheduled run that notices a new upstream release, bumps the pin,
  builds all four systems with nix and publishes a GitHub release of the
  nix outputs, with no human in the loop when every gate is green
- the same gate a fleet repository has: hk from `.pklith` via pklith, CI
  rendered by actlith, a federated spec checked by microlith and sherd,
  token ceilings by itok, characters by characterminator, one language
  per file by xenolith

# Naming

- Repository and flake name: `nix-orca`. The fleet names repositories
  whose product is a nix package of someone else's program
  `nix-<upstream>`: `nix-hk`, `nix-fakecloud`, `nix-mistral-vibe`,
  `nix-semble`, `nix-cavekit`. A deviation from the `-lith` rule, as for
  those; local.
- Package attribute and program: `orca-ide`, the name upstream gives its
  Linux packages (`orca-ide_<v>_amd64.deb`) and its CLI shim. Not `orca`:
  in an overlay that name would shadow the screen reader for every
  consumer of the overlay.
- Availability checked 2026-10-20:
  - no GitHub repository `pr0d1r2/nix-orca`
  - GitHub repository search `nix-orca in:name`: 13 results, most of them
    OrcaSlicer flakes; `Samuka007/nix-orca` packages this Orca,
    `Verantor/nix-orca` is an unrelated "nix helper" last pushed
    2024-09-06
  - nixpkgs (fleet pin `8ce7336`): `orca` is "Screen reader"; no
    `orca-ide`
  - Recount: `gh api repos/pr0d1r2/nix-orca`, `gh api -X GET
    search/repositories -f q='nix-orca in:name' -q .total_count`, `nix
    eval --raw github:NixOS/nixpkgs/<pin>#orca.meta.description`.
- Rejected alternatives (same date, same checks):
  - `orca-nix`: 13 GitHub repositories match, 4 of them package this Orca.
  - `nix-orca-ide`: free (0 results), but longer than it needs to be; the
    repository name is about the upstream project, the attribute about the
    program.
  - a `-lith` name: the fleet keeps `-lith` for its own tools.
