# Building on a remote Linux builder

The Linux package builds from source, and the NixOS VM checks need an
x86_64-linux host with KVM. From a Mac, that work goes to a remote
builder. This page describes how this repository uses one; adapt the
hostname to yours.

## The reference builder

`nix-builder.local` is a
[nixos-nix-builder](https://github.com/pr0d1r2/nixos-nix-builder)
appliance: NixOS booted from USB, x86_64-linux, KVM, `root@` over ssh.
Its `/` and `/tmp` are tmpfs, sharing its RAM, so anything large goes to
its storage disk instead (below). The dev shell says on entry when nix
does not list a Linux builder.

## Build there, evaluate here

Evaluate and fetch on your machine, build on the builder:

```sh
nix build --store ssh-ng://root@nix-builder.local --eval-store auto \
  .#checks.x86_64-linux.launch
```

Your machine fetches flake inputs with its own GitHub credentials; the
builder only builds what it is sent. Builds that fetch on the builder
itself (`ssh builder nix build github:...`) run into GitHub's
unauthenticated API limit, 60 requests an hour per address, which a home
network's builder and Mac share. If your own nix hits that limit too,
give it a token for one command:

```sh
NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake lock
```

or set `access-tokens` in your nix configuration.

Read a remote output's files without importing it (an untrusted user
cannot import the builder's unsigned paths):

```sh
nix store cat --store ssh-ng://root@nix-builder.local /nix/store/...-check/demo.mp4 >demo.mp4
```

`scripts/demo-assets.sh ssh-ng://root@nix-builder.local` does both for
the demo.

## Be a good neighbour

The builder is shared, and it may run other long-running work that
keeps its load average high. Gate heavy jobs on pressure, not load, with
[congestimancer](https://github.com/pr0d1r2/congestimancer)'s `cgmr`,
one job at a time:

```sh
ssh root@nix-builder.local cgmr --needs-mem 8GB --cpu-pressure 25 \
  --mem-pressure 10 --io-pressure 25 --timeout 30m -- true &&
  nix build -j 1 --store ssh-ng://root@nix-builder.local --eval-store auto .#checks.x86_64-linux.agents-stub
```

`--needs-mem` checks total available memory and reserves it, so
concurrent callers do not overbook the machine (a VM check needs about
6 GB); `--timeout` stops waiting rather than block forever. Avoid
`--load` and `--mem`: both are per CPU, so `--load 12` never blocks and
`--mem 8GB` never passes on a 16-core host.

## Files on the builder

Keep this repository's files in one directory on the storage disk, never
in `/tmp` or `/root`:

```text
/mnt/storage/tmp/nix-orca/        scratch, logs, probes, GC roots
```

Add GC roots there with `nix-store --add-root <dir>/<name> -r <path>`.
When the tmpfs fills (a killed build leaves its directory in
`/nix/var/nix/builds`), `nix-collect-garbage` and removing the dead
build directories frees it.
