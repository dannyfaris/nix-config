# Version gate — fail-loud retirement trigger for overlay packages.
#
# Usage: call at the top of an overlay body to assert the overlay is still
# needed. While nixpkgs lags behind `pinned` the call is a no-op (returns
# null, which the caller ignores). Once nixpkgs ships `pinned` or newer,
# eval throws — surfacing the retirement action through `nix flake check`
# and any host build rather than silently carrying dead weight.
#
# `throw` (not `lib.warn`) is the repo's fail-loud stance — an overlay
# whose purpose has dissolved should break the build, not emit a dismissable
# warning. Source: issue #515 §closure, community-config-survey.md §7.7.
#
# Args:
#   pinned  — version string the overlay is pinning to (e.g. "0.21.2-Beta")
#   channel — the nixpkgs package to compare against (e.g. prev.aerospace)
#   retire  — human-legible string naming the retirement action
#
# `lib.versionAtLeast` handles "0.21.2-Beta"-style strings: it splits on
# [.-] and compares component-wise, so "0.21.2-Beta" ≥ "0.21.2-Beta" is
# true and any later version is also caught.
{ lib }:
{
  pinned,
  channel,
  retire,
}:
lib.throwIf (lib.versionAtLeast (lib.getVersion channel) pinned)
  "version-gate: nixpkgs now has ${lib.getName channel} ${lib.getVersion channel} (≥ pinned ${pinned}) — ${retire}"
  null
