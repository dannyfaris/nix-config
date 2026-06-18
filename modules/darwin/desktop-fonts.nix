# desktop-fonts (Darwin) — install only the font face macOS actually consumes:
# Monaspace Argon Nerd Font, for Ghostty's terminal + Nerd glyphs.
#
# Unlike the NixOS side, Darwin is NOT Stylix-severed (#390 is Linux-desktop
# only): Stylix stays the theme source here, and its ghostty target renders
# Ghostty's font-family from stylix.fonts.monospace (home/darwin/ghostty.nix;
# the operator keeps Ghostty's own size pin). So stylix.fonts.monospace stays.
#
# Nothing else is installed (whitelist > blanket; install only what's
# consumed): macOS native UI is San Francisco, emoji is Apple Color Emoji, and
# nothing on the Mac is fontconfig-aware — so a desktop sans/serif/emoji here
# would be unused weight. There is no fontconfig target (macOS resolves via
# Core Text) and no size mirror (Ghostty owns its sizing).
#
# Imported by foundation.nix — every Darwin host is GUI, so unlike the NixOS
# side (gated behind the desktop-env bundle for headless hosts) there's no
# desktop gate to respect.
#
# Full story: docs/desktop/fonts.md §Darwin. Per #209; trimmed to Monaspace
# under #390.
{ pkgs, ... }:
{
  # Ghostty's face — Monaspace Argon Nerd Font. Stylix's ghostty target renders
  # Ghostty from this slot (see header). sansSerif / serif / emoji are left to
  # Stylix defaults and deliberately NOT installed below — unconsumed on macOS.
  stylix.fonts.monospace = {
    package = pkgs.nerd-fonts.monaspace;
    name = "MonaspiceAr Nerd Font";
  };

  # Install only Monaspace: nix-darwin symlinks it into /Library/Fonts.
  fonts.packages = [ pkgs.nerd-fonts.monaspace ];
}
