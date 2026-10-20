# SPEC

## §G GOAL

flake outputs wiring ∀ 4 systems: packages, overlay, apps, `legacyPackages.agents`, checks, `nixConfig`, `nix/sources.json`. each package & modules in child nodes.

## §F FEDERATION

dir|owns|⊥owns|tokens
linux|Linux `orca-ide` from source on pin Electron|`.deb` repackage & fixed-output pieces (`bin`), agent set (`agents`)|-
darwin|darwin `orca-ide` from upstream signed zip|Linux packages (`linux`, `bin`)|-

## §N NAV

rel|path|lens
up|.|-
self|nix|flake outputs, `nix/sources.json`; packages & modules in children

## §C CONSTRAINTS

- `flake.nix` at root; `nixpkgs.follows = "nixpkgs-lock/nixpkgs"`; 1 `import nixpkgs` per system, `config.allowUnfree = true` only for the flake's own agent outputs; overlay honours consumer's config (`nix/agents`).
- agent inputs (`nix/agents` §I) are `flake = false` except `nix-mistral-vibe` (flake, `inputs.nixpkgs-lock.follows = "nixpkgs-lock"`).
- `nix/sources.json`: upstream version, tag source hash, JS deps hash, `.deb` hashes & fixed-output piece hashes per Linux system, `-mac.zip` SRI `sha512` per darwin system. written only by `scripts` bump.
- ⊥ shell text in `.nix` (xenolith); scripts installed from `scripts/`, wrappers via `makeWrapper`.
- package attr missing on a system → absent from that system's set, ⊥ eval error.
- `nixConfig`: `extra-substituters` + `extra-trusted-public-keys` = fleet cachix (`.` §I).

## §I INTERFACES

- out: `packages.<system>.{orca-ide,default,orca-ide-agents}`; `packages.<linux>.orca-ide-bin`.
- out: `overlays.default` → `{ orca-ide, orca-ide-agents }`.
- out: `apps.<system>.{orca-ide,default}` → `bin/orca-ide`.
- out: `legacyPackages.<system>.agents.<name>`.
- out: `checks.<system>.*` — union of child checks for that system.
- file: `nix/sources.json` (schema per §C).

## §V INVARIANTS

V1: `overlays.default` adds exactly `orca-ide` & `orca-ide-agents`; check evaluates overlay on empty pkgs set & compares attr names.
V2: `nix flake check --all-systems` evaluates ∀ 4 systems on any host w/o building foreign systems.
V3: `nix/sources.json` = only file an upstream bump changes; bump PR diff ⊄ other paths → check fails.

## §T TASKS

id|status|task|cites
T1|.|`flake.nix` skeleton: `nixpkgs-lock` input, 4 systems, `nixConfig`|V2
T2|.|`nix/sources.json` + reader, schema check|V3
T3|.|`overlays.default`, `apps`, `checks` aggregation|V1

## §B BUGS

id|date|cause|fix
