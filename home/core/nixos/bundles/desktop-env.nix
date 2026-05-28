# desktop-env — home-manager pieces for the Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #4): bundles
# contain only an `imports` list and no inline option setting. The
# user-facing capabilities the desktop session needs are factored into
# standalone modules beside this file:
#
#   - niri.nix    — programs.niri.settings.binds (Mod+T → ghostty, Mod+Shift+E → quit).
#   - ghostty.nix — programs.ghostty.enable.
#   - dms.nix     — programs.dank-material-shell.{enable, systemd.enable, niri.enableKeybinds}.
#
# First occupant of home/core/nixos/bundles/. The desktop stack is
# Linux-only (DMS, niri, greetd-launched Ghostty all carry Linux paths)
# so per scripts/lint-shared-purity.sh this lives under nixos/, not
# shared/.
#
# The system-side companion bundle is at modules/core/nixos/bundles/desktop-env.nix.
#
# Per ADR-028.
{
  imports = [
    ../niri.nix
    ../ghostty.nix
    ../dms.nix
  ];
}
