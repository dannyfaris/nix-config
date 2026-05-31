# Single source of truth for "what colour is each host". Looked up by
# modules/core/nixos/stylix-palette.nix via hostContext.hostName.
# Missing-host lookups fail loudly at eval (no default fallback —
# Nix's `attr.X` on a missing X throws a clear error).
#
# Visibly-distinct hues per host so SSH'ing between them surfaces a
# palette shift in prompt / Zellij frame / helix / macchina banner — the
# fourth signal layer in the SSH-context awareness stack (issues #4, #6,
# #7, #17 land the other three).
#
# Scheme names match files under ${pkgs.base16-schemes}/share/themes/<name>.yaml.
# Future hosts (mothership, mba, mac-mini) get entries here at bring-up.
{
  nixos-vm = "catppuccin-mocha";
  mercury = "tokyo-night-dark";
  metis = "rose-pine";
}
