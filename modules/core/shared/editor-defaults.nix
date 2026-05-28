# Default editor for system-mediated tools — sudoedit, visudo,
# systemctl edit, etc. Sudo strips PATH from the inherited environment,
# so we use the absolute store path here. Per ADR-005, helix is the
# chosen editor; this module propagates that into the system layer
# alongside home.sessionVariables.{EDITOR,VISUAL} in
# home/core/shared/editor.nix (the user-shell layer).
#
# Lives under modules/core/shared/ because environment.variables is a
# NixOS option name shared identically with nix-darwin (same semantics
# on both), and pkgs.helix exists on both platforms. shared-purity lint
# passes (no platform conditionals).
{ pkgs, ... }:
{
  environment.variables = {
    SUDO_EDITOR = "${pkgs.helix}/bin/hx";
    SYSTEMD_EDITOR = "${pkgs.helix}/bin/hx";
  };
}
