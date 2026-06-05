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
  # Make Ghostty's cask-bundled terminfo discoverable by non-Ghostty-
  # launched TUIs. The cask installs its compiled terminfo inside the
  # .app bundle (at the path below), outside the nix-derived
  # TERMINFO_DIRS — so `infocmp xterm-ghostty` fails and gocui/tcell-
  # based tools fatal at startup with a generic
  # `*exec.ExitError exit status 1` (notably lazydocker, see
  # github.com/jesseduffield/lazydocker issues #738 / #724 / #593, all
  # converging on `TERM=xterm-256color` as the workaround). Prepending
  # the cask's path to TERMINFO_DIRS makes xterm-ghostty resolvable
  # natively so the workaround isn't needed.
  #
  # Reassigned (not `set --append`) because fish exports lists with
  # space joins for variable names that don't match its `*PATH`/`*PATHS`
  # auto-path heuristic — and TERMINFO_DIRS doesn't, so `--append` would
  # leak ` <path>` into child envs and break ncurses lookups. Explicit
  # colon-prepend produces a correct PATH-style child env. Guarded by
  # `test -d` so this is a no-op if the cask isn't (yet) installed;
  # merged into the shared fish init in home/shared/shell.nix by the HM
  # module system.
  programs.fish.interactiveShellInit = ''
    set -l ghostty_terminfo /Applications/Ghostty.app/Contents/Resources/terminfo
    # Re-sourcing config.fish (`exec fish` etc.) would otherwise compound
    # the prepend; the contains-guard makes this idempotent. `string join`
    # avoids a trailing colon when $TERMINFO_DIRS is empty (skips empty
    # args).
    if test -d $ghostty_terminfo
        and not string match -q "*$ghostty_terminfo*" -- "$TERMINFO_DIRS"
        set -gx TERMINFO_DIRS (string join : $ghostty_terminfo $TERMINFO_DIRS)
    end
  '';

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
