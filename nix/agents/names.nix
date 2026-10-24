# Every agent id nix/agents can offer (§C), static: the NixOS module makes
# one option per id, and options cannot depend on pkgs. `openclaw` is
# offered only on request (`extra`), never in orca-ide-agents.
{
  default = [
    "claude"
    "codex"
    "gemini"
    "pi"
    "grok"
    "mistral-vibe"
    "opencode"
    "aider"
    "goose"
    "amp"
    "crush"
    "cursor"
    "copilot"
    "kiro"
    "qwen-code"
    "rovo"
    "codebuff"
  ];
  extra = [ "openclaw" ];
}
