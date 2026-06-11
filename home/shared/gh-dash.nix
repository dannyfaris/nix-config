# gh-dash — TUI dashboard for GitHub PRs/issues, packaged as a `gh` CLI
# extension. This file is the implementation; the decision (host gate,
# Stylix base16 bridge, "ENHANCE" companion skipped) is recorded
# canonically in ADR-006 §"gh-dash". Imported via the git-multi-identity
# bundle so it rides on programs.gh and stays off mercury.
#
# The theme block is bridged by hand to the Stylix base16 palette because
# gh-dash has no Stylix target — see ADR-006 §"gh-dash" → Theming.
{ config, ... }:
let
  # Same accessor + semantic mapping the multiplexer/prompt use, so the
  # whole TUI reads from one palette. base05 fg / base04 dim-fg / base03
  # muted / base02 selection-bg / base01 faint-line;
  # base08 red / base0B green / base0D focus-accent (base16 primary; also
  # niri's active-window border).
  c = config.lib.stylix.colors;
  hex = slot: "#${c."${slot}-hex"}";
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
in
{
  programs.gh-dash = {
    enable = true;

    # Only the theme is set; everything else (sections, keybindings, pager)
    # is left at gh-dash's own defaults. Each colour field is individually
    # optional and falls back to a gh-dash default if unset — the full set
    # is given here purely for complete palette coverage.
    settings.theme.colors = {
      text = {
        primary = hex "base05"; # default foreground
        secondary = hex "base04"; # dimmer metadata text
        inverted = hex "base01"; # dark text on label/status backgrounds (≈ upstream #303030 default)
        faint = hex "base03"; # comments / muted
        warning = hex "base08"; # red
        success = hex "base0B"; # green
      };
      background.selected = hex "base02"; # selection background
      # primary/secondary use the focus/muted roles (via theme-tokens); faint is
      # a structural hairline, not a role, so it stays on the hex helper — as
      # does text.faint (base03) above, which reaches the same slot structurally,
      # not as the muted *role*. Labelling both paths keeps the split deliberate
      # (the drift class #369 targets).
      border = {
        primary = hex tokens.color.role.focus.slot; # focused section (focus role)
        secondary = hex tokens.color.role.muted.slot; # unfocused section (muted role)
        faint = hex "base01"; # hairline separators (structural)
      };
    };
  };
}
