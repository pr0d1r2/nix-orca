# nix/sources.json, read and checked (nix T2). The bump script writes the
# JSON and nothing else (nix V3); this file refuses a shape the packages
# do not expect, at evaluation, naming the field.
{ lib }:
let
  sources = lib.importJSON ./sources.json;

  sri =
    algo: field: value:
    lib.assertMsg (lib.hasPrefix "${algo}-" value) "nix/sources.json: ${field} must be an SRI ${algo} hash";

  asset =
    field: a:
    lib.assertMsg (builtins.isString (a.name or null)) "nix/sources.json: ${field}.name missing"
    && lib.assertMsg (builtins.isInt (a.size or null)) "nix/sources.json: ${field}.size missing"
    && sri "sha512" "${field}.hash" (a.hash or "");

  perSystem =
    kind: names: file:
    lib.assertMsg (
      lib.subtractLists [ "teamIdentifier" ] (builtins.attrNames (sources.${kind} or { })) == names
    ) "nix/sources.json: ${kind} must list exactly ${toString names}"
    && lib.all (s: asset "${kind}.${s}.${file}" sources.${kind}.${s}.${file}) names;

  valid =
    lib.assertMsg (builtins.isString (sources.version or null)) "nix/sources.json: version missing"
    && lib.assertMsg (
      sources.tag or null == "v${sources.version}"
    ) "nix/sources.json: tag must be v<version>"
    && lib.assertMsg (
      builtins.match "[0-9a-f]{40}" (sources.commit or "") != null
    ) "nix/sources.json: commit must be the tag's 40-hex commit (round 9)"
    && sri "sha256" "src.hash" (sources.src.hash or "")
    && sri "sha256" "pnpmDeps.hash" (sources.pnpmDeps.hash or "")
    && sri "sha256" "mobilePnpmDeps.hash" (sources.mobilePnpmDeps.hash or "")
    && perSystem "linux" [ "aarch64-linux" "x86_64-linux" ] "deb"
    && lib.assertMsg (builtins.isString (
      sources.darwin.teamIdentifier or null
    )) "nix/sources.json: darwin.teamIdentifier missing (nix/darwin V5)"
    && perSystem "darwin" [ "aarch64-darwin" "x86_64-darwin" ] "zip";
in
assert valid;
sources
