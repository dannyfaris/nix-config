# gh-dash — TUI dashboard for GitHub PRs/issues, packaged as a `gh` CLI
# extension. This file is the implementation; the decision (host gate,
# Stylix base16 bridge, "ENHANCE" companion skipped) is recorded
# canonically in ADR-006 §"gh-dash". Imported via the git-multi-identity
# bundle so it rides on programs.gh and stays off mercury.
#
# The theme block maps to ANSI-16 index strings so gh-dash follows the
# terminal palette on a conductor flip (ADR-041); gh-dash has no Stylix
# target — see ADR-006 §"gh-dash" → Theming.
_: {
  programs.gh-dash = {
    enable = true;

    # Only the theme is set; everything else (sections, keybindings, pager)
    # is left at gh-dash's own defaults. Each colour field is individually
    # optional and falls back to a gh-dash default if unset — the full set
    # is given here purely for complete palette coverage.
    # gh-dash 4.24.1 accepts bare ANSI index strings "0"–"255"; lipgloss v2
    # emits classic SGR for 0–15, so these are palette-relative (ADR-041).
    settings.theme.colors = {
      text = {
        primary = "15"; # bright-white — default foreground (base05)
        secondary = "8"; # bright-black — dim text (base04, collapses onto muted)
        inverted = "0"; # black — label/status backgrounds (base01, structural)
        faint = "8"; # bright-black — comments / muted (base03)
        warning = "1"; # red — base08
        success = "2"; # green — base0B
      };
      background.selected = "0"; # black — selection bg (base02, first pass)
      # focus → 4 (blue), muted → 8 (bright-black), structural → 0 (black).
      border = {
        primary = "4"; # blue — focus role (base0D)
        secondary = "8"; # bright-black — muted role (base03)
        faint = "0"; # black — hairline separators (base01, structural)
      };
    };
  };
}
