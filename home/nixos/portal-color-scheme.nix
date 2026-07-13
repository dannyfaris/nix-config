# portal-color-scheme — the xdg-desktop-portal color-scheme bridge.
#
# The `dconf.settings` declaration that used to live here (writing
# org/gnome/desktop/interface/color-scheme from stylix.polarity on every
# rebuild) is now handled by the gated seed in home/nixos/theme-menu.nix:
# it writes the dconf key ONLY when the family pointer is absent (first-login
# path), so a rebuild never resets a runtime polarity selection. The `theme`
# CLI writes it on every polarity switch. This satisfies both the portal-
# bridge requirement and the R3 polarity-persistence guarantee (ADR-044).
#
# The rationale for why the portal bridge is needed (xdg-desktop-portal-gnome
# reads /org/gnome/desktop/interface/color-scheme; Firefox, libadwaita, and
# GTK4 apps follow it for dark/light) is unchanged — it is single-sourced in
# ADR-044. This file is retained as an import-graph marker so the bundle
# comment in desktop-env.nix still points somewhere. If the module is ever
# folded away entirely, remove both this file and its import from the bundle.
{ }
