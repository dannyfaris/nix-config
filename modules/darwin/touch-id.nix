# Touch ID for sudo — accept fingerprint (and paired Apple Watch
# approval) in place of password for sudo authentication.
#
# touchIdAuth writes `pam_tid.so` into `/etc/pam.d/sudo_local`; reattach
# prepends `pam_reattach.so` so Touch ID works inside Ghostty/tmux/zellij
# (those terminals detach from the GUI bootstrap session that pam_tid.so
# requires). Apple's `softwareupdate` leaves `sudo_local` alone, so both
# settings survive macOS upgrades without operator intervention. Selection
# rationale, enrolment prerequisite, and sharp edges: see
# docs/darwin/touch-id.md.
#
# Capability, not posture — a Darwin host without Touch ID hardware (an
# older keyboard-less Mac mini, a remote-only headless macOS host)
# would simply not import this module. Lives standalone per ADR-027:
# fleet uniformity is a snapshot property, not a reason to put
# capabilities in foundation. (Single-line standalones are allowed —
# ADR-027 §Decision §2; promotion to a bundle waits on a coherent
# sibling, which doesn't exist yet.)
#
# Fingerprint enrolment is a one-time physical step per Mac
# (System Settings → Touch ID & Password → Add Fingerprint). On
# neptune that's done; on the next Darwin host the bootstrap runbook
# will surface the step.
_: {
  security.pam.services.sudo_local.touchIdAuth = true;
  # Re-attach the terminal to the user's bootstrap session before pam_tid checks
  # it, so Touch ID works inside Ghostty, tmux, and zellij — without this,
  # those terminals detach from the GUI session and sudo falls back to password.
  security.pam.services.sudo_local.reattach = true;
}
