# SPEC

## §G GOAL

∀ Orca agent CLI w/ usable nix package as native nix package; `orca-ide-agents` puts them on Orca's `PATH`; consumer overrides any agent.

## §N NAV

rel|path|lens
up|.|-
up|nix|flake outputs, `nix/sources.json`; packages & modules in children
self|nix/agents|agent CLI set, `orca-ide-agents`, agent inputs
sib|nix/linux|Linux `orca-ide` from source on pin Electron
sib|nix/darwin|darwin `orca-ide` from upstream signed zip
sib|nix/bin|`orca-ide-bin` & fixed-output pieces from `.deb`
sib|nix/modules|NixOS, nix-darwin, home-manager modules; `orca-ide.sb`; `.exposure`

## §C CONSTRAINTS

- per-agent flakes, `flake = false` inputs, `package.nix` called w/ pin pkgs: `claude-code-nix` (`sadjow/claude-code-nix`), `codex-cli-nix` (`sadjow/codex-cli-nix`), `gemini-cli-nix` (`sadjow/gemini-cli-nix`), `pi-nix` (`sadjow/pi-nix`), `grok-build-nix` (`AodhanHayter/grok-build-nix`, xAI Grok Build). `nix-mistral-vibe` = flake input following `nixpkgs-lock` (D43).
- from pin: `opencode`, `aider-chat`, `goose-cli`, `amp-cli`, `crush`, `cursor-cli`, `github-copilot-cli`, `kiro-cli`, `qwen-code`, `acli` (D43).
- ⊥ pin `grok-cli` (community CLI, same command); ⊥ `ante`, `muse` (unrelated); `antigravity` ⊥ until its program = `agy`; `kilocode-cli` ⊥ (no platforms, wrong program).
- unfree: `claude-code`, `amp-cli`, `crush`, `cursor-cli`, `github-copilot-cli`, `kiro-cli`, `acli`. flake outputs evaluate w/ `allowUnfree`; overlay honours consumer config.
- `orca-ide` default `agents = [ ]`; ⊥ closure growth for lean package.
- ⊥ cachix push of ∀ agent | `orca-ide-agents` (licence, 5 GB, `.:V5`).
- agent inputs updated daily in own PR, opened w/ the bump App token (`release` §C, round 8) so `build.yml` runs; builds & checks, ⊥ release (D19, D43). ⊥ auto-merge: an update changes third-party nix code (`package.nix`) evaluated in this build; owner merges after reading the diff (round 9; D10 covers only upstream Orca bumps).
- later, ⊥ v1: each agent in own `systemd-nspawn` container | hardened unit.
- no-package list (V5), 26 `TuiAgent` ids at `v1.4.230`: `codebuddy`, `openclaude`, `autohand`, `ante`, `trae`, `opencode2`, `mimo-code`, `omp`, `prime-agent`, `qoder`, `qoder-cn`, `antigravity`, `kilo`, `aug`, `cline`, `freebuff`, `command-code`, `continue`, `droid`, `kimi`, `hermes`, `muse`, `dsh`, `zcode`, `devin`, `jcode`. potential, ⊥ v1: packaged only after first release (root T10) (owner, 2026-10-20).
- agent set by `TuiAgent` id (§I), 16: `claude`, `codex`, `gemini`, `pi`, `grok`, `mistral-vibe`, `opencode`, `aider`, `goose`, `amp`, `crush`, `cursor`, `copilot`, `kiro`, `qwen-code`, `rovo`. out (2026-10-20, amends D43): `codebuff` (pin pkg = npm launcher downloading CLI on first run, fails V3), `openclaw` (pin marks insecure; consumer adds via override + `permittedInsecurePackages`). `mistral-vibe` absent on x86_64-darwin: import-from-derivation at eval needs x86_64-darwin builder, breaks `nix:V2`. `claude-agent-teams` = Orca itself. id ≠ command for `cursor` (`cursor-agent`), `kiro` (`kiro-cli`), `mistral-vibe` (`vibe`), `qwen-code` (`qwen`), `rovo` (`acli`); `scripts/agents/tui-ids.sh` reads both.

## §I INTERFACES

- pkg: `orca-ide-agents` — `orca-ide.override { agents = <∀ available on system>; }`.
- legacy: `legacyPackages.<system>.agents.<name>`, name = Orca `TuiAgent` id.
- override: `inputs.nix-orca.inputs.<input>.{url,follows}`; `orca-ide.override { agents = [ ... ]; }`.

## §R RESEARCH

id|topic|finding|src
R1|agents `v1.4.230`|45 `detectCmd` in `src/shared/tui-agent-config.ts`; 18 w/ usable nix package; 7 unfree|`nix eval` `version`, `meta.mainProgram`, `meta.license` on pin
R2|aarch64-darwin 2026-10-20|16 agents build; each `--version` answers; `orca-ide-agents` closure 11.8 GB; largest `aider` 6.0 GB, `gemini` 2.2, `mistral-vibe` 2.2, `goose` 1.9, `qwen-code` 1.8, `grok` 1.8|`nix build`, `nix path-info -S`

## §V INVARIANTS

V1: ∀ agent in set: `meta.mainProgram` = Orca `detectCmd` | alias for its id at pinned upstream tag; check reads `tui-agent-config.ts` from source.
V2: agent unavailable on a system → absent there, ⊥ eval | build failure.
V3: ∀ agent `--version` exits 0 in sandbox w/o network | key.
V4: lock graph keeps 1 nixpkgs w/ agent inputs present (`.:V1`).
V5: ∀ `detectCmd` id at pinned upstream tag ∈ agent set ∪ no-package list kept here; new id upstream → check reports & opens 1 issue, ⊥ fails build (round 11).

## §T TASKS

id|status|task|cites
T1|x|agent set from pin + `detectCmd` check|V1,V2
T2|x|5 `flake = false` inputs + `nix-mistral-vibe`|V4
T3|x|`orca-ide-agents` + `--version` checks|V3
T4|.|daily agent-input update PR (`scripts`, script done: `scripts/agents-update.sh`; workflow in `release`)|-
T5|.|after first release (root T10): packaging nodes for no-package list (§C), nixpkgs first where licence allows|V5

## §B BUGS

id|date|cause|fix
