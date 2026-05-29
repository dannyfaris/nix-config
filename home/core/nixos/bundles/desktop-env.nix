# desktop-env — home-manager pieces for the Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #4): bundles
# contain only an `imports` list and no inline option setting. The
# user-facing capabilities the desktop session needs are factored into
# standalone modules beside this file:
#
#   - niri.nix — programs.niri.settings.binds (curated essential set;
#     see docs/desktop/keybinds.md for the full taxonomy).
#   - foot.nix — programs.foot.enable.
#   - fuzzel.nix — programs.fuzzel.enable + launcher behaviour
#     settings (see docs/desktop/fuzzel.md).
#   - fnott.nix — services.fnott.enable (notification daemon;
#     D-Bus-activated; see docs/desktop/fnott.md).
#
# First occupant of home/core/nixos/bundles/. The desktop stack is
# Linux-only (niri, greetd-launched Foot + fuzzel + fnott all carry
# Linux paths) so per scripts/lint-shared-purity.sh this lives under
# nixos/, not shared/.
#
# The system-side companion bundle is at modules/core/nixos/bundles/desktop-env.nix.
#
# Per ADR-028 (amended by ADR-029).
{
  imports = [
    ../niri.nix
    ../foot.nix
    ../fuzzel.nix
    ../fnott.nix
  ];
}
