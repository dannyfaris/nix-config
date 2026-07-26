# Persist whitelist — OS-core state with no owning repo module.
#
# Module-owns-its-state (docs/design/ephemeral-root.md §Design) places each
# persist declaration beside the module that creates the state; the entries
# here are created by NixOS/systemd themselves, so this module is their
# stand-in owner. Gated on persist.enable (adopting hosts only — see
# modules/nixos/persist.nix); safe to import fleet-wide (impermanence's
# option surface is wired in lib/mk-host.nix).
#
# Deliberately NOT persisted (adjudicated against the first metis inventory,
# 2026-07-26): /var/cache (regenerates), /var/lib/systemd/{catalog,random-seed,
# timesync,rfkill,linger} (regenerate or re-derive; linger becomes declarative
# via users.users.<name>.linger if ever relied on), logrotate/lastlog status
# (no functional loss), /etc/credstore* (empty systemd scaffolding),
# /var/lib/{machines,portables} (systemd recreates; nested subvolumes ride
# archives per the design note).
{ config, lib, ... }:
{
  environment.persistence."/persist" = lib.mkIf config.persist.enable {
    files = [
      # Journal/dbus identity; a fresh one orphans every prior journal file
      # and re-keys anything keyed on the machine (research §4 — the single
      # most-agreed entry in prior art).
      "/etc/machine-id"
    ];
    directories = [
      # uid/gid maps for declarative users — losing it renumbers users and
      # orphans file ownership fleet-wide. The one entry impermanence's own
      # docs call mandatory.
      "/var/lib/nixos"
      # Persistent=true timers (nix-gc, btrfs-scrub, wiki family, the probe
      # itself) read these stamps to catch up missed runs; without them every
      # reboot re-fires everything at once.
      "/var/lib/systemd/timers"
      # Post-mortem artifacts survive the reboot that often follows a crash.
      "/var/lib/systemd/coredump"
      # Journals + wtmp/btmp; the audit trail must outlive the boot.
      "/var/log"
      # sudo lecture stamps — invisible to the probe (tmpfiles-created dir)
      # but real state per the design note's baseline.
      "/var/db/sudo"
      # Root's home: shell history, transient keys, whatever root-context
      # work leaves behind. Omitted from the design note's baseline and the
      # probe's early ignore set — both corrected 2026-07-26; prior art
      # (erase-your-darlings lineage) persists it. Mode matches login.defs.
      {
        directory = "/root";
        mode = "0700";
      }
    ];
  };
}
