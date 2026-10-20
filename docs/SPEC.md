# SPEC

## §G GOAL

human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER.

## §N NAV

rel|path|lens
up|.|-
self|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats

## §C CONSTRAINTS

- README: platform table, pin graph, cachix trust trap (untrusted user ignores flake `nixConfig`; admin adds substituter & key), attach overlay to NixOS / nix-darwin / home-manager, agents & overrides, releases = text only & how to fetch by store path.
- README notes (D26, D27, D32): Ubuntu ≥ 24.04 AppArmor userns → load shipped profile, ⊥ suggest `--no-sandbox`; updater override on distros w/ `dpkg`; darwin updater & telemetry limits; `Nix Apps` Spotlight; darwin sandbox opt-out → please open issue.
- README note (round 7): ⊥ use Orca's Settings → CLI "Register in PATH" under nix: it symlinks a command path (`orca` on darwin) to the launcher inside the store path, which dangles after update + GC; `bin/orca-ide` from the package is the CLI.
- ⊥ private repo named.

## §I INTERFACES

- file: `README.md`, `docs/SECURITY.md`, `docs/CONTRIBUTING.md`, `docs/LLM-DISCLAIMER.md`.

## §V INVARIANTS

V1: ∀ external command not on wrapper `PATH` named in README (`nix/linux:V8`).
V2: README platform table ≡ systems in `flake.nix`.

## §T TASKS

id|status|task|cites
T1|.|README|V1,V2
T2|.|SECURITY, CONTRIBUTING, LLM-DISCLAIMER|-

## §B BUGS

id|date|cause|fix
