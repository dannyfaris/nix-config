# AltTab

Windows-style alt-tab window switcher for macOS — surfaces individual
windows (not just app groups) in a single-key chord, with previews,
window-title search, and per-display / per-space filters. Picked
because macOS's native ⌘-Tab switches *apps* not *windows*, and the
operator's muscle memory across Linux (niri on metis) and the
historical Windows years is window-level switching.

## Selection

Darwin: Homebrew cask `alt-tab`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).

Update stance: **Sparkle silent**, same shape as Tailscale, Ghostty,
Typora, and ChatGPT. `SUEnableAutomaticChecks` +
`SUAutomaticallyUpdate` keys wired in `modules/darwin/homebrew.nix`
under bundle ID `com.lwouis.alt-tab-macos`.

## Rationale

**MAS unavailable.** AltTab is GPL3+ and distributed only via the
upstream GitHub releases (and the Homebrew cask that wraps them); no
apps.apple.com listing exists. Rejected at ADR-031 Step 0; clause 3
cannot apply.

**Clause-2 carve-out, framed operationally.** `pkgs.alt-tab-macos` is
available on `aarch64-darwin` and `x86_64-darwin` (verified via
`nix eval nixpkgs#alt-tab-macos.meta.platforms`). The binaries
converge — both paths ship the same upstream
`AltTab-<version>.zip` from `github.com/lwouis/alt-tab-macos/releases`.

The cask is chosen because the nixpkgs Darwin derivation has a
named, load-bearing degradation:

- **Named integration:** AltTab's auto-updater is **Sparkle**
  (verified in upstream `Info.plist`: `SUPublicEDKey`,
  `SUEnableAutomaticChecks=true`, `SUScheduledCheckInterval=604800`
  — weekly default). Sparkle expects `/Applications/AltTab.app` to
  be writable so the in-place update flow can replace the bundle.
  Silent point-release updates are how AltTab ships features and
  bug fixes between flake bumps; upstream cadence is multiple
  releases per quarter (v11.1.0 landed 2026-05-25).
- **Named degradation:** `pkgs.alt-tab-macos` on Darwin installs
  the `.app` under the Nix store — `installPhase = "mkdir -p
  $out/Applications && cp -r *.app $out/Applications"`, so the
  bundle lives at
  `/nix/store/...-alt-tab-macos-X.Y.Z/Applications/AltTab.app`.
  Nix store paths are immutable; Sparkle cannot write to them.
  The derivation does not pre-disable the updater (unlike
  `pkgs.google-chrome` with its `--simulate-outdated-no-au`
  wrapper), so Sparkle would attempt updates at runtime and
  either fail silently or surface error popups. Effective update
  cadence collapses to `nix flake update` + `nh darwin switch` —
  operator-cadence on a tool whose upstream ships multiple
  releases per quarter.
- **Named verification path:** if a contributor wants to flip to
  `pkgs.alt-tab-macos`, verify: (1) AltTab's Sparkle path can be
  cleanly disabled (no error popups, no `Sparkle.framework` retry
  attempts) when the bundle is immutable, (2) operator-cadence
  flake bumps land AltTab updates often enough to be acceptable.
  If both pass, clause 2's degradation premise dissolves and
  ADR-031 Migration trigger 1 applies.

**Update stance — Sparkle silent.** Same shape as Tailscale,
Ghostty, Typora, and ChatGPT: let Sparkle do its job, set the SU\*
keys belt-and-braces so the silent posture is explicit.

## Alternatives considered

**MAS** — not on MAS. Rejected at ADR-031 Step 0.

**`pkgs.alt-tab-macos` on Darwin** — viable mechanism; carved out
on the operational grounds above (Sparkle silently broken by
immutable nix-store path; no pre-disable safety like Chrome has).
Worth revisiting as a follow-up if a contributor lands the
verification path in §Rationale.

**macOS native ⌘-Tab** — app-level not window-level. Doesn't cover
the load-bearing use case (switching between two terminal windows,
or between a Chrome window with docs and a Chrome window with
Slack/Outlook web clients). Functional baseline, not a substitute.

**Rectangle / other window managers** — different problem domain
(window placement vs. window switching). Not weighed against AltTab.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "alt-tab" ];

system.defaults.CustomUserPreferences = {
  "com.lwouis.alt-tab-macos" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
  };
};
```

Bundle ID `com.lwouis.alt-tab-macos` is confirmed against the
upstream cask's `zap` block and the upstream `config/base.xcconfig`
`PRODUCT_BUNDLE_IDENTIFIER`; verify on the live host with
`defaults domains | tr , '\n' | grep -i alt-tab` before treating
the keys as having taken effect.

In-app preferences (key chord, animation speed, per-display /
per-space filters) are not managed declaratively today — set
once via AltTab's Preferences pane after first launch. AltTab
stores them in `~/Library/Preferences/com.lwouis.alt-tab-macos.plist`;
declarative management could land later as a
`system.defaults.CustomUserPreferences` block, gated on the
operator having converged on a stable settings shape.

## Update behaviour

**Default (this config):** Sparkle runs on its vendor cadence
(weekly per the upstream `SUScheduledCheckInterval`) and silently
updates `/Applications/AltTab.app`. No operator action required.

Verify the keys took effect after first activation:

```bash
defaults read com.lwouis.alt-tab-macos SUEnableAutomaticChecks   # → 1
defaults read com.lwouis.alt-tab-macos SUAutomaticallyUpdate     # → 1
```

**Fallback if Sparkle's `/Applications/` writes trigger Mosyle
admin-permission prompts:**

```nix
system.defaults.CustomUserPreferences."com.lwouis.alt-tab-macos" = {
  SUEnableAutomaticChecks = false;
  SUAutomaticallyUpdate = false;
};
```

Then update AltTab manually via
`brew update && brew upgrade --cask --greedy alt-tab`. Same
shape as the Tailscale, Ghostty, Typora, and ChatGPT fallbacks.

## Sharp edges

**TCC prompts on first launch.** AltTab needs **Accessibility**
permission (to register the global hotkey and read window-focus
events) and **Screen Recording** permission (to render window
thumbnail previews). First launch surfaces both as macOS TCC
prompts: System Settings → Privacy & Security → Accessibility,
and → Screen Recording. One-time per Mac; the cask doesn't
auto-grant these, and there's no nix-darwin-declarative path to
grant them (TCC's database is intentionally operator-confirmed).
Without Screen Recording, AltTab still switches windows but
previews are blank.

**`auto_updates true` in the upstream cask is metadata, not
runtime behaviour.** The flag tells Homebrew "this cask
self-updates, don't manage version bumps." Runtime behaviour is
controlled by Sparkle and the SU\* keys above. Same shape as
Typora and ChatGPT.

**No `SUScheduledCheckInterval` override.** Upstream's Info.plist
pins the check interval at 604800 (weekly), distinct from
Sparkle's general "≈daily" default referenced in
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) §Update
mechanism stance. User-defaults written via
`system.defaults.CustomUserPreferences` would override Info.plist
values, but we deliberately do not set this key — upstream's
weekly cadence is acceptable, and silence on the third common
Sparkle key avoids surprising future readers comparing this doc
to the cask source.

**macOS floor.** Upstream's `depends_on macos: ">= :ventura"` for
the v11.x series; not a constraint on mac-mini (current OS) but
relevant for any older Mac considering this cask.

**Hotkey conflicts.** If another window-switcher is installed
(Raycast's window-switcher, Mission Control bindings, a future
Rectangle pane), hotkey conflicts are operator-resolved in
AltTab's Preferences → Controls. Not a packaging concern.

**Bundle ID is `com.lwouis.alt-tab-macos`** (the upstream
maintainer's GitHub handle `lwouis` is part of the reverse-DNS
prefix). Verified against the upstream cask's `zap` block and
`config/base.xcconfig` in the upstream repo.

**Migration candidate to nixpkgs.** Per §Rationale's verification
path: if a contributor lands a clean Sparkle-disable path for
`pkgs.alt-tab-macos` on Darwin (no error popups, no update-retry
loops) AND the nixpkgs version lag closes, the clause-2 carve-out's
premise weakens and ADR-031 Migration trigger 1 may fire.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing AltTab on the Mac via cask under
  clause 2; this doc owns the carve-out justification.
- Homebrew `alt-tab` cask source (Sparkle livecheck against
  `alt-tab.app/appcast.xml`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/a/alt-tab.rb
- Upstream project — https://alt-tab.app/ /
  https://github.com/lwouis/alt-tab-macos
