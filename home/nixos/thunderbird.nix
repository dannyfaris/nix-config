# thunderbird — Mozilla's native desktop email client; Gecko toolkit
# (shared with Firefox); native Wayland. The mail client on metis for
# the operator's personal Gmail + iCloud Mail (work M365 stays on
# mac-mini). See docs/desktop/thunderbird.md.
#
# Install only. No `profiles.*` block is declared, so the module's
# one-default-profile assertion (gated on `cfg.profiles != {}`) does
# not fire and Thunderbird creates/manages its own profile on first
# launch. Accounts are runtime/GUI-managed, not Nix-pinned — credentials
# live in Thunderbird's own store, mirroring the Noctalia settings
# posture (see docs/desktop/noctalia.md). The declarative
# `accounts.email` surface exists but is deliberately unused.
#
# Wayland needs no wiring: Thunderbird 128+ is the same Gecko as Firefox
# and auto-detects WAYLAND_DISPLAY at startup, so it launches Wayland-
# native under niri. We deliberately do NOT set MOZ_ENABLE_WAYLAND —
# matching the host's Firefox wiring, where that opt-in is now a no-op
# (see home/nixos/firefox.nix and docs/desktop/firefox.md §Configuration).
#
# Lives under nixos/ for cohesion with the rest of the desktop stack;
# pkgs.thunderbird does build on Darwin, so placement is a stack call,
# not a portability constraint.
#
# Per #388.
_: {
  programs.thunderbird.enable = true;
}
