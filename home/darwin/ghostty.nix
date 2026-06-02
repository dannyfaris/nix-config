# Ghostty user config on Darwin. The .app binary itself is installed
# via the Homebrew cask declared in modules/darwin/homebrew.nix
# (ADR-031 clause 1: pkgs.ghostty.meta.platforms is Linux-only).
# This file owns ~/.config/ghostty/config.
#
# See docs/desktop/ghostty.md for selection rationale, the
# auto-update + Sparkle-keys interaction, and verification commands.
#
# Sibling to home/darwin/macchina-shell-init.nix in the home/darwin/
# tree. macOS-only — foot is the chosen terminal on Linux desktop
# hosts per ADR-028 §History.
_: {
  programs.ghostty = {
    enable = true;
    # package=null tells home-manager to skip installing Ghostty into
    # home.packages; the cask owns the .app binary at /Applications/
    # Ghostty.app. HM still writes ~/.config/ghostty/config regardless
    # of the package value, which is all we need from this module.
    package = null;
    settings = {
      # auto-update = "download" is the active source of truth at
      # runtime for Ghostty's update behaviour. Per Ghostty's Swift
      # source (AppDelegate.swift §"Sync our auto-update settings" +
      # UpdateDelegate.swift §"Called when an update is scheduled to
      # install silently"), setting auto-update drives Sparkle's
      # SPUUpdater.automaticallyChecksForUpdates = true +
      # automaticallyDownloadsUpdates = true at runtime, and triggers
      # Sparkle's willInstallUpdateOnQuit delegate hook. Result:
      # silent install on next quit, no operator action.
      #
      # Ghostty's published config docstring for auto-update = download
      # reads "do not automatically install" — inconsistent with the
      # delegate behaviour. Runtime behaviour wins today; the Sparkle
      # SU* keys set in modules/darwin/homebrew.nix are a hedge against
      # Ghostty bringing the runtime in line with the docstring in a
      # future release. See docs/desktop/ghostty.md §Sharp edges.
      auto-update = "download";
    };
  };
}
