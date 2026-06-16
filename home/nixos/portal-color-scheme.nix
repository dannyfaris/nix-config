# portal-color-scheme — bridges `stylix.polarity` to the
# xdg-desktop-portal `org.freedesktop.appearance.color-scheme`
# interface via dconf.
#
# Why this exists: the portal implementation in use on metis
# (xdg-desktop-portal-gnome — niri's chosen portal backend) reads
# `/org/gnome/desktop/interface/color-scheme` from dconf and exposes
# its value through the portal API. Apps that query the portal —
# Firefox for both chrome and the web-content
# `prefers-color-scheme` CSS media query, libadwaita apps, GTK4 apps
# via newer GTK builds — use that value to drive their dark/light
# theming.
#
# Stylix DOES write this dconf key — but only via its
# `stylix.targets.gnome` HM target. That target's other config items
# (gnome-shell user-themes extension, gnome-shell.css derivation,
# wallpaper dconf write requiring `stylix.image`) are inappropriate
# on a niri host that doesn't run gnome-shell, so we leave the
# target absent from the desktop whitelist in
# home/nixos/stylix-targets-desktop.nix. This module
# writes the polarity-driven dconf key directly without dragging in
# the gnome-shell-adjacent surface.
#
# Without this bridge, `stylix.polarity = "dark"` (set per #141 +
# the paired-schemes refactor #142) propagates to Stylix's per-tool
# targets (foot, fuzzel, fnott, waybar) and the GTK base16 CSS, but
# NOT to the portal — so Firefox / web-content
# `prefers-color-scheme` queries report no preference and apps
# render in their light defaults. This module closes the gap that
# #141 left unresolved.
#
# Mirrors the polarity → color-scheme mapping in Stylix's own gnome
# target (`modules/gnome/hm.nix` in nix-community/stylix):
#   polarity == "dark"  → "prefer-dark"
#   polarity == "light" → "default"
#   polarity == "either" → "default" (matches Stylix's branch)
#
# Linux-only (dconf doesn't exist on Darwin); lives under
# home/nixos/.
{ config, ... }:
{
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if config.stylix.polarity == "dark" then "prefer-dark" else "default";
}
