# fuzzel — Wayland-native application launcher.
#
# Stylix theming is wired centrally via `stylix.targets.fuzzel.enable
# = true` in home/core/shared/bundles/theming.nix; Stylix writes
# `programs.fuzzel.settings.main.font` (Inter at popups size),
# `programs.fuzzel.settings.colors.*` (full base16 palette across 11
# slots), and `programs.fuzzel.settings.main.icon-theme` (polarity-
# driven). We deliberately don't override Stylix's font/colour
# writes — the settings below are behaviour-only.
#
# Lives under nixos/ because fuzzel is Wayland-only and doesn't
# compile off Linux — same placement reasoning as foot.nix. macOS
# hosts will get their own launcher (Raycast/Alfred) when
# home/core/darwin/ lands per the mac-mini onboarding epic #11.
#
# Bind: Mod+Space → fuzzel. Defined in home/core/nixos/niri.nix
# alongside the rest of the bind set; see docs/desktop/keybinds.md
# for the modifier-namespace philosophy and docs/desktop/fuzzel.md
# for the launcher selection rationale.
#
# Per #73.
_: {
  programs.fuzzel = {
    enable = true;
    settings.main = {
      layer = "overlay";
      anchor = "top";
      terminal = "foot";
    };
  };
}
