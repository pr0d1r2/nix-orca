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
