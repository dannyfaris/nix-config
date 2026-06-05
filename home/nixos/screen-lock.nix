# Screen lock + idle handling for the niri desktop (#97). swaylock as
# the locker, swayidle as the idle daemon. Home-manager-only: swaylock
# authenticates via the `swaylock` PAM service NixOS already ships
# (/etc/pam.d/swaylock present by default), so no system module is
# needed.
#
# Idle policy (balanced): 5 min → lock, 10 min → displays off, and a
# lock before sleep so any resume lands on the lock screen. See
# docs/desktop/screen-lock.md for the selection rationale and the sharp
# edges — notably verifying unlock works before trusting it, since
# metis break-glass is the physical console.
#
# Stylix themes the lock surface via `stylix.targets.swaylock.enable` in
# home/nixos/stylix-targets-desktop.nix (whitelist stance — explicit
# enable; autoEnable is off).
{ config, ... }:
let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock";
in
{
  programs.swaylock.enable = true;

  services.swayidle = {
    enable = true;

    # before-sleep: lock before the system suspends, so resume always
    # requires auth regardless of what triggered the suspend (deliberate
    # suspend triggers are #98). lock: honour logind lock-session
    # requests (e.g. a future "lock now" bind calling loginctl).
    events = {
      before-sleep = "${swaylock} -f";
      lock = "${swaylock} -f";
    };

    # 5 min → lock; 10 min → displays off via niri's DPMS IPC action,
    # restored on resume. `niri` resolves on the session PATH; the action
    # needs NIRI_SOCKET in the service env (see screen-lock.md §Sharp
    # edges if display-off no-ops).
    timeouts = [
      {
        timeout = 300;
        command = "${swaylock} -f";
      }
      {
        timeout = 600;
        command = "niri msg action power-off-monitors";
        resumeCommand = "niri msg action power-on-monitors";
      }
    ];
  };
}
