# AI coding agents — opt-in extras: Codex (OpenAI) + Gemini CLI (Google).
# Companion to agent-clis.nix (the always-on base). Imported via
# hostContext.extraHomeModules on hosts that want the broader set; the
# work-only Mercury host keeps only the base. See ADR-020 for the
# import-split convention.
#
# Both tools authenticate via OAuth login flows on first run: codex's
# "Sign in with ChatGPT" and gemini's "Sign in with Google". No sops-
# managed API keys needed.
#
# Both are Apache-licensed — no unfree whitelist entry required.
{ pkgs, ... }: {
  home.packages = with pkgs; [
    codex
    gemini-cli
  ];
}
