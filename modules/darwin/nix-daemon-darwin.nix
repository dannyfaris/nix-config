# Darwin-side companion to modules/shared/nix-daemon.nix — owns the
# nix-daemon knobs that nix-darwin expresses differently from NixOS.
#
# Three pieces today:
#
# - `nix.gc.interval` — launchd-style scheduling. NixOS uses
#   `nix.gc.dates = "weekly"` (systemd-calendar string); nix-darwin
#   takes a list of `StartCalendarInterval` blocks (each an attrset of
#   Weekday / Day / Hour / Minute integers). `Weekday = 7` (or
#   equivalently 0) is Sunday in launchd's convention; pinning
#   Hour/Minute keeps the run off-hours.
#
# - `nix.optimise.automatic = true` — scheduled hardlink-dedupe of
#   /nix/store. nix-darwin asserts a narrow nix/lix version window on
#   `nix.settings.auto-optimise-store = true` (the at-write variant the
#   NixOS sibling uses) to guard against race-condition data-corruption
#   bugs in older nix versions; the scheduled `optimise` operation
#   doesn't have the same race window so it's safe across all
#   supported nix versions. Net dedupe is equivalent; just deferred to
#   the scheduled run instead of every write.
#
# - `nix.settings.trusted-users = ["root" "@admin"]` — privilege
#   posture for nix-daemon operations. nix-darwin's upstream default is
#   `root`-only, which is too narrow for any operator Darwin host: the
#   operator runs as an admin user (not root, by macOS design) and
#   needs trusted-user privileges to drive remote builders (e.g.
#   linux-builder), override substituters, or mark paths as trusted.
#   `@admin` is macOS's admin-group shorthand; on a sole-operator Mac
#   it resolves to the operator only. NixOS hosts in this repo don't
#   need an equivalent override — none use remote builders today and
#   upstream's `root`-only default suffices for the wheel-group nix
#   operations the operator does perform there. Posture, not feature:
#   constrains an already-present subsystem (the daemon) rather than
#   enabling one, which is why it lives here next to the other
#   Darwin-side daemon knobs instead of in a capability bundle. Lived
#   inside modules/darwin/linux-builder.nix until 2026-06-05; the
#   coupling read as "linux-builder needs this," but the posture is
#   broader (substituter overrides, path-trust marking).
#
# Sibling to modules/nixos/nix-daemon-nixos.nix.
_: {
  nix = {
    gc.interval = [
      {
        Weekday = 7;
        Hour = 4;
        Minute = 0;
      }
    ];

    optimise.automatic = true;

    settings.trusted-users = [
      "root"
      "@admin"
    ];
  };
}
