#!/usr/bin/env bash
# Enforces platform-purity for modules/shared/ and home/shared/.
#
# Wired into the pre-commit framework via parts/checks.nix; the framework
# filters tracked files through the configured `files` regex
# (^(modules|home)/shared/.*\.nix$) and passes the matches as
# positional args.
#
# Files under shared/ must be platform-agnostic: cross-platform Nix
# expressions that evaluate identically on every system. Platform-
# conditional code belongs in the per-platform sibling trees
# (modules/{nixos,darwin}/, home/{nixos,darwin}/). Today
# (2026-05-28) both shared/ trees are clean; this lint is preventative
# — it protects against drift once Darwin hosts onboard and the
# temptation to short-circuit "just one stdenv.isDarwin check" arises.
#
# Patterns flagged (extended-regex alternation):
#   - stdenv.isDarwin / stdenv.isLinux
#   - pkgs.stdenv.isDarwin / pkgs.stdenv.isLinux
#   - (pkgs.)?stdenv.hostPlatform.is(Darwin|Linux)
#   - pkgs.hostPlatform.is(Darwin|Linux)
#     (also incidentally matches config.nixpkgs.hostPlatform.is*, since
#      "nixpkgs" ends in "pkgs" — coverage we want anyway. Don't tighten
#      the prefix anchor without re-adding that case.)
#   - (pkgs.stdenv.)?system == "<arch>-darwin" / ... -linux"
#   - lib.platforms.darwin / lib.platforms.linux
#
# Known limitations (intentionally not flagged):
#   - `inherit (pkgs.stdenv) isDarwin;` followed by bare `isDarwin` use.
#     Too many false positives on the bare identifier.
#   - `with pkgs.stdenv;` exposing bare `isDarwin`. Same.
#   - pkgs.targetPlatform.is* — rare in module code (more common in
#     derivation contexts); add if drift surfaces.
#   - lib.meta.availableOn — typically a filter expression rather than a
#     platform conditional; add if drift surfaces.
#   Platform-purity in those shapes is a reviewer-side concern.
#
# A file matching any pattern is rejected. Override (for legitimate
# one-off platform fallbacks that should still live in shared/) with:
#   git commit --no-verify
#
# See TODO.md §Good→Great / git history for the rationale; ADR-025 for
# this framework.

set -euo pipefail

PATTERNS='stdenv\.isDarwin|stdenv\.isLinux|pkgs\.stdenv\.is(Darwin|Linux)|(pkgs\.)?stdenv\.hostPlatform\.is(Darwin|Linux)|pkgs\.hostPlatform\.is(Darwin|Linux)|(pkgs\.stdenv\.)?system *== *"[^"]*-(darwin|linux)"|lib\.platforms\.(darwin|linux)'

failures=0
for file in "$@"; do
  if matches=$(grep -nE "$PATTERNS" "$file" 2>/dev/null); then
    echo "ERROR: $file contains platform-conditional code (shared/ must be platform-agnostic)." >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
    echo "  → Move platform-specific code to modules/<platform>/ or home/<platform>/." >&2
    failures=$((failures + 1))
  fi
done

if [[ $failures -gt 0 ]]; then
  echo >&2
  echo "$failures shared/ file(s) failed the platform-purity check." >&2
  echo "Override (intentional platform conditional in shared/): git commit --no-verify" >&2
  exit 1
fi

exit 0
