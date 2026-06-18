# Noctalia Shell — cohesive Wayland desktop shell on the Linux desktop
# (ADR-036, #385). v4 Quickshell line via the flake's home-manager module
# (`inputs.noctalia`, pinned to `legacy-v4`).
#
# The shell + its binary are spawned from niri (`spawn-at-startup` in
# home/nixos/niri.nix). The launcher keybind cutover is done (PR-3);
# waybar/fuzzel/fnott and swaylock+swayidle were all decommissioned in #385 —
# Noctalia owns the bar, launcher, notifications, lock, and idle (lock-on-idle +
# displays-off via its IdleService). External theming (foot/gtk/yazi/niri via
# Noctalia's built-in templates) is enabled at runtime by the operator and is
# not Nix-pinned — see ADR-036 and docs/desktop/noctalia.md.
#
# Two upstream quirks the wiring depends on (verified against legacy-v4):
#   - the HM module installs the binary only when `package` is set
#     (`home.packages = lib.optional (cfg.package != null) cfg.package`), so
#     the package is wired explicitly from the flake input here;
#   - the module ships an opt-in systemd unit (deprecated upstream) — left
#     off; the compositor spawns the shell instead.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  # notify-send (libnotify) — the CLI for emitting test notifications to
  # Noctalia, which now owns org.freedesktop.Notifications. Re-homed here
  # from the decommissioned fnott.nix (#385); pairs with Noctalia as daemon.
  #
  # wl-clipboard (wl-copy/wl-paste) — CLI clipboard access on the session
  # PATH. Noctalia owns clipboard (its cliphist watcher uses wl-clipboard
  # from its own wrapper PATH), but that copy isn't on the interactive
  # PATH, so non-OSC-52 consumers that shell out to wl-copy (gh-dash's `y`,
  # scripts) found no utility. Surfaced session-wide here, with the
  # clipboard owner. See docs/desktop/clipboard.md (#360).
  home.packages = [
    pkgs.libnotify
    pkgs.wl-clipboard
  ];
}
