# Touch ID for sudo

Operator's authentication shortcut for `sudo` on every Darwin host that
has Touch ID hardware available. On `neptune` the hardware reaches macOS
through the Apple Magic Keyboard with Touch ID; the same wiring carries
over to any future MacBook with built-in Touch ID.
The Apple Watch "approve with Watch" prompt is enabled by the same option as a free side-effect — `pam_tid.so` natively offers the Apple Watch as an approval channel when a paired Watch is present and no fingerprint is given, so `touchIdAuth` alone covers both (nix-darwin's separate `watchIdAuth`/`pam_watchid.so` option is not set here).

## Selection

`security.pam.services.sudo_local.touchIdAuth = true;` and `security.pam.services.sudo_local.reattach = true;`, set in `modules/darwin/touch-id.nix` and imported per-host by Darwin hosts that want it (today: `neptune`, `saturn`). The module is a single-capability standalone per ADR-027 — capabilities, even universally desired ones, do not belong in `foundation.nix`.

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

**`reattach = true` closes the Ghostty/tmux/zellij gap.** Terminal multiplexers (tmux, zellij) and non-Terminal.app terminals (Ghostty) run in a process that has detached from the user's macOS bootstrap session — the session context that `pam_tid.so` requires to call the biometric subsystem. Without `reattach`, `sudo` in those environments silently falls back to a password prompt because the GUI agent is unreachable. `security.pam.services.sudo_local.reattach = true` installs `pam_reattach.so` from `pkgs.pam-reattach` and writes it as the first entry in `/etc/pam.d/sudo_local`, ordered *before* `pam_tid.so` — the ordering matters because `pam_reattach` must re-attach the session before `pam_tid` attempts to contact the biometric agent. **Boundary:** this only helps when a GUI session exists locally. Over SSH there is no bootstrap session to reattach; password fallback is correct and expected there — no change to SSH behaviour.

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

None beyond the existing Touch ID enrolment dialog. `pam_tid.so` is a signed Apple module that interacts with `BiometricKit` through Apple's own entitlements; it doesn't require the operator to add `sudo` to any Privacy & Security pane. The first `sudo` after activation may prompt once for fingerprint, then accepts Touch ID for subsequent invocations within the standard sudo timestamp window.

## Verification

After `nh darwin switch` lands the module:

```bash
cat /etc/pam.d/sudo_local
# Expect to see (pam_reattach.so first, then pam_tid.so):
#   auth       optional       /nix/store/…-pam-reattach-…/lib/pam/pam_reattach.so
#   auth       sufficient     pam_tid.so

sudo -k       # invalidate the existing sudo timestamp
sudo -v       # should prompt with Touch ID, not password
```

`sudo -v` validates the credential cache without running any command, which makes it the safest verification — the macOS Touch ID dialog appears, the operator authenticates, and the cache is refreshed.

**Multiplexer verification (the gap this module closes):** inside a Ghostty window running zellij or tmux, run `sudo -k && sudo -v` — the Touch ID dialog should appear, not a password prompt. This is the canonical check that `pam_reattach.so` is working correctly. Run it in a fresh Ghostty window with a freshly created zellij/tmux session opened after the switch — multiplexer sessions already running were spawned under the pre-reattach bootstrap session and can spuriously fail (same family as the repo's known zellij session-purge gotcha).

If the dialog doesn't appear and a password prompt does instead, either:

1. The fingerprint enrolment is missing — check System Settings.
2. The `sudo_local` file isn't being read by PAM — verify `/etc/pam.d/sudo` includes the line `auth include sudo_local` (Apple's default in Sonoma+; nix-darwin doesn't manage `/etc/pam.d/sudo` itself).
3. Running over SSH — there is no GUI bootstrap session to reattach; password fallback is expected and correct there.

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
Watch-approval check. Operators occasionally hit this when the Watch
auto-locks because the wrist was off-wrist briefly (showers, charging,
etc.) and forget to re-authenticate on the Watch itself.

**Apple Watch unlock and Touch ID racing.** When both are available
(the operator is wearing an unlocked Watch *and* a finger is on the
Touch ID sensor), Touch ID wins by virtue of being a synchronous
modal dialog. The Watch approval prompt only surfaces if no fingerprint
arrives within the standard biometric-timeout window.
