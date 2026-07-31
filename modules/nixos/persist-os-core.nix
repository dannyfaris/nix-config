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
# timesync,rfkill,linger} (regenerate or re-derive; linger IS relied on and
# is declarative — modules/nixos/docker.nix), lastlog status (no functional
# loss), /etc/credstore* (empty systemd scaffolding),
# /var/lib/{machines,portables} (systemd recreates; nested subvolumes ride
# archives per the design note).
#
# The class rule (learned from #553): nothing read BEFORE the stage-2 mount
# units may ride an impermanence FILE bind — an impermanence file entry is a
# bind mount established during stage-2 activation, invisible to anything that
# runs earlier. Early-boot-read state must therefore live PHYSICALLY on a
# neededForBoot filesystem, not on a bind. Two such entries left this module's
# `files` set for that reason: the SSH host keys (sops-nix reads them in early
# boot to decrypt neededForUsers secrets → modules/nixos/sshd.nix, keys placed
# directly on /persist) and /etc/machine-id (read in the initrd before any
# bind → modules/nixos/ephemeral-root.nix, copied by the stage-1 leg and
# seeded on fresh hosts by a stage-2 oneshot).
#
# A second class rule (learned adjudicating alcyone's first drift report):
# state whose owner writes it temp-file-then-rename(2) may not ride a FILE
# bind either — rename onto a bind mountpoint fails EBUSY, so the persisted
# copy freezes and the writer errors on every run. Such state likewise lives
# physically on /persist: logrotate's rotation ledger (third entry, below)
# is repointed there via --state rather than bind-mounted.
{ config, lib, ... }:
{
  environment.persistence."/persist" = lib.mkIf config.persist.enable {
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

  # Rotation-time ledger, physically on /persist per the second class rule
  # (logrotate writes it temp-file-then-rename — a file bind would EBUSY).
  # /var/log persists above, so the ledger deciding its rotation must share
  # its lifetime: wiped, the rotation clock resets every boot and surviving
  # logs never rotate on hosts that reboot inside the rotation window.
  services.logrotate.extraArgs = lib.mkIf config.persist.enable [
    "--state"
    "/persist/var/lib/logrotate.status"
  ];
}
