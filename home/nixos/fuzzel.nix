# fuzzel — Wayland-native application launcher.
#
# Stylix theming is wired centrally via `stylix.targets.fuzzel.enable
# = true` in home/nixos/stylix-targets-desktop.nix; Stylix writes
# `programs.fuzzel.settings.colors.*` (full base16 palette across 11
# slots) and `programs.fuzzel.settings.main.icon-theme` (polarity-
# driven). We don't override Stylix's colour writes.
#
# Font: mono (Monaspace Argon), set below via mkForce. Stylix's fuzzel target
# writes main.font to the sansSerif slot, but in the hybrid font model the
# launcher rides the mono alongside the terminal (foot) and bar (waybar) —
# Omarchy-style — not the sans. See docs/desktop/fuzzel.md.
#
# Lives under nixos/ because fuzzel is Wayland-only and doesn't
# compile off Linux — same placement reasoning as foot.nix. macOS
# hosts use a native launcher (Spotlight today); a Raycast/Alfred
# selection hasn't been made.
#
# Bind: Mod+Space → fuzzel. Defined in home/nixos/niri.nix
# alongside the rest of the bind set; see docs/desktop/keybinds.md
# for the modifier-namespace philosophy and docs/desktop/fuzzel.md
# for the launcher selection rationale.
#
# Per #73.
{ config, lib, ... }:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  profile = import ../../lib/display-profiles.nix; # active display profile — launcher size
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        layer = "overlay";
        anchor = "top";
        terminal = "foot";

        # Launcher → mono (Monaspace Argon), Omarchy-style — the bar/launcher
        # ride the terminal mono, not the sans. mkForce: Stylix's fuzzel target
        # writes main.font (sansSerif). Size from the active display profile (the
        # launcher is the deliberately-large focal element).
        font = lib.mkForce "${config.stylix.fonts.monospace.name}:size=${toString profile.fonts.launcher}";
      };

      # Border → the "focus" role (base0D) so the launcher frame uses the
      # idiomatic accent slot and matches niri's window border; width + radius
      # from the geometry tokens (shared with niri/fnott). mkForce: Stylix's
      # fuzzel target writes colors.border = base0E. On metis base0D==base0E
      # (per-host 0D/0E override) so the colour is a visual no-op here — correct
      # by slot for portability. fuzzel rode its own default radius (10); pin it
      # to the token so it doesn't diverge once the radius moves off 10. See
      # theme-tokens.nix, docs/desktop/fuzzel.md, and the accent map (#108).
      border.width = tokens.geometry.borderWidth;
      border.radius = tokens.geometry.cornerRadius;
      colors.border = lib.mkForce "${tokens.color.role.focus.hex}ff";
    };
  };
}
