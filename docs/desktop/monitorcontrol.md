# MonitorControl

DDC/CI control for external displays — brightness, volume, and contrast over the video link — with the **native macOS OSD** and Apple-key binding (F1/F2 brightness, the volume keys). Picked because `mac-mini` drives an **LG UltraFine over HDMI**, and macOS exposes no native brightness or volume control for a third-party display on HDMI: the brightness keys are inert and the menu-bar volume slider is greyed out. DDC/CI is the only mechanism that restores them (brightness = VCP `0x10`, volume = VCP `0x62`), and MonitorControl is the free / open-source frontend for it.

## Selection

Darwin: `pkgs.monitorcontrol` via [`modules/darwin/monitorcontrol.nix`](../../modules/darwin/monitorcontrol.nix), imported by `hosts/mac-mini/default.nix`. ADR-031's §Boundary rule **nixpkgs-by-default baseline** applies — clause 3 is disqualified (the MAS listing is the software-dimming-only *Lite* build) and no load-bearing clause-2 degradation holds (see Rationale).

This is the **third Darwin runtime to land via nixpkgs** rather than the cask path, after [colima.md](./colima.md) and [utm.md](./utm.md) — and the second nixpkgs-sourced GUI `.app` after UTM. Same shape as both: standalone module, single `environment.systemPackages` line, no Homebrew involvement.

## Rationale

**MAS rejected — clause-3 disqualifier.** The only App Store listing is **MonitorControl Lite**, a deliberately feature-reduced edition that ships *software dimming* only — a gamma/overlay trick that darkens the picture but **cannot drive the panel backlight or DDC volume at all**. The App Store sandbox can't grant the entitlements the hardware-DDC + media-key path needs, so the full feature set ships only via GitHub releases / Homebrew / nixpkgs. A materially-degraded MAS variant is the same disqualifier shape as UTM SE's "slow edition" — clause 3 is rejected regardless of whether the degradation is sandboxed JIT (UTM) or sandboxed hardware access (MonitorControl).

**Cask rejected — no load-bearing clause-2 degradation.** Homebrew's `monitorcontrol` cask points at the same `MonitorControl.<version>.dmg` from upstream's GitHub releases and ships a Sparkle updater. The one candidate for a clause-2 carve-out is **TCC**: MonitorControl needs an Accessibility grant to capture the media keys and show the native OSD, and because a nix-store path changes on every version bump, macOS *may* re-prompt for Accessibility after an update — whereas the cask's stable `/Applications/MonitorControl.app` location preserves the grant. That argument does not clear ADR-031's clause-2 specificity bar for three reasons: (1) the degradation is **uncertain** — MonitorControl is developer-signed and notarized, so macOS keys the TCC grant to the code-signing identity (Designated Requirement), which can survive the path change; (2) it is **mild and recoverable** — DDC control needs no TCC, so the menu-bar sliders keep working and a one-time re-tick of Accessibility restores the keys; (3) the ADR explicitly says *"don't like the nix-managed location alone does not qualify for clause 2"*, and a maybe-it-re-prompts grant is close to that. So the nixpkgs-by-default baseline stands, and the cask is retained only as the documented migration fallback (§Sharp edges).

**nixpkgs path — clean unpack of the official signed app, free / MIT.** `pkgs.monitorcontrol` (4.3.3 — the same version the cask installs) `fetchurl`s the upstream release `.dmg`, `undmg`s it, and copies `MonitorControl.app` into `$out/Applications/` verbatim. There is **no rebuild and no ad-hoc re-sign** — the derivation notes it cannot build from Xcode source, so Apple's developer code-signature is preserved intact (exactly what a media-key-capturing app needs to satisfy Gatekeeper and TCC). The upstream `.dmg` is notarized by the project, so first launch should be clean — though that notarization isn't independently re-verified here. The package is MIT-licensed and `available` under the default config, so it needs **no `allowUnfreePredicate` entry** (unlike `pkgs.lunar` and `pkgs.betterdisplay`, both unfree). nix owning the version also retires the Sparkle `SU*` keys ceremony that the cask path would require.

## Alternatives considered

**MAS — MonitorControl Lite** (software-dimming only). Rejected at the clause-3 disqualifier; cannot drive the backlight or DDC volume.

**Homebrew cask `monitorcontrol`** — viable mechanism, same upstream `.dmg`. Carved out because the only clause-2 candidate (TCC re-grant on store-path change) is uncertain and mild, and nixpkgs is free + declarative + drops the Sparkle agent. **Retained as the migration fallback** if the Accessibility re-grant turns out to fire on every bump and annoy — a one-line module flip (see §Sharp edges).

**`pkgs.lunar`** — more powerful LG-specific DDC handling, a software-dimming fallback, and a real CLI. Rejected as the default because it is **unfree** (evaluates `available: false` under the repo's default config → would need an `allowUnfreePredicate` entry, against the tight-allowlist stance) and freemium (full features are paid). Reconsider only if MonitorControl's DDC proves inadequate for this LG.

**`pkgs.betterdisplay`** — the community's go-to when MonitorControl's DDC won't bind over HDMI on Apple Silicon, plus HiDPI / virtual-display features and a CLI. Also **unfree** + freemium → same allowlist cost. **Documented as the escalation** if MonitorControl cannot drive this LG over the Mac mini's HDMI port (see §Sharp edges).

**`pkgs.m1ddc` + Hammerspoon** — the pure-CLI route: bind keys in `home/darwin/hammerspoon.nix` to `m1ddc set luminance/volume`, reusing Hammerspoon's existing Accessibility grant (no new TCC app), no GUI. MIT, aarch64-darwin. Rejected as the primary because the operator chose the native-OSD GUI experience, but it is the **no-new-TCC alternative** if the GUI route's Accessibility friction bites — and `m1ddc` is a useful scripting tool to keep in mind regardless.

## Configuration

**Module declaration** — `modules/darwin/monitorcontrol.nix`:

```nix
environment.systemPackages = [ pkgs.monitorcontrol ];
```

That is the whole module. The host imports `../../modules/darwin/monitorcontrol.nix` from `hosts/mac-mini/default.nix`. The nixpkgs derivation handles the rest: `MonitorControl.app` lands at `/Applications/Nix Apps/MonitorControl.app` via nix-darwin's system-applications symlinking.

**First-run grant (one-time).** Launch MonitorControl, then System Settings → Privacy & Security → **Accessibility** → enable MonitorControl. This is what lets it intercept the Apple brightness/volume keys and show the native OSD. DDC control itself (the menu-bar sliders) works without it — Accessibility is only for the key capture.

## Workflow

Launch from Spotlight / Launchpad (`Cmd-Space` → "MonitorControl"). The menu-bar item gives per-display brightness / volume / contrast sliders, and once Accessibility is granted the Apple brightness keys (F1/F2) and the volume keys drive the LG with the native macOS OSD.

For the LG UltraFine over HDMI specifically: **brightness over DDC works**; **volume is the display-dependent half** — see §Sharp edges if the volume slider is inert.

## Update behaviour

**nixpkgs flake bumps.** MonitorControl ships via nixpkgs; updates land on `nix flake update` + `nh darwin switch`. No Sparkle `SU*` keys (nix owns the version; the immutable store path would break Sparkle's in-place self-update anyway — the desired outcome here, not a regression). Same operator-cadence posture as [utm.md](./utm.md) and [colima.md](./colima.md).

## Sharp edges

**TCC / Accessibility re-grant on version bumps.** This is the clause-2 candidate named above. Because the nix-store path changes per version, macOS *may* re-prompt for the Accessibility grant on a `monitorcontrol` bump. The grant is keyed to the (stable) code-signing identity, so it may persist — but this is **empirically unconfirmed on this fleet**. It is mild and recoverable: the DDC sliders are unaffected, and re-ticking Accessibility restores the media-key binding. **If it fires on every bump and becomes an annoyance, migrate to the cask** — replace the `pkgs.monitorcontrol` line in `modules/darwin/monitorcontrol.nix` with a `homebrew.casks = [ "monitorcontrol" ];` entry in `modules/darwin/homebrew.nix`, plus the Sparkle silent-update keys under the app bundle ID (verify on the box — historically `me.guillaumeb.MonitorControl`). The stable `/Applications/MonitorControl.app` path then preserves the grant across the app's own Sparkle updates.

**Volume over HDMI is display-dependent.** The LG UltraFine may not expose the DDC audio-volume control (VCP `0x62`) over HDMI, in which case the volume slider is inert no matter the frontend — this is a property of the panel + HDMI link, not of MonitorControl. Reported workarounds, in order of effort: reseat the HDMI cable and disable the display's energy-saving in macOS; connect via **USB-C → DisplayPort** instead of the Mac mini's built-in HDMI port (Apple-Silicon HDMI-port DDC is the flakiest path, and DP/USB-C is more reliable); or route audio to a software-controllable output (USB DAC, or a software audio device) and leave the monitor's own buttons for its speakers. **Brightness is unaffected** — VCP `0x10` works regardless.

**DDC may not bind over the Mac mini's built-in HDMI port at all.** Apple-Silicon Macs have a documented quirk where DDC over the internal HDMI port intermittently fails to initialize. If *brightness* control (not just volume) doesn't work either, try the USB-C → DisplayPort path first; if DDC still won't bind, escalate to `pkgs.betterdisplay` (a more robust DDC engine), accepting its unfree `allowUnfreePredicate` cost as the named reason.

**App location.** Like UTM, MonitorControl lands at `/Applications/Nix Apps/MonitorControl.app`, not `/Applications/MonitorControl.app`. Spotlight / Launchpad / Cmd-Tab find it; Dock-pinning may occasionally hiccup when the nix store path changes across an update. Gatekeeper should be clean on first launch — the upstream build is notarized (unlike UTM's developer-only signing), though that's per the project and unconfirmed on this fleet, so worst case is a one-time accept-and-open.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) — §Boundary rule nixpkgs-by-default baseline; clause-3 disqualifier for the *Lite* MAS variant; no load-bearing clause-2 degradation.
- [`utm.md`](./utm.md) / [`colima.md`](./colima.md) — sibling Darwin nixpkgs installs (same shape: standalone module, `environment.systemPackages`, no cask).
- MonitorControl upstream — https://github.com/MonitorControl/MonitorControl
- `m1ddc` (MIT CLI sibling) — https://github.com/waydabber/m1ddc
- MonitorControl Lite is software-dimming-only on the MAS — https://github.com/MonitorControl/MonitorControl#readme (and the MAS listing's own description).
- Volume-over-HDMI on LG + Mac mini is display-dependent — MonitorControl discussions [#1597](https://github.com/MonitorControl/MonitorControl/discussions/1597) and [#1742](https://github.com/MonitorControl/MonitorControl/discussions/1742); the Apple-Silicon HDMI-port DDC quirk — [#1301](https://github.com/MonitorControl/MonitorControl/issues/1301).
