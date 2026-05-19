# AI coding agents — base set: Claude Code + Cursor.
# See docs/decisions/ADR-008-agent-clis.md for rationale.
#
# Imported by every host via the standard home-manager imports list.
# Hosts that also want Codex + Gemini CLI add agent-clis-extras.nix via
# hostContext.extraHomeModules — split per ADR-020's host-divergences-via-
# import-splits convention. Work-only hosts (Mercury) keep only the base.
#
# Both tools authenticate via OAuth login flows on first run:
# `claude login` and cursor-agent's login flow. No sops-managed API keys
# needed — pre-flight verified each tool's primary auth path. If
# non-interactive automation later requires env-var API keys, the
# env-var-via-sops pattern sketched in ADR-008 (sops.secrets file at
# /run/secrets/<name>, sourced by fish shellInit) is the documented
# fallback.
#
# Unfree: cursor-cli is whitelisted in modules/core/nixos/nix-daemon.nix's
# allowUnfreePredicate (alongside claude-code).
{ pkgs, ... }: {
  home.packages = with pkgs; [
    claude-code
    cursor-cli
  ];
}
