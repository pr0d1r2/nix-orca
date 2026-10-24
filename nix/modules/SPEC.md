# SPEC

## §G GOAL

NixOS, nix-darwin & home-manager modules, stacked: each built on previous, each done when its tests pass (D42).

## §N NAV

rel|path|lens
up|.|-
up|nix|flake outputs, `nix/sources.json`; packages & modules in children
self|nix/modules|NixOS, nix-darwin, home-manager modules; `orca-ide.sb`; `.exposure`
sib|nix/linux|Linux `orca-ide` from source on pin Electron
sib|nix/darwin|darwin `orca-ide` from upstream signed zip
sib|nix/bin|`orca-ide-bin` & fixed-output pieces from `.deb`
sib|nix/agents|agent CLI set, `orca-ide-agents`, agent inputs

## §C CONSTRAINTS

- order: `nixosModules.orca-ide` (package) → its `services.orca-ide` (`serve`, hardened) → `darwinModules.orca-ide` (launchd + Seatbelt) → `homeManagerModules.orca-ide`. next ⊥ start before previous green.
- NixOS service (D35): `DynamicUser`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, `PrivateDevices`, `NoNewPrivileges`, `CapabilityBoundingSet=`, `RestrictAddressFamilies`, `SystemCallFilter=@system-service`, `MemoryDenyWriteExecute` where JS JIT allows; `RestrictNamespaces` & `PrivateUsers` settled by test; ∀ relaxation commented w/ what breaks.
- service state: `DynamicUser` + `StateDirectory=orca-ide` → `/var/lib/orca-ide` (`stateDir` default); `serve` works on repos under `stateDir` only, ⊥ `/home` (`ProtectHome`); agent CLI creds also under `stateDir`; unit sets `HOME = stateDir` so Electron `userData` lands there too (round 10).
- `serve` binds `127.0.0.1` by default on NixOS & nix-darwin (upstream default `0.0.0.0`, `nix/linux` R7) (Seatbelt inbound rule follows `listenAddress` & port, D36); option `listenAddress`; `openFirewall = false` default; exposing beyond loopback ! explicit option & README names Orca's own pairing/auth as the only gate (round 10).
- LAN (owner 2026-10-24; upstream `stablyai/orca#31387`: safer, LAN pairing kept): firewall opens port only to `allowedClients` (CIDRs) and/or on `firewallInterfaces`, iptables & nftables; ⊥ w/ `openFirewall`. ⊥ systemd `IPAddressDeny`: blocks agents' outbound too. `listenInterface` binds that interface's address, resolved at start (`scripts/service/serve-bind.sh`), ⊥ w/ `listenAddress`. README: beyond LAN → VPN interface.
- exposure ratchet in `.exposure` (⊥ `.coverage`, `paradigm/V25`).
- darwin (D36): `launchd.daemons` job, dedicated user from `users.users`, launchd limits; `/usr/bin/sandbox-exec` w/ `orca-ide.sb` in repo: deny default, read `/nix/store` & system paths Electron needs, rw state dir only, inbound TCP only on serve port, exec only from `/nix/store`; store path, state dir, port as `-D` params. opt-out `services.orca-ide.sandbox.enable = false` keeps user & limits.
- prior art for profile: nix `sandbox-defaults.sb`, Chromium `.sb`. network rules by address & port, ⊥ domain.
- ⊥ declarative Orca settings in v1 (round 7): Orca keeps settings in SQLite `profile-state.db` (domain `settings`, revisioned writes) under Electron `userData`, legacy `orca-data.json` beside it (`src/main/persistence/`); ⊥ file a module can own. later node needs upstream import | CLI path.

## §I INTERFACES

- module: `nixosModules.{orca-ide,default}` — `programs.orca-ide.{enable,package}`, `services.orca-ide.{enable,package,port,listenAddress,listenInterface,allowedClients,openFirewall,firewallInterfaces,stateDir}`.
- module: `darwinModules.{orca-ide,default}` — same + `services.orca-ide.sandbox.enable` (default `true`).
- module: `homeManagerModules.{orca-ide,default}` — `programs.orca-ide.{enable,package}`.
- file: `nix/modules/orca-ide.sb`, `.exposure`.

## §R RESEARCH

id|topic|finding|src
R1|unit hardening 2026-10-21|each D35 directive bisected w/ `systemd-run` in NixOS VM: 19 pass as is; `SystemCallFilter=@system-service` (+ `unshare`/`setns`/`@mount`/`@privileged`) → Chromium zygote EINVAL ∴ deny list `~@clock ~@cpu-emulation ~@debug ~@module ~@obsolete ~@raw-io ~@reboot ~@swap`; `RestrictNamespaces` needs all but cgroup (`~cgroup`); `MemoryDenyWriteExecute` ⊥ (JS engine JIT). Electron serve binds `0.0.0.0` → patched `ORCA_SERVE_BIND_HOST` → `pinnedBindHost` (owner choice); loopback default asked upstream in `stablyai/orca#31387` (drop patch when it lands). exposure 2.2|`nix/tests/service-nixos.nix`, bisect on nix-builder.local

## §V INVARIANTS

V1: `systemd-analyze security orca-ide-serve` exposure ≤ `.exposure`; raise fails (D35).
V2: under full hardening `serve` answers & client session runs agent command (D35).
V3: same service runs in NixOS container (`containers.<name>`, systemd-nspawn) inside VM (D35).
V4: darwin probes: job starts; `serve` answers; write outside state dir fails; owner home unreadable; unified log Sandbox denials = expected set only (D36).
V5: `sandbox.enable = false` → ⊥ `sandbox-exec` in job, user & limits kept.
V6: home-manager activation puts `orca-ide` on `PATH`; ⊥ module writes into Orca `userData`.
V7: LAN service: allowed client connects, other client refused by firewall; port closed off `firewallInterfaces`; listens on `listenInterface` address only.
V8: `listenAddress = "0.0.0.0"` (upstream default): firewall alone limits reach, allowed client connects, other refused; unit mount ns hides `/home`, `/` read-only (owner 2026-10-24, `docs/SERVE.md`).

## §T TASKS

id|status|task|cites
T1|x|`nixosModules.orca-ide` + VM test (`checks.x86_64-linux.module-nixos`)|V6
T2|x|`services.orca-ide` hardened + exposure ratchet (`checks.x86_64-linux.service-nixos`, score 2.2)|V1
T3|.|`darwinModules.orca-ide` + `orca-ide.sb` + probes (macOS runner, Tart reference)|V4,V5
T4|.|`homeManagerModules.orca-ide` + activation check|V6
T5|.|darwin app placement: nix-darwin `/Applications/Nix Apps`, home-manager its own apps dir; Tart probe: TCC grant (Accessibility, Screen Recording) given to version N still holds after update to N+1 at a new store path; result → §R & README (round 10). probe opt-in, off by default: own output, ⊥ `checks`, ⊥ CI; README says unverified until run (owner 2026-10-24, root T18)|V4
T6|.|under full hardening: paired client session runs agent command via `serve`; same service in NixOS container inside VM|V2,V3
T7|x|LAN options + `checks.x86_64-linux.service-lan` (3 VMs)|V7
T8|.|`service-lan` + `wide` server on `0.0.0.0`; `vm-orca.sh isolated UNIT PATH`; `docs/SERVE.md` (profiles, unit isolation, verify, upstream `stablyai/orca#31387`); README LAN → link (owner 2026-10-24)|V7,V8

## §B BUGS

id|date|cause|fix
