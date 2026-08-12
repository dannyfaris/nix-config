# desktop-env — home-manager pieces for the macOS desktop workflow.
#
# The Darwin parallel of home/nixos/bundles/desktop-env.nix: the opt-in GUI
# capability a Mac daily driver takes as a unit, named once here rather than
# re-listed module-by-module in every host that wants it. macOS owns the
# desktop itself; these modules customise it — window management, terminal,
# keyboard remap, screenshots, and runtime theme switching.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): only an
# `imports` list, no inline config. The cross-platform interactive core
# (cli-tooling, git-multi-identity, ssh, macchina, agent-clis) is NOT here
# — it's wanted regardless of GUI (a future headless Mac would take the
# core and decline this bundle), so it stays a per-host import, mirroring
# how the Linux desktop-env bundle leaves that core to the host. First
# occupant of home/darwin/bundles/.
#
# The system-side companions (the .app installs, launchd agents, and
# services these user configs pair with) live in modules/darwin/* and are
# imported in each host's system `imports` — see hosts/celaeno.
{
  imports = [
    # Ghostty user config (~/.config/ghostty/config). Cask owns the .app —
    # see modules/darwin/homebrew.nix and docs/desktop/ghostty.md.
    ../ghostty.nix
    # Karabiner-Elements karabiner.json (~/.config/karabiner/karabiner.json).
    # Cask owns the .app + DriverKit system extension + launchd jobs; this
    # module owns the declarative remap config. Realizes the Hyper modifier
    # (caps_lock → Ctrl+Opt); the Mission-Control / Space-jump remaps are
    # retired — those chords fall through to the skhd keymap (ADR-047). See
    # docs/desktop/karabiner.md.
    ../karabiner.nix
    # skhd — the hotkey half of the yabai window manager (ADR-047). Chords come
    # from the capability registry; bodies are hand-authored per capability id.
    ../skhd.nix
    # SwiftBar menu-bar Desktop indicator, pushed by yabai's space_changed
    # signal (ADR-047).
    ../swiftbar.nix
    # Declared Mission Control shortcuts skhd synthesizes for space navigation
    # (ADR-047) — they reset across a reboot undeclared, which silently killed
    # 11 of 41 binds.
    ../symbolic-hotkeys.nix
    # Ensures ~/Pictures/Screenshots exists; pairs with screencapture.location
    # in modules/darwin/system-prefs.nix.
    ../screenshots-dir.nix
    # Runtime theme switching (#499, #605): the appearance watcher + hook
    # option, the JankyBorders repaint hook, theme-following wallpaper
    # pools, and the named-theme menu (entry dirs + the `theme` switcher
    # CLI). Ghostty's half is native dual-theme + the menu include in its
    # own module. See docs/design/macos-live-theme-switching.md.
    ../dark-mode-notify.nix
    ../jankyborders-hook.nix
    ../wallpapers.nix
    ../theme-menu.nix
  ];
}
