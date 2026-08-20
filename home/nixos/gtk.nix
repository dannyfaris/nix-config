# GTK toolkit appearance — the theme, the font, and the two gtk.css
# mount-points Noctalia owns.
#
# Tool-named per docs/taxonomy.md: "GTK" is the universally recognised term
# for what this configures, and any role name for it ("toolkit-theme")
# would be more abstract without being clearer. One neighbour to know
# about: the *icon* theme is set in home/nixos/pointer-icons.nix, co-located
# with the cursor theme it must not drift from (#110).
#
# These are home-manager's own `gtk.*` options, set directly. Until #885
# they were written by Stylix's `gtk` target from the same values; the
# engine has left the NixOS side (ADR-028 §History) and the options it drove
# are first-class HM options, so they are declared here instead. What the
# target did NOT contribute is colour: GTK app colours come from Noctalia's
# own gtk3/gtk4 builtin templates (ADR-048), which is exactly why the
# engine had nothing left to do.
#
# Imported by home/nixos/bundles/desktop-env.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Per-surface sizes come from the display calibration, so they stay
  # coupled to the niri output scale. See lib/display-profiles.nix.
  profile = import ../../lib/display-profiles.nix;

  # `programs.foot.enable` is true only on hosts that import the desktop-env
  # home bundle. The desktop-session proxy: GTK theming is toolkit-level with
  # no per-app gate, so without this a future desktop-less importer would pull
  # adw-gtk3 / gtk+3 (~42 MiB) for chrome it can't render.
  desktopSession = config.programs.foot.enable or false;
in
{
  gtk = lib.mkIf desktopSession {
    enable = true;

    # adw-gtk3 backports libadwaita's look to GTK3, so GTK3 and GTK4 app
    # chrome match instead of splitting into Adwaita-light and libadwaita.
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3";
    };

    # Stated rather than left to the default: HM's `gtk.gtk4.theme` default
    # flips from `config.gtk.theme` to null at stateVersion 26.05, and
    # setting it also silences the deprecation warning that flip announces.
    gtk4.theme = config.gtk.theme;

    # GTK app-UI (the polkit prompt, file pickers, app dialogs) rides the
    # `Sans` fontconfig generic, so it follows the font conductor — and any
    # runtime ~/.config/fontconfig override — like every other surface; today
    # Sans resolves to Inter (#390; docs/desktop/fonts.md). Sized at
    # lib/display-profiles.nix's `popups` slot — the chrome body size (M3
    # body) — so dialogs match the notification body. No package: the
    # conductor's faces install at system level.
    font = {
      name = "Sans";
      size = profile.fonts.popups;
    };
  };

  # Noctalia creates and owns both gtk.css files (its gtk3/gtk4 builtin
  # templates), so home-manager must not declare either path — HM writing
  # one buys a backup collision that wedges activation (#874, ADR-048
  # §History). The gtk-4.0 leg is live: HM's own gtk4 module writes that
  # file whenever `gtk4.theme.package != null`, which the theme above makes
  # true. The gtk-3.0 leg is a standing guard on the same mount-point — HM
  # writes it only for a non-empty `gtk3.extraCss`, which would collide the
  # same way.
  xdg.configFile = lib.mkIf desktopSession {
    "gtk-3.0/gtk.css".enable = false;
    "gtk-4.0/gtk.css".enable = false;
  };
}
