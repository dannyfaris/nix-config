# Power, sleep, and recovery posture for Darwin hosts that should stay
# online indefinitely. Three knobs:
#
#   - `power.restartAfterPowerFailure = true;` — host auto-reboots
#     when AC returns after an outage. Essential for the always-on
#     SSH-bastion / builder role mac-mini fills; otherwise a power
#     blip during operator-elsewhere hours leaves the host off until
#     someone walks to it and presses the power button.
#
#   - `power.sleep.computer = "never";` — host never sleeps. The
#     fleet's other hosts (mercury, metis, nixos-vm) SSH into
#     mac-mini for shared-state work; computer sleep would break those
#     flows. nix-darwin's `power.sleep.computer` type accepts either
#     a positive integer (minutes) or the literal "never" — verified
#     against the pinned input.
#
#   - `power.sleep.display` — left unset, taking macOS's factory
#     default (~10 minutes on AC). Display sleep is a power /
#     screen-burn safeguard and is orthogonal to computer sleep: the
#     screen can sleep while the host continues to serve SSH and run
#     scheduled jobs. Paired with the password-on-wake setting in
#     system-prefs.nix (`screensaver.askForPassword = true` +
#     `askForPasswordDelay = 0`) for the screen-lock posture.
#
# Capability, not posture — the values here are wrong for a future
# laptop. `power.sleep.computer = "never"` on a battery-powered Mac
# would shred the battery; `restartAfterPowerFailure` is irrelevant
# on a host whose power supply is "its own battery." Future MacBook
# hosts either:
#   - don't import this module (their host file omits the
#     `../../modules/darwin/power.nix` line), or
#   - import a sibling module (e.g. `power-laptop.nix`) with
#     laptop-appropriate values.
# Either way, the laptop's host file is the boundary; this module is
# never imported by foundation because ADR-027 §"Foundation should
# stay honestly minimal" rejects capability-shaped defaults in
# foundation regardless of current fleet uniformity.
#
# All three knobs translate to `pmset` writes at activation time and
# take effect immediately.
_: {
  power = {
    restartAfterPowerFailure = true;
    sleep.computer = "never";
    # sleep.display intentionally not set — macOS factory default.
  };
}
