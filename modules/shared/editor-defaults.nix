# Default editor for system-mediated tools. Two variables with two
# distinct mechanisms — they do NOT share semantics across platforms,
# despite both riding the shared `environment.variables` option (#345):
#
#   - SUDO_EDITOR — read by sudoedit/visudo as the *invoking* user before
#     escalation, so it applies on both NixOS and Darwin. Absolute store
#     path because sudo strips PATH from the environment it builds.
#
#   - SYSTEMD_EDITOR — read by `systemctl edit`. Effective only where the
#     caller's environment survives: `systemctl --user edit` and a root
#     login shell (both inherit the value from /etc/set-environment). It
#     is NOT honored by `sudo systemctl edit` — sudo's env_reset drops it
#     (our sudoers env_keep carries only TERMINFO*, no editor vars), so
#     systemctl falls back to vi/nano on that path. That path is rare
#     break-glass on a declarative NixOS box (system units are managed in
#     Nix, not via `systemctl edit`), so we document the limit rather than
#     widen sudoers env_keep for it. On Darwin SYSTEMD_EDITOR is inert
#     dead weight — macOS has no systemd — but it is harmless and dropping
#     it per-platform would need a conditional the shared-purity lint
#     forbids, so it stays.
#
# Per ADR-005, helix is the chosen editor; this module is the system-layer
# companion to home.sessionVariables.{EDITOR,VISUAL} in
# home/shared/editor.nix (the user-shell layer).
#
# Lives under modules/shared/ because `environment.variables` is the same
# option on NixOS and nix-darwin and pkgs.helix exists on both; the
# shared-purity lint passes (no platform conditionals).
{ pkgs, ... }:
{
  environment.variables = {
    SUDO_EDITOR = "${pkgs.helix}/bin/hx";
    SYSTEMD_EDITOR = "${pkgs.helix}/bin/hx";
  };
}
