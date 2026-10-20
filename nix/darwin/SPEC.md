# SPEC

## §G GOAL

`orca-ide` on `aarch64-darwin` & `x86_64-darwin`: upstream signed `-mac.zip` unpacked, `Orca.app` untouched, `bin/orca-ide` shim.

## §N NAV

rel|path|lens
up|.|-
up|nix|flake outputs, `nix/sources.json`; packages & modules in children
self|nix/darwin|darwin `orca-ide` from upstream signed zip
sib|nix/linux|Linux `orca-ide` from source on pin Electron
sib|nix/bin|`orca-ide-bin` & fixed-output pieces from `.deb`
sib|nix/agents|agent CLI set, `orca-ide-agents`, agent inputs
sib|nix/modules|NixOS, nix-darwin, home-manager modules; `orca-ide.sb`; `.exposure`

## §C CONSTRAINTS

- fetch `Orca-<v>-arm64-mac.zip` | `Orca-<v>-mac.zip` w/ SRI `sha512` from upstream `latest-mac.yml`; manifest entry missing | size ≠ → bump refuses (D12).
- `Orca.app` copied w/ `dontFixup`; ⊥ patch, ⊥ re-sign, ⊥ strip (D38).
- `x86_64-darwin` built on arm64 runner via Rosetta, `extra-platforms = x86_64-darwin` (D39).
- wrapper: `git` on `PATH`; `telemetry = false` → `ORCA_TELEMETRY_DISABLED=1` for `bin/orca-ide` launches only (D27); ⊥ updater switch (D26).
- ⊥ pushed to cachix; consumer fetches zip from GitHub (D41).

## §I INTERFACES

- pkg: `orca-ide` (darwin) — `Applications/Orca.app`, `bin/orca-ide` → `Orca.app/Contents/Resources/bin/orca` (upstream CLI launcher, renamed per D5).
- check: `checks.<darwin>.{codesign,arch,orca-ide-version}`.

## §V INVARIANTS

V1: `codesign --verify --deep --strict` passes on store `Orca.app` (D16).
V2: `lipo -archs Orca.app/Contents/MacOS/Orca` = `arm64` on `aarch64-darwin`, `x86_64` on `x86_64-darwin` (D39).
V3: `Orca.app` tree ≡ zip contents byte for byte.
V4: unpack reproducible: `nix build --rebuild` bit-identical ∴ attested NAR hash reproducible by consumer (D30, D41).

## §T TASKS

id|status|task|cites
T1|.|`aarch64-darwin` package + checks|V1,V2,V3
T2|.|`x86_64-darwin` via Rosetta|V2
T3|.|rebuild check|V4

## §B BUGS

id|date|cause|fix
