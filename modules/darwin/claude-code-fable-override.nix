# TEMPORARY, mac-mini-only, reversible override (delete the file + its
# import line to revert — see REVERSAL below).
#
# Pins `claude-code` to 2.1.170 so Claude Fable 5 shows up in the
# `/model` picker. Fable requires Claude Code >= 2.1.170
# (https://code.claude.com/docs/en/model-config); older CLIs can't
# select it. nixos-unstable was still at 2.1.161 when this landed (the
# weekly bump in #327) — 2.1.170 had only reached nixpkgs master, not
# yet the channel this repo tracks (ADR-030). This bridges that gap on
# this one host until the channel catches up.
#
# Mechanism: an overlay that `overrideAttrs` the pinned nixpkgs
# claude-code, swapping only `version` + `src`. nixpkgs's 2.1.170
# `package.nix` is byte-identical to the pinned channel's (verified by
# diff) — the two differ only in `manifest.json` (the version string +
# per-platform checksums), so grafting the 2.1.170 prebuilt onto the
# pinned build is faithful: same wrapper flags, same install/version-
# check logic. `src` is replaced wholesale (not just `version` bumped)
# because the channel's `manifest.json` carries only the pinned
# version's checksum; the upstream derivation reads `src`'s sha256 from
# that manifest, so a bare `version` bump would fetch the 2.1.170 URL
# with the wrong (stale) hash. Supplying a flat `fetchurl` with the
# 2.1.170 hash sidesteps the manifest entirely. `darwin-arm64` is
# hardcoded: this module is imported only by mac-mini (aarch64-darwin).
#
# useGlobalPkgs = true (modules/darwin/home-manager.nix), so this
# system-level overlay reaches the `pkgs.claude-code` that
# home/shared/agent-clis.nix puts on PATH — no edit to that shared,
# all-hosts file is needed.
#
# REVERSAL: delete this file and its import line in
# hosts/mac-mini/default.nix, then `nh darwin switch`. Or just wait:
# once nixos-unstable advances past 2.1.170, the weekly flake-lock bump
# delivers it fleet-wide and this override becomes redundant (drop it
# then). After activation, select Fable with `/model fable`.
_: {
  nixpkgs.overlays = [
    (_final: prev: {
      claude-code = prev.claude-code.overrideAttrs (_old: {
        version = "2.1.170";
        src = prev.fetchurl {
          url = "https://downloads.claude.ai/claude-code-releases/2.1.170/darwin-arm64/claude";
          sha256 = "e903646d8b7a31882a80ecd27569a27d8ac57b3708745f349709632c84117fdf";
        };
      });
    })
  ];
}
