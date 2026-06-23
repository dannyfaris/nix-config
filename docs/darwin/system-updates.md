# macOS + App Store auto-update

Operator stance on the OS-and-App-Store update channels Apple owns:
both auto-install, both fully unattended. The reasoning is identical
to the Sparkle silent-update stance applied to per-app casks in
`modules/darwin/homebrew.nix` (see Ghostty / Tailscale / Typora /
ChatGPT in that module) — the security-load-bearing path is "the
binary stays current," not "the operator chooses which release
notes to read."

## Selection

`modules/darwin/system-updates.nix`:

- `system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;`
  — first-class nix-darwin option. Covers macOS point releases and
  security responses (RSR).
- `system.defaults.CustomUserPreferences."com.apple.commerce".AutoUpdate = true;`
  — App Store apps auto-download.
- `system.defaults.CustomUserPreferences."com.apple.commerce".AutoUpdateRestartRequired = true;`
  — App Store apps that need a restart-to-install auto-install
  without prompting.

Standalone module imported per-host (`hosts/neptune/default.nix`).
Not in foundation per ADR-027 — auto-updates are a capability, not a
posture: a host with audit/compliance constraints could legitimately
want manual control.

## Rationale

neptune is the operator's personal daily driver and the always-on
SSH-target for the rest of the fleet. Update friction translates
directly into "I'll do it later," which on a security-load-bearing
host (neptune hosts a Chrome with Keystone, a 1Password, an SSH
server) is the wrong default. The operator's existing stance for
cask-managed apps via Sparkle (silent download + silent install,
documented in the Sparkle silent-update header section of
`modules/darwin/homebrew.nix`) extends naturally to the two update
channels Apple owns end-to-end.

**Why `com.apple.commerce` (not `com.apple.SoftwareUpdate`) for App
Store updates.** Apple's `softwareupdate(8)` machinery has two
distinct surfaces:

- `com.apple.SoftwareUpdate` — System Settings → General → Software
  Update. Covers macOS itself: OS updates, security responses,
  XProtect, MRT, configuration data, system files. nix-darwin
  exposes the user-facing knob as
  `system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates`.
- `com.apple.commerce` — the back-end Apple's *App Store* uses for
  purchases and updates of MAS-distributed apps. The toggle in
  System Settings → App Store → "Automatic Updates" writes
  `com.apple.commerce` `AutoUpdate`, not anything under
  `com.apple.SoftwareUpdate`. This is observable with
  `defaults read com.apple.commerce` after flipping the toggle.

nix-darwin does *not* expose `com.apple.commerce` as a first-class
options module — there's no
`system.defaults.commerce.AutoUpdate` or similar. The
`system.defaults.CustomUserPreferences` escape hatch is the standard
path; precedent already in the repo at the `CustomUserPreferences`
block in `modules/darwin/homebrew.nix` (the Sparkle silent-update
keys per app bundle ID). Same shape applies here, just for an Apple
domain rather than a vendor's.

**`AutoUpdateRestartRequired` semantics.** macOS distinguishes two
classes of MAS update: those installable while the app is running
(most), and those requiring the app to quit or the system to restart
(occasionally — system extensions, kernel-adjacent helpers, certain
Microsoft Office point releases). Without
`AutoUpdateRestartRequired = true`, restart-required updates queue
up and prompt the operator the next time they open System Settings.
With it set, those updates install during the next App Store update
pass without operator interaction. The setting is the difference
between "updates appear to silently install" and "*all* updates
silently install," and is the right choice given the operator's
auto-update-everything stance.

## What this does NOT cover

- **Homebrew cask / nixpkgs / Sparkle.** Per-app vendor updaters
  (Sparkle for Ghostty / Tailscale / Typora / ChatGPT, Keystone for
  Chrome / Gemini, the in-app electron updaters for Obsidian /
  Cursor / Fellow / Wispr Flow, the ToDesktop updater for Cursor)
  are configured per-cask in `modules/darwin/homebrew.nix`. See
  ADR-031 §"Update mechanism stance" and the per-app docs under
  `docs/desktop/`.
- **Mac App Store *installations*.** What apps to install via MAS is
  declared in `homebrew.nix:masApps`. This module only flips the
  auto-update toggle for the apps already installed.
- **`nix flake update` / Nix store updates.** Nix's update cadence
  is operator-driven via `nh darwin switch` after a flake bump.
  Out of scope for an "Apple system updates" module.
- **XProtect / MRT / Apple security responses.** These piggyback on
  the `com.apple.SoftwareUpdate` channel that
  `AutomaticallyInstallMacOSUpdates` covers; no separate wiring
  needed.

## Manual-control fallback

If a future situation calls for manual update control (e.g. enrolling
in a beta seed, debugging a regression, freezing during a critical
project) the override path is to disable just the relevant key, not
to un-wire the module. From `hosts/neptune/default.nix` or a
host-specific override:

```nix
# Temporarily disable App Store auto-update during the X migration.
system.defaults.CustomUserPreferences."com.apple.commerce".AutoUpdate = false;
```

The override sets the same key the module would otherwise set;
nix's last-write-wins module merging takes care of the rest. No need
to drop the import; the module stays in the import list and the
override sits in the host file with a comment explaining the
freeze.

## Verification

After `nh darwin switch`:

```bash
defaults read com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates
# Expect: 1

defaults read com.apple.commerce AutoUpdate
# Expect: 1

defaults read com.apple.commerce AutoUpdateRestartRequired
# Expect: 1
```

Cross-check by opening System Settings → General → Software Update.
The "Automatic updates" detail panel should show all three sub-toggles
on (Check for updates, Download new updates when available, Install
macOS updates). The App Store auto-update toggle in System Settings
→ App Store should also reflect on.

## Sharp edges

**`AutoUpdateRestartRequired` is observable on the App Store side
only.** There's no surfaced user-facing toggle for "auto-install
restart-required App Store updates" in macOS Sequoia's System
Settings — Apple removed the explicit checkbox a few versions ago.
The key still works; it's just no longer surfaced in the UI. If the
operator later wonders why MAS restart-required updates are
auto-installing without prompting, this doc is the explanation.

**`AutomaticallyInstallMacOSUpdates` does not bypass major-version
upgrades.** macOS 15 → 26 (Tahoe) and equivalent major releases
require explicit operator action regardless of this setting. The
key covers point releases, security responses, and configuration
data updates within a major version — exactly the "weekly CVE
patch" class of update where unattended install matters most.

**Server / unattended hosts.** If a future Darwin host is genuinely
unattended (e.g. CI / build mac mini in a rack somewhere), auto-
install + auto-restart can interrupt long-running tasks. For that
class of host, override `AutoUpdateRestartRequired = false;` in the
host file, deferring restart-required installs to operator-driven
maintenance windows. neptune today is operator-attended, so this
caveat doesn't apply.
