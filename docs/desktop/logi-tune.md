# Logi Tune

Logitech peripheral-management app — configures webcam settings (exposure, field of view, Right Sight auto-framing), firmware updates, and video-meeting presets for Logitech webcams and Logi Dock. Installed on Neptune to manage the operator's Logitech webcam.

## Selection

Darwin: Homebrew cask `logitune`, declared in `modules/darwin/homebrew.nix` per [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s **clause 1** (no nixpkgs equivalent on Darwin; not in nixpkgs at all).

Update stance: **silent via Logi Tune's own internal updater** (Homebrew cask marks `auto_updates true`). No `CustomUserPreferences` keys — the updater is not Sparkle; the `SU*` keys do not apply.

## Rationale

**Clause-1 carve-out, no comparison to weigh.** Logi Tune is not packaged in nixpkgs (`nix search nixpkgs logitune` returns nothing; no `pkgs.logi-tune` exists). MAS is rejected at Step 0 — the only App Store listing (ID 1456293789) is iPhone-only; there is no macOS build on MAS. Clauses 2 and 3 have nothing to evaluate.

## Alternatives considered

**MAS** — disqualified at Step 0. The App Store listing (ID 1456293789) is flagged "Only for iPhone"; no macOS build exists on the App Store.

**nixpkgs** — not packaged on any platform. Rejected at Step 1.

**Direct DMG from Logitech** — same binary as the cask source (`software.vc.logitech.com/downloads/tune/LogiTuneInstaller.dmg`), but unmanaged: it is not recorded in Homebrew's receipt database, so it is invisible to `nix-darwin switch` and survives `onActivation.cleanup = "uninstall"` silently. Rejected because the cask path gives the same artifact under declarative control.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "logitune" ];
```

No `CustomUserPreferences` keys — the updater is not Sparkle; the `SU*` keys do not apply.

## Update behaviour

**Default (this config):** Logi Tune's internal updater checks for and installs app and firmware updates automatically in the background. The Homebrew cask's livecheck queries Logitech's release API (`support.logi.com/api/v2/help_center/...`) for version bookkeeping; the runtime updater inside the app handles self-updates independently of Homebrew.

**Fallback if the auto-updater causes issues:** no `defaults`-domain suppression key is known for Logi Tune's updater. The only fallback is an in-app toggle (location varies by version; check Settings or Preferences within Logi Tune) plus operator-cadence updates via `brew update && brew upgrade --cask --greedy logitune`.

## Sharp edges

**Manual installer cask.** `logitune` uses `installer manual: "LogiTuneInstaller.app"` — Homebrew mounts the DMG and runs the bundled installer application rather than copying a `.app` directly. On first `nh darwin switch` after adding the cask, Homebrew will launch the Logi Tune installer GUI. The operator must click through it; the activation blocks until the installer exits. Subsequent `nix-darwin switch` runs should skip the install once the cask receipt is recorded — confirm on first activation that Homebrew does not re-launch the installer GUI on a second switch (idempotency for `installer manual:` casks is less well-defined than for `app` or `pkg` types). No equivalent automation path exists — Logi Tune does not ship a silent-install mode in the cask's public release.

**TCC prompts on first use.** Logi Tune requires Camera access to control webcam settings. macOS will surface a TCC prompt on first launch: System Settings → Privacy & Security → Camera. One-time; not declaratively grantable from nix-darwin.

**LaunchAgent and LaunchDaemon installed by the Logitech installer.** The installer places `/Library/LaunchAgents/com.logitech.logitune.launcher.plist` (user-session agent) and `/Library/LaunchDaemons/com.logitech.LogiRightSight.plist` (the Right Sight auto-framing daemon). These are managed by the Logitech installer/uninstaller, not by nix-darwin. The cask's `uninstall` block removes them on `brew remove` / activation cleanup. Whether a firmware or daemon update from Logi Tune's internal updater causes macOS to re-register the LaunchDaemon and surface an authorization prompt is not confirmed; observe on the first firmware update cycle.

**Bundle ID is `com.logitech.logitune`.** Verified against the upstream cask's `zap` block (`~/Library/Preferences/com.logitech.logitune.plist`).

## Verification

After the first `nh darwin switch` that installs Logi Tune, confirm the expected post-install state:

```bash
# App is in place
ls /Applications/LogiTune.app

# LaunchAgent registered (user-session)
launchctl print gui/$(id -u)/com.logitech.logitune.launcher

# LaunchDaemon registered (system)
launchctl print system/com.logitech.LogiRightSight

# No stray Sparkle keys (none should be present — this confirms the updater is non-Sparkle)
defaults read com.logitech.logitune 2>/dev/null | grep -i "SUEnable\|SUAuto" || echo "no Sparkle keys — expected"
```

**Observation window:** On first launch and on the first firmware update cycle, confirm that no unexpected macOS system-authorization prompts appear beyond the expected one-time Camera TCC prompt. If the auto-updater or a firmware push surfaces admin-permission dialogs outside the app window, adopt the in-app fallback described in §Update behaviour.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — clause 1: no Darwin nixpkgs equivalent; MAS disqualified (iPhone-only).
- Homebrew `logitune` cask source — https://github.com/Homebrew/homebrew-cask/blob/master/Casks/l/logitune.rb
- Logitech Logi Tune product page — https://www.logitech.com/en-us/video-collaboration/software/logi-tune-software.html
