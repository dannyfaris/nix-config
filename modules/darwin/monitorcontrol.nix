# MonitorControl — DDC/CI brightness + volume control for external
# displays, with the native macOS OSD. Imported per-host; currently
# only by mac-mini, which drives an LG UltraFine over HDMI — a
# connection macOS gives no native brightness/volume control for
# (third-party display + HDMI = inert brightness keys and a greyed-out
# volume slider; DDC/CI is the only way back).
#
# See docs/desktop/monitorcontrol.md for the full ADR-031 walk. Short
# version:
#
#   - MAS rejected: the only App Store listing is "MonitorControl
#     Lite", a feature-reduced edition that ships *software dimming*
#     only (a gamma overlay) — it cannot drive the backlight or DDC
#     volume at all (the sandbox can't grant the entitlements the
#     hardware-DDC + media-key path needs). Materially degraded vs.
#     the full app; clause-3 disqualifier,
#     same shape as UTM SE's "slow edition".
#   - cask rejected: the `monitorcontrol` cask points at the same
#     GitHub release .dmg and ships Sparkle. Its one clause-2
#     candidate is TCC — the app needs Accessibility to capture the
#     media keys, and the nix-store path changes on each version bump,
#     which *may* force re-granting Accessibility (the cask's stable
#     /Applications path keeps the grant). But the degradation is
#     uncertain (MonitorControl is developer-signed + notarized, so
#     the grant is keyed to the code-signing identity and may survive
#     the path change) and mild/recoverable (DDC sliders keep working;
#     re-tick Accessibility to restore the keys). Per ADR-031's
#     clause-2 specificity bar — "don't like the nix-managed location
#     alone does not qualify" — this maybe-degradation doesn't clear
#     it. nixpkgs-by-default baseline applies; the cask stays
#     documented as the migration fallback if the re-grant proves
#     annoying.
#   - nixpkgs chosen: pkgs.monitorcontrol (4.3.3, MIT, free) on
#     aarch64-darwin unpacks the official notarized .app verbatim from
#     the upstream release .dmg (fetchurl + undmg + cp — no rebuild,
#     no re-sign, so Apple's signature + notarization survive). Its
#     installPhase puts MonitorControl.app under $out/Applications/,
#     surfaced via nix-darwin's system-applications mechanism at
#     /Applications/Nix Apps/MonitorControl.app. Free/MIT means no
#     allowUnfreePredicate entry (unlike pkgs.lunar /
#     pkgs.betterdisplay, both unfree), and nix owning the version
#     drops the Sparkle SU* keys ceremony entirely. No companion CLI
#     ships in the bundle (unlike UTM/utmctl); pkgs.m1ddc is the MIT
#     CLI sibling if a scriptable DDC surface is ever wanted.
#
# Standalone module per ADR-027 (single-package — does not satisfy
# bundle-purity; no coherent sibling yet to graduate into a bundle).
# The host opts in by importing this module.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.monitorcontrol # DDC brightness/volume + native OSD. See
    # docs/desktop/monitorcontrol.md for the install-path rationale
    # and the LG-over-HDMI volume caveat.
  ];
}
