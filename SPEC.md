# SPEC

## §G GOAL

`nix-orca` — Orca (`stablyai/orca`, desktop app running fleet of coding agents) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`), ∀ 4 fleet systems, attachable to NixOS, nix-darwin & home-manager closures w/ 1 input. Linux built from source on pin's Electron; darwin = upstream's signed `Orca.app` untouched. built daily; Linux cached on `pr0d1r2.cachix.org`; GitHub release only when upstream releases.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `e5605a3` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.
