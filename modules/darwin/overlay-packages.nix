# Darwin overlay: AeroSpace 0.21.2-Beta ahead of the nixpkgs pin (0.20.3-Beta).
#
# WHY: upstream AeroSpace shipped 0.21.2-Beta (focus-follows-mouse, shell
# operators, scriptability improvements); nixpkgs-unstable still carries
# 0.20.3-Beta as of 2026-07-13. The operator wants the newer binary now
# rather than waiting for the channel to catch up.
#
# RETIREMENT CONTRACT: the versionGate call inside the overlay body throws
# at eval time once nixpkgs reaches 0.21.2-Beta — a failing `nix flake
# check` (and any host build) signals retirement. Action: drop the
# overrideAttrs block in this file and remove this module's import from
# hosts/neptune/default.nix and hosts/saturn/default.nix.
#
# TCC / ACCESSIBILITY SHARP EDGE: every AeroSpace version bump invalidates
# macOS's Accessibility grant (keyed to the store path + cdhash). After
# `nh darwin switch` the operator must re-grant Accessibility in System
# Settings > Privacy & Security > Accessibility before tiling resumes.
# See docs/runbooks/darwin-bootstrap.md §AeroSpace for the full procedure.
{ lib, ... }:
let
  versionGate = import ../../lib/version-gate.nix { inherit lib; };
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      # Gate fires (throws) once nixpkgs catches up to 0.21.2-Beta; is a
      # no-op while it lags. `prev.aerospace` is the channel version before
      # this overlay, so the comparison is against nixpkgs, not ourselves.
      # `builtins.seq` forces gate evaluation — Nix is lazy and an unforced
      # `let _gate = ...` binding would be silently skipped.
      aerospace =
        let
          gate = versionGate {
            pinned = "0.21.2-Beta";
            channel = prev.aerospace;
            retire = "drop the aerospace overrideAttrs block in modules/darwin/overlay-packages.nix and remove this module from hosts/neptune/default.nix and hosts/saturn/default.nix";
          };
        in
        builtins.seq gate (
          prev.aerospace.overrideAttrs (_old: {
            version = "0.21.2-Beta";
            src = prev.fetchzip {
              url = "https://github.com/nikitabobko/AeroSpace/releases/download/v0.21.2-Beta/AeroSpace-v0.21.2-Beta.zip";
              sha256 = "sha256-+4n9di1NbPs5pttSEHPDzpHinfuSyWSx5CjNA9IOH+Q=";
            };
          })
        );
    })
  ];
}
