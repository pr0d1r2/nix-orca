# The agent CLIs Orca knows that have a nix package (nix/agents), keyed by
# Orca's TuiAgent id (§I). An agent that does not evaluate on a system, by
# platform, by an upstream throw, as unfree or as insecure under the
# caller's config, is left out there rather than failing the set (V2).
# `extra` adds the agents offered only on request (names.nix), for the
# NixOS module's options; orca-ide-agents never has them.
{
  lib,
  pkgs,
  inputs,
  system,
  extra ? false,
}:
let
  fromInput = input: args: pkgs.callPackage "${input}/package.nix" args;

  candidates = {
    # Per-agent flakes, ahead of the pin (D43).
    claude = fromInput inputs.claude-code-nix { };
    codex = fromInput inputs.codex-cli-nix { runtime = "native"; };
    gemini = fromInput inputs.gemini-cli-nix { };
    pi = fromInput inputs.pi-nix { };
    grok = fromInput inputs.grok-build-nix { };
    # Its build imports from a derivation at evaluation, so on x86_64-darwin
    # evaluating it needs an x86_64-darwin builder, which tryEval cannot
    # catch; left out there so every system evaluates from any host (nix V2).
    # nixpkgs' codebuff is a launcher that downloads the real CLI on first
    # run (fails V3 offline); nix-codebuff fetches that CLI by hash.
    codebuff = pkgs.callPackage "${inputs.nix-codebuff}/pkgs/codebuff/package.nix" { };
    mistral-vibe =
      if system == "x86_64-darwin" then
        null
      else
        inputs.nix-mistral-vibe.packages.${system}.mistral-vibe or null;
    # The pin (D43).
    inherit (pkgs)
      opencode
      crush
      qwen-code
      openclaw
      ;
    aider = pkgs.aider-chat;
    goose = pkgs.goose-cli;
    amp = pkgs.amp-cli;
    cursor = pkgs.cursor-cli;
    copilot = pkgs.github-copilot-cli;
    kiro = pkgs.kiro-cli;
    rovo = pkgs.acli;
    # openclaw: on request only. The pin marks it insecure ("uses LLMs to
    # parse untrusted content ... full access to system by default"), so it
    # evaluates only where the consumer lists it in
    # `permittedInsecurePackages` (inherited from the pin above).
  };
  names = import ./names.nix;
  offered = names.default ++ lib.optionals extra names.extra;

  evaluates =
    drv:
    let
      tried = builtins.tryEval (
        drv != null && lib.meta.availableOn pkgs.stdenv.hostPlatform drv && builtins.seq drv.drvPath true
      );
    in
    tried.success && tried.value;
in
assert lib.assertMsg (
  lib.sort lib.lessThan (builtins.attrNames candidates)
  == lib.sort lib.lessThan (names.default ++ names.extra)
) "nix/agents: default.nix and names.nix name different agents";
lib.filterAttrs (_: evaluates) (lib.getAttrs offered candidates)
