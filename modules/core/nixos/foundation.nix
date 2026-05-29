# Foundation — the bundle every NixOS host imports by convention.
#
# Structurally a bundle (governed by the same bundle-purity rule, ≥ 2
# imports, pure aggregation). Distinguished from other bundles only by:
#   - name "foundation.nix" (signals universal-import convention);
#   - placement at the top of modules/core/nixos/ rather than inside
#     bundles/ (discoverability).
#
# Contents: identity (users, sops), administration (nix-daemon, locale,
# baseline system packages), security posture (firewall), the
# home-manager NixOS-module wiring, default editor for system-mediated
# tools, and Stylix theming (per-host palette). Reserved for things
# that aren't opt-in capabilities. A capability — even one every
# current host happens to want — belongs in a capability bundle, not
# here. See ADR-027 and PRD §3.2.
{
  inputs,
  pkgs,
  hostContext,
  ...
}:
let
  palettes = import ../../../lib/host-palettes.nix;
  scheme = palettes.${hostContext.hostName};
in
{
  imports = [
    ./locale.nix
    ./nix-daemon.nix
    ./firewall.nix
    ./sops.nix
    ./users.nix
    ../shared/system-packages.nix
    ../shared/editor-defaults.nix
    ./host-context.nix
    ./home-manager.nix
    inputs.stylix.nixosModules.stylix
  ];

  # Stylix is the single source of truth for theming across both the TUI
  # surface (helix, bat, fzf, starship, zellij, yazi, lazygit, fish) and
  # the metis desktop env (niri + foot, per ADR-028 amended by ADR-029).
  # Per-host base16 palette comes from lib/host-palettes.nix keyed on
  # hostContext.hostName; missing-host lookups fail loudly at eval.
  #
  # autoEnable = false is the whitelist stance per CLAUDE.md "Deliberate
  # stances" — every Stylix target we want is enabled deliberately, not
  # auto-detected. HM-side target enables live in
  # home/core/shared/bundles/theming.nix.
  stylix = {
    enable = true;
    autoEnable = false;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
    # No font configuration here — there is no universal font intent.
    # Headless hosts (mercury, nixos-vm) don't render fonts; SSH
    # clients use their own. Desktop-side font selections + install
    # wiring live in modules/core/nixos/desktop-fonts.nix. See
    # docs/desktop/fonts.md for the full rationale.
  };
}
