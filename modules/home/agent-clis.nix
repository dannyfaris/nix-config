# AI coding agents — Claude Code, Codex, Gemini, Cursor.
# See docs/decisions/ADR-008-agent-clis.md for rationale.
# TODO(slice-5e): add codex, gemini-cli, cursor-cli.
{ pkgs, ... }: {
  home.packages = [ pkgs.claude-code ];
}
