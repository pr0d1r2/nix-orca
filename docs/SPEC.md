# SPEC

## §G GOAL

human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER.

## §N NAV

rel|path|lens
up|.|-
self|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|release|CI pipeline: workflows from `.actlith`, bump PR flow, cache checks, tokens, permissions

## §C CONSTRAINTS

- README: platform table, pin graph, cachix trust trap (untrusted user ignores flake `nixConfig`; admin adds substituter & key), attach overlay to NixOS / nix-darwin / home-manager, agents & overrides, ⊥ GitHub release (root T19): builds from cachix & how to fetch by store path.
- README notes (D26, D27, D32): Ubuntu ≥ 24.04 AppArmor userns → load shipped profile, ⊥ suggest `--no-sandbox`; updater override on distros w/ `dpkg`; darwin updater & telemetry limits; `Nix Apps` Spotlight; darwin sandbox opt-out → please open issue.
- README note (round 7): ⊥ use Orca's Settings → CLI "Register in PATH" under nix: it symlinks a command path (`orca` on darwin) to the launcher inside the store path, which dangles after update + GC; `bin/orca-ide` from the package is the CLI.
- README note (round 10): on Linux outside NixOS the host's GPU driver is ⊥ in the store, so Chromium falls back to software GL; Orca still runs. hardware GL needs a host-driver wrapper (nixGL-style) the consumer adds; package ⊥ bundles host drivers.
- ⊥ private repo named.

## §I INTERFACES

- file: `README.md`, `docs/SECURITY.md`, `docs/CONTRIBUTING.md`, `docs/LLM-DISCLAIMER.md`, `docs/DEMO.md`, `docs/BUILDER.md` (remote builder), `docs/SERVE.md` (serve profiles, unit isolation, checks; `nix/modules:V8`); `docs/demo/` holds the demo files, written by `scripts/demo-assets.sh` only.

## §V INVARIANTS

V1: ∀ external command not on wrapper `PATH` named in README (`nix/linux:V8`).
V2: README platform table ≡ systems in `flake.nix`.

## §T TASKS

id|status|task|cites
T1|x|README|V1,V2
T2|x|SECURITY, CONTRIBUTING, LLM-DISCLAIMER|-

## §B BUGS

id|date|cause|fix
