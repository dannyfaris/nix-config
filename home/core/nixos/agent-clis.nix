# AI coding agents — Claude Code, Codex, Gemini, Cursor.
# See docs/decisions/ADR-008-agent-clis.md for rationale.
#
# All four authenticate via OAuth login flows on first run: `claude login`,
# codex's "Sign in with ChatGPT", gemini's "Sign in with Google", and
# cursor's login flow. No sops-managed API keys are needed — pre-flight
# verified each tool's primary auth path. If non-interactive automation
# later requires env-var API keys, the env-var-via-sops pattern sketched
# in ADR-008 (sops.secrets file at /run/secrets/<name>, sourced by fish
# shellInit) is the documented fallback.
#
# Unfree: cursor-cli is whitelisted in modules/core/nixos/nix-daemon.nix's
# allowUnfreePredicate (alongside claude-code). codex and gemini-cli are
# Apache-licensed.
{ pkgs, ... }: {
  home.packages = with pkgs; [
    claude-code
    codex
    gemini-cli
    cursor-cli
  ];
}
