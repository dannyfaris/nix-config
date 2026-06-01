# NixOS-side companion to `modules/shared/nix-daemon.nix` — owns the
# knobs the cross-platform kernel can't carry:
#
# - `programs.command-not-found.enable` — option exists only on NixOS;
#   nix-darwin has no equivalent. Flakes don't generate the channel-based
#   programs.sqlite index, so leaving the default on silently fails.
# - `nix.gc.dates` — calendar-string syntax ("weekly", "daily") is the
#   NixOS shape (consumed by systemd-timers). nix-darwin's GC uses a
#   structured `nix.gc.interval` submodule keyed off launchd semantics;
#   the Darwin sibling `modules/darwin/nix-daemon-darwin.nix` sets its
#   own equivalent. Putting "weekly" in the shared kernel would fail
#   eval on Darwin.
#
# Imported by `modules/nixos/foundation.nix` alongside
# `modules/shared/nix-daemon.nix`. The `-nixos` suffix parallels the
# planned `nix-daemon-darwin.nix` Darwin sibling.
_: {
  # Flakes don't generate programs.sqlite; leaving this on silently fails.
  programs.command-not-found.enable = false;

  # NixOS GC schedule. Darwin uses `nix.gc.interval` in its own sibling.
  nix.gc.dates = "weekly";
}
