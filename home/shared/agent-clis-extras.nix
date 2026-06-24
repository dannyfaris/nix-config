# AI coding agents — opt-in extras: Codex (OpenAI) + Antigravity CLI (Google).
# Companion to agent-clis.nix (the always-on base). Imported via
# hostContext.extraHomeModules on hosts that want the broader set; the
# work-only Mercury host keeps only the base. See ADR-020 for the
# import-split convention.
#
# Both tools authenticate via OAuth login flows on first run: codex's
# "Sign in with ChatGPT" and antigravity's "Sign in with Google" (the `agy`
# binary). No sops-managed API keys needed.
#
# Antigravity CLI replaced Gemini CLI when Google retired the free-tier
# Gemini CLI backend and folded it into Antigravity — see ADR-008
# (2026-06-24 revision) and #433 for the dates and rationale. Codex stays
# Apache-2.0; Antigravity CLI is unfree and whitelisted in
# modules/shared/nix-daemon.nix.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    codex
    antigravity-cli
  ];
}
