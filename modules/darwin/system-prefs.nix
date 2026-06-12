# macOS user-facing system preferences — the GUI knobs the operator
# would otherwise click through in System Settings on every new Mac.
# Single module collects them because they share a mechanism (nix-darwin
# typed wrappers around `defaults write` to the relevant macOS plist
# domains) and a purpose (operator preference, not security posture);
# splitting Dock from Finder from "expand save dialogs" would create
# four micro-modules with no independent purchase.
#
# Scope: Dock, Finder, the two NSGlobalDomain save/print dialog
# expansion knobs, the screensaver password-on-wake pair, the boot
# chime toggle, and the screenshot save location. Power/sleep lives
# in a sibling module (power.nix) —
# distinct concern: operational posture, not UI preference. Touch ID
# for sudo lives in its own module (touch-id.nix) — distinct concern:
# authentication. macOS auto-update lives in its own module
# (system-updates.nix) — distinct concern: vendor update cadence.
# Each is independently opt-out per ADR-027.
#
# Capability per ADR-027 (not foundation): a Darwin host with different
# operator preferences (e.g. a work-policy Mac that mandates icon view
# in Finder) would simply not import this module, or override the
# relevant keys in its own host file. Fleet uniformity is a snapshot
# property.
#
# Most knobs take effect on activation because nix-darwin restarts
# cfprefsd + Dock + Finder. NSGlobalDomain save/print keys take effect
# on next app launch (existing app instances unaffected until restart).
# `system.startup.chime = false` takes effect at next boot.
#
# Selection rationale and verification per-knob:
#   - Dock + Finder: rationale below.
#   - Screensaver lock: paired with Touch ID for sudo
#     (docs/darwin/touch-id.md) — once a fingerprint is enrolled,
#     wake-from-sleep accepts Touch ID automatically. NOTE: this is
#     operator-facing screen lock only — FileVault (at-rest disk
#     encryption) is a separate, orthogonal posture not managed by
#     this module. A host with screen-lock-on but FileVault-off is
#     defended against shoulder surfing but not against physical
#     theft + single-user-mode boot; the two should be considered
#     together if at-rest security matters.
#   - Save/print dialog expansion: kills the macOS default of
#     collapsed dialogs that need an expand-arrow click to reveal
#     the sidebar / detailed options. Tiny win, accumulates over
#     hundreds of save/print interactions per month.
#   - Boot chime: muted on activation; takes effect at next boot. On
#     Apple Silicon some firmware revisions ignore this; the setting
#     is cheap regardless.
#   - Screenshot save location: keeps file captures out of ~/Desktop
#     and into ~/Pictures/Screenshots — the fleet-wide location,
#     matching the niri side's `screenshot-path`. macOS's
#     `screencapture` silently falls back to ~/Desktop if the
#     configured path doesn't resolve, so the directory must exist
#     for the setting to take effect. Directory creation lives in
#     the home-manager module `home/darwin/screenshots-dir.nix`
#     (the directory is per-user, so home-manager is the natural
#     layer; mirrors the `ensureProjectDirs` pattern in
#     `home/shared/git-identity-dual.nix`). The screenshot *chords*
#     (and the file/clipboard swap) live in
#     `modules/darwin/keyboard-shortcuts.nix`.
_:

let
  operator = import ../../lib/operator.nix;
in
{
  system = {
    startup.chime = false;

    defaults = {
      dock = {
        # Auto-hide the Dock; reclaim the screen edge. Companion knobs
        # (autohide-delay, autohide-time-modifier) left at defaults
        # unless the operator opts in.
        autohide = true;
        # Hide the "recents" section — the operator's app surface is
        # declared, not historical-frequency-based.
        show-recents = false;
      };

      finder = {
        # Always show file extensions — extensions are part of the
        # filename, hiding them is a category error.
        AppleShowAllExtensions = true;
        # Default view: column. Best for navigating deep trees, which
        # is the dominant Finder use case on a dev workstation.
        FXPreferredViewStyle = "clmv";
        # Search the current folder by default (SCcf), not the whole
        # Mac. Whole-Mac search remains available via the search-scope
        # dropdown when explicitly wanted.
        FXDefaultSearchScope = "SCcf";
        # Folders sort above files — directory-first navigation is
        # the universal convention every other file manager honours;
        # macOS Finder is the historical outlier.
        _FXSortFoldersFirst = true;
        # New Finder windows open to the home directory, not Recents.
        NewWindowTarget = "Home";
      };

      NSGlobalDomain = {
        # Expand save dialogs by default — the sidebar and the full
        # filesystem tree are visible without the operator clicking
        # the expand arrow.
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        # Expand print dialogs by default — same idea: show the
        # full options panel (paper size, scaling, two-sided) instead
        # of the collapsed single-line summary.
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      screensaver = {
        # Require password (or Touch ID, once a fingerprint is
        # enrolled — see docs/darwin/touch-id.md) immediately on wake
        # from sleep / screensaver. `askForPasswordDelay = 0` means
        # no grace period; the lock is enforced the instant the
        # screen wakes.
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      screencapture = {
        # Save screenshots to ~/Pictures/Screenshots instead of ~/Desktop.
        # Absolute path because `defaults write` doesn't expand `~`
        # and macOS resolves the path literally. The directory is
        # created by the matching home-manager module — see header.
        location = "${operator.darwinHome}/Pictures/Screenshots";
      };
    };
  };
}
