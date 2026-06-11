# fuzzel — Wayland-native application launcher.
#
# Stylix theming is wired centrally via `stylix.targets.fuzzel.enable
# = true` in home/nixos/stylix-targets-desktop.nix; Stylix writes
# `programs.fuzzel.settings.colors.*` (full base16 palette across 11
# slots) and `programs.fuzzel.settings.main.icon-theme` (polarity-
# driven). We don't override Stylix's colour writes.
#
# Font: we DO override Stylix here. Stylix would default fuzzel to the
# sansSerif slot (Inter); instead the whole Wayland chrome uses the one
# mono Nerd Font (JetBrainsMono Nerd Font), so the launcher and the
# power menu match foot and waybar. See docs/desktop/fuzzel.md.
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
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        layer = "overlay";
        anchor = "top";
        terminal = "foot";

        # Mono Nerd Font (monospace slot + popups size), overriding
        # Stylix's sansSerif default so the launcher/menu matches the
        # rest of the chrome. mkForce: Stylix's fuzzel target also
        # writes main.font.
        font = lib.mkForce "${config.stylix.fonts.monospace.name}:size=${toString config.stylix.fonts.sizes.popups}";
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
