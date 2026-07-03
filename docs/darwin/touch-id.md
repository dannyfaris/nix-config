# Touch ID for sudo

Operator's authentication shortcut for `sudo` on every Darwin host that
has Touch ID hardware available. On `neptune` the hardware reaches macOS
through the Apple Magic Keyboard with Touch ID; the same wiring carries
over to any future MacBook with built-in Touch ID. The Apple Watch
"approve with Watch" prompt is enabled by the same option as a free
side-effect — nix-darwin's `touchIdAuth` toggle activates both the
`pam_tid.so` (Touch ID) and `pam_watchid.so` modules.

## Selection

`security.pam.services.sudo_local.touchIdAuth = true;`, set in
`modules/darwin/touch-id.nix` and imported per-host by Darwin hosts that
want it (today: `neptune`). The module is a single-line capability and
sits as a standalone module per ADR-027 — capabilities, even universally
desired ones, do not belong in `foundation.nix`.

## Rationale

`sudo` defaults to password authentication on macOS. Without Touch ID
wiring, every `nh darwin switch`, every `sudo -v`, every script-driven
elevation prompts the operator for the account password. neptune's
day-to-day workload is rebuild-and-activate-heavy; the password friction
is real.

**`sudo_local` vs `sudo` is the load-bearing selection.** Apple
introduced `/etc/pam.d/sudo_local.template` in macOS Sonoma 14.0 as the
*sanctioned* extension point for adding modules to the `sudo` PAM stack.
The previous-generation pattern — editing `/etc/pam.d/sudo` directly to
add `auth sufficient pam_tid.so` — works mechanically but is overwritten
by every macOS update because `/etc/pam.d/sudo` is part of the macOS
system bundle. Operators using the old pattern have to re-edit
`/etc/pam.d/sudo` after every Software Update, which is exactly the
imperative-step-per-mac the rest of #208 exists to eliminate.

nix-darwin's `security.pam.services.sudo_local.touchIdAuth` option writes
to `/etc/pam.d/sudo_local`, which Apple's `softwareupdate` mechanism does
*not* overwrite. The setting therefore survives every macOS upgrade
without operator intervention. That makes it the right choice for a
declarative config: write once, never re-touch.

Naming the module `touch-id.nix` rather than `pam-touchid.nix` or
`sudo-touch-id.nix` is a "most-communicative term" call (taxonomy.md).
"Touch ID" is the user-facing capability and the most discoverable name
when scanning `modules/darwin/` for "where does Touch ID live." If a
future PAM-adjacent concern surfaces (e.g. Touch ID for screen-lock
unlock — currently macOS-automatic, but if nix-darwin ever exposes a
knob), this name still anchors the concept clearly without forcing a
rename.

## Prerequisite: fingerprint enrolment

This option only makes `sudo` *accept* Touch ID. It does not — and
cannot — enroll fingerprints. Enrolment is a one-time physical step per
Mac via System Settings → Touch ID & Password → "Add Fingerprint." On
`neptune`, enrolment uses the Magic Keyboard's Touch ID sensor; the
operator completed this manually before the module landed.

On the next Mac (whichever Darwin host joins the fleet next), the
bootstrap runbook (`docs/runbooks/darwin-bootstrap.md`) will need a
step pointing the operator at the System Settings panel. Without
fingerprint enrolment, the option is inert — `sudo` falls back to
password.

Apple Watch unlock (the "approve with your Apple Watch" prompt) does
not require explicit enrolment per Mac; it depends on the same iCloud
account pairing the operator already has for the Apple ecosystem. If
the Watch is paired and unlocked on-wrist, sudo offers the Watch as an
approval channel automatically once `touchIdAuth = true` is set.

## TCC interactions

None beyond the existing Touch ID enrolment dialog. `pam_tid.so` and
`pam_watchid.so` are signed Apple modules that interact with `BiometricKit`
through Apple's own entitlements; they don't require the operator to
add `sudo` to any Privacy & Security pane. The first `sudo` after
activation may prompt once for fingerprint, then accepts Touch ID for
subsequent invocations within the standard sudo timestamp window.

## Verification

After `nh darwin switch` lands the module:

```bash
cat /etc/pam.d/sudo_local
# Expect to see:
#   # sudo_local: local config file which survives system updates
#   auth       sufficient     pam_tid.so
#   auth       sufficient     pam_watchid.so

sudo -k       # invalidate the existing sudo timestamp
sudo -v       # should prompt with Touch ID, not password
```

`sudo -v` validates the credential cache without running any command,
which makes it the safest verification — the macOS Touch ID dialog
appears, the operator authenticates, and the cache is refreshed. If the
dialog doesn't appear and a password prompt does instead, either:

1. The fingerprint enrolment is missing — check System Settings.
2. The `sudo_local` file isn't being read by PAM — verify
   `/etc/pam.d/sudo` includes the line
   `auth include sudo_local` (Apple's default in Sonoma+; nix-darwin
   doesn't manage `/etc/pam.d/sudo` itself).

## Sharp edges

**Apple Silicon firmware updates can clear `/etc/pam.d/sudo_local`.**
Apple's `softwareupdate` is the documented preserve-this-file path,
but major OS upgrades (e.g. 14 → 15) have occasionally been observed to
reset `/etc/pam.d/` entirely depending on update channel and migration
path. The nix-darwin module re-creates `sudo_local` on every activation,
so the recovery is `nh darwin switch` after a major upgrade. Keep this
in mind if `sudo` reverts to password-only after an OS upgrade — first
suspect is "post-upgrade activation hasn't run yet."

**Apple Watch unlock requires the Watch to be on the wrist AND
unlocked.** A locked Watch on the wrist won't satisfy the
`pam_watchid.so` check. Operators occasionally hit this when the Watch
auto-locks because the wrist was off-wrist briefly (showers, charging,
etc.) and forget to re-authenticate on the Watch itself.

**Apple Watch unlock and Touch ID racing.** When both are available
(the operator is wearing an unlocked Watch *and* a finger is on the
Touch ID sensor), Touch ID wins by virtue of being a synchronous
modal dialog. The Watch approval prompt only surfaces if no fingerprint
arrives within the standard biometric-timeout window.
