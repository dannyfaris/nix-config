# zen-browser — Firefox-derived browser with sidebar-first chrome,
# workspaces, essentials, and split-view. Under audit on metis
# alongside Firefox per #127.
#
# The HM module shape (`programs.zen-browser`) comes from the
# 0xc000022070/zen-browser-flake input, imported below via
# `inputs.zen-browser.homeModules.default` (which aliases the `beta`
# release stream). `inputs` reaches this file via the HM
# `extraSpecialArgs` wiring in modules/nixos/home-manager.nix.
#
# Stylix theming is wired centrally via
# `stylix.targets.zen-browser = { enable = true; profileNames = [ "default" ]; }`
# in home/shared/stylix-targets.nix. Both fields are required:
# `enable` because foundation sets `stylix.autoEnable = false`
# (whitelist stance per CLAUDE.md); `profileNames` because Stylix's
# Zen module cannot auto-detect profile names without infinite
# recursion (same module-system limitation as Firefox's target).
# Stylix writes per-profile font.name prefs, reader-mode colours,
# `userChrome.css` (full base16 mapping into Zen's own
# `--zen-*` variable surface), and `userContent.css` (base16 mapping
# for Zen's `about:` pages). `enableCss = true` is the upstream
# default and intentionally not restated; setting it false would
# defeat the audit.
#
# Lives under home/nixos/ because the audit is metis-only and the
# desktop-env bundle placement is Linux-only. (The upstream flake
# does ship an `aarch64-darwin` build + Darwin-aware HM-module
# branches, so the placement decision can be revisited if Zen earns
# a multi-host footprint.)
#
# MIME registration is deliberately NOT touched here — Firefox stays
# the default URL handler (see home/nixos/firefox.nix's
# `xdg.mimeApps.defaultApplications`) during the audit so
# `xdg-open` behaviour is predictable. Zen is launched manually from
# fuzzel for evaluation. If Zen displaces Firefox at #127's decision
# point, the MIME block migrates from firefox.nix to this file
# alongside removing firefox.nix.
#
# See docs/desktop/zen.md for the full selection rationale and sharp
# edges (community-flake binaries, release cadence, Stylix CSS vs
# Zen Mods interaction, font-size asymmetry vs Firefox).
#
# Per #127.
{ inputs, ... }:
{
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    profiles.default = {
      id = 0;
      isDefault = true;
    };
  };
}
