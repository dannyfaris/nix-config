# desktop-env — home-manager pieces for the macOS desktop workflow.
#
# The Darwin parallel of home/nixos/bundles/desktop-env.nix: the opt-in
# GUI capability both Mac daily-driver hosts (neptune, saturn) share, so
# the composition lives once and can't drift between them. macOS owns the
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
# imported in each host's system `imports` — see hosts/{neptune,saturn}.
{
  imports = [
    # Ghostty user config (~/.config/ghostty/config). Cask owns the .app —
    # see modules/darwin/homebrew.nix and docs/desktop/ghostty.md.
    ../ghostty.nix
    # Karabiner-Elements karabiner.json (~/.config/karabiner/karabiner.json).
    # Cask owns the .app + DriverKit system extension + launchd jobs; this
    # module owns the declarative remap config. Realizes the Hyper modifier
    # (caps_lock → Ctrl+Opt); the Mission-Control / Space-jump remaps are
    # retired (ADR-040 — those chords fall through to AeroSpace). See
    # docs/desktop/karabiner.md.
    ../karabiner.nix
    # AeroSpace window manager (~/.config/aerospace/aerospace.toml + launchd).
    # Owns macOS window management (tiling, workspaces, the Hyper keymap) via
    # the aerospace-action registry emitter. Supersedes the retired
    # Hammerspoon layer (ADR-040). See docs/design/macos-deterministic-tiling.md.
    ../aerospace.nix
    # Ensures ~/Pictures/Screenshots exists; pairs with screencapture.location
    # in modules/darwin/system-prefs.nix.
    ../screenshots-dir.nix
    # Runtime theme switching (#499): the appearance watcher + hook option, the
    # JankyBorders repaint hook, and theme-following wallpaper pools. Ghostty's
    # half is native dual-theme in its own module. See
    # docs/design/macos-live-theme-switching.md.
    ../dark-mode-notify.nix
    ../jankyborders-hook.nix
    ../wallpapers.nix
  ];
}
