# lock-before-sleep — a logind sleep delay-inhibitor bridged to user-level
# systemd targets (nixpkgs systemd-lock-handler), so the home-side
# noctalia-lock-on-sleep oneshot (home/nixos/noctalia.nix) provably completes
# before ANY suspend proceeds — idle-fired, `systemctl suspend`, or a future
# power-key. Restores the "lock before sleep regardless of trigger" guarantee
# the v4 shell gap relaxed; a hand-rolled system-level Before=sleep.target
# unit was rejected as racy (#644, docs/design/noctalia-v5-migration.md
# §Design; runtime-proven by probe S5's journal ordering).
{
  services.systemd-lock-handler.enable = true;
}
