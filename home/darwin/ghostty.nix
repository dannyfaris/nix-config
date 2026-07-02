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
{
  lib,
  pkgs,
  inputs,
  hostContext,
  ...
}:
let
  # Both polarity variants of the host's scheme couplet, pre-baked so
  # Ghostty can flip with the macOS appearance at runtime — no rebuild.
  # See docs/design/macos-live-theme-switching.md §Design (Class 1).
  schemePair = import ../../lib/scheme-pair.nix {
    inherit
      inputs
      pkgs
      lib
      hostContext
      ;
  };
  # Same slot mapping as the Stylix ghostty target's themes.stylix —
  # kept identical so the dual variants can't drift from what the
  # target would have written for the active polarity.
  mkGhosttyTheme = colors: {
    background = colors.base00;
    foreground = colors.base05;
    cursor-color = colors.base05;
    selection-background = colors.base02;
    selection-foreground = colors.base05;
    palette = with colors.withHashtag; [
      "0=${base00}"
      "1=${base08}"
      "2=${base0B}"
      "3=${base0A}"
      "4=${base0D}"
      "5=${base0E}"
      "6=${base0C}"
      "7=${base05}"
      "8=${base03}"
      "9=${base08}"
      "10=${base0B}"
      "11=${base0A}"
      "12=${base0D}"
      "13=${base0E}"
      "14=${base0C}"
      "15=${base07}"
    ];
  };
in
{
  # Bring Ghostty under Stylix theming, the macOS parallel of foot on
  # metis (home/nixos/stylix-targets-desktop.nix). The target writes
  # the base16 palette into Ghostty's 16 ANSI slots (theme = "stylix"
  # + themes.stylix), plus background/foreground/cursor/selection, and
  # tracks polarity automatically (#256). It also sets font-family
  # (MonaspiceAr Nerd Font + Noto Color Emoji, the faces #209
  # installs system-wide) so TUI glyphs render — desirable.
  #
  # Placement: the enable lives here, colocated with the Ghostty
  # module, rather than in the shared whitelist — and it is the one
  # Stylix target that *survives* the TUI terminal-authority conversion
  # (ADR-041): the terminal is the palette bus the TUIs now follow, so
  # its own theming (palette generation + fonts) stays Stylix-fed.
  #
  # The target stays enabled for its font contribution even though its
  # theme selector is mkForce-overridden below (dual-theme, #499); its
  # themes/stylix file remains as inert dead weight — accepted, see
  # docs/design/macos-live-theme-switching.md §De-risk evidence.
  stylix.targets.ghostty.enable = true;
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

      # Pin font-size back to Ghostty's own macOS default (13pt). The
      # Stylix ghostty target sets font-size = fonts.sizes.terminal *
      # 4/3 to convert Stylix's 72-DPI point size to Ghostty's 96-DPI
      # macOS scaling; with the default terminal size (12) that lands
      # at 16pt — noticeably larger than the .app default. We adopt
      # Stylix's palette and font *family* but keep the operator's
      # established size, so mkForce overrides the target's value.
      # (Ghostty's macOS default is 13, per its Config.zig: "On macOS
      # we default a little bigger since this tends to look better.")
      font-size = lib.mkForce 13;

      # Under AeroSpace (ADR-040), `Hyper+Return` spawns a new Ghostty window
      # via `open -na Ghostty.app`, which starts a new app *instance* per
      # window. Quitting each instance when its last window closes keeps the
      # process count == the open-window count (clean process-per-window)
      # instead of leaving windowless instances lingering until logout. The
      # delay knob is Linux-only, so on macOS this quits immediately — the
      # intended behaviour here.
      quit-after-last-window-closed = true;

      # Native dual-theme: Ghostty follows the macOS appearance signal
      # itself and repaints open windows on a polarity flip — the
      # zero-plumbing half of runtime theme switching (#499). mkForce
      # overrides the Stylix target's single-polarity `theme = "stylix"`
      # (plain assignment upstream, no mkDefault). See
      # docs/design/macos-live-theme-switching.md §Design.
      theme = lib.mkForce "light:stylix-light,dark:stylix-dark";
      window-theme = "system";
    };

    # The pre-baked polarity variants the selector above points at,
    # written to ~/.config/ghostty/themes/.
    themes = {
      stylix-dark = mkGhosttyTheme schemePair.dark;
      stylix-light = mkGhosttyTheme schemePair.light;
    };
  };
}
