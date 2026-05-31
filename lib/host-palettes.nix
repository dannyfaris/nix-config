# Single source of truth for "what theme is each host". Looked up by
# modules/nixos/stylix-palette.nix via hostContext.hostName.
# Missing-host lookups fail loudly at eval (no default fallback —
# Nix's `attr.X` on a missing X throws a clear error).
#
# Each entry carries two fields:
#   - scheme — name of a base16 yaml under
#     ${pkgs.base16-schemes}/share/themes/<name>.yaml; supplies the
#     base16 palette every Stylix target downstream reads from.
#   - polarity — "dark" / "light" / "either"; declares the host's
#     dark/light preference so Stylix can write the cross-app signals
#     (GTK's gtk-application-prefer-dark-theme, the xdg-portal
#     color-scheme, adw-gtk3 dark-variant selection). With the
#     default "either", Stylix writes no preference and dark-aware
#     apps (Firefox web content, Zen chrome, GTK file pickers, …)
#     render in their light defaults regardless of how dark the
#     palette is — see #123.
#
# Visibly-distinct hues per host so SSH'ing between them surfaces a
# palette shift in prompt / Zellij frame / helix / macchina banner — the
# fourth signal layer in the SSH-context awareness stack (issues #4, #6,
# #7, #17 land the other three).
#
# Future hosts (mothership, mba, mac-mini) get entries here at bring-up.
{
  nixos-vm = {
    scheme = "catppuccin-mocha";
    polarity = "dark";
  };
  mercury = {
    scheme = "tokyo-night-dark";
    polarity = "dark";
  };
  metis = {
    scheme = "rose-pine";
    polarity = "dark";
  };
}
