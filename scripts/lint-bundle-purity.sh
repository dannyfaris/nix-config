#!/usr/bin/env bash
# Enforces ADR-027 / PRD §8.1 #3 "bundle-purity" on aggregator files
# (foundation.nix plus any bundle under bundles/): the top level must be
# exactly `{ imports = [ ... ]; }` (optionally function-wrapped) — an
# imports list and nothing else. No inline option setting, no `config`
# block, no extra top-level attributes.
#
# Wired into the pre-commit framework via parts/checks.nix; the framework
# filters tracked files through the configured `files` regex
# (^(modules|home)/[^/]+/(bundles/.*|foundation)\.nix$) and passes the
# matches as positional args.
#
# Scope (per ADR-032, Rule 1 — proportionate enforcement): this gate
# checks the one load-bearing invariant — pure aggregation, no inline
# config — and stops there. The earlier "≥ 2 imports" and "no duplicate
# entries" checks were removed: duplicate imports are idempotent in Nix
# (not a correctness bug), and forbidding single-module bundles is an
# aesthetic/structural rule a reviewer catches for free. Both survive as
# conventions (ADR-027, PRD §8.1 #3), author/reviewer-enforced rather
# than gated. Dropping them also retired the hand-rolled paren-depth
# tokeniser they required, and the separate self-test harness that
# locked in that tokeniser's behaviour — the "bespoke parser/tokeniser
# is a smell" the proportionate-enforcement rule names. The shape check
# below needs neither.
#
# Strategy: `nix-instantiate --parse` canonicalises the file to a single
# line (whitespace folded, every list item wrapped in parens, relative
# paths resolved to absolute). The shape regex then asserts the canonical
# body is exactly `{ imports = [ ... ]; }`, optionally wrapped in a
# function header `(<args>: ...)`. Any extra top-level attribute, any
# inline `services.X.enable`, any `config` block produces text the regex
# refuses.
#
# Override (intentional one-off shape deviation):
#   git commit --no-verify
#
# See ADR-027 (bundle-purity) and ADR-032 (proportionate enforcement);
# ADR-025 for the lint framework.

set -euo pipefail

failures=0

for file in "$@"; do
  # `--store dummy://` avoids initialising a local Nix store: `--parse`
  # is a pure-text operation and doesn't need one. Without it, running
  # inside a sandbox that lacks /nix/var (e.g. `nix flake check`'s
  # pre-commit derivation) prints a "/nix/var/nix does not exist"
  # warning to stderr and races on a freshly-created SQLite db.
  err_file=$(mktemp)
  if ! parsed=$(nix-instantiate --store dummy:// --parse "$file" 2>"$err_file"); then
    echo "ERROR: $file failed to parse:" >&2
    sed 's/^/  /' <"$err_file" >&2
    rm -f "$err_file"
    failures=$((failures + 1))
    continue
  fi
  rm -f "$err_file"

  # Strict shape: `{ imports = [ <content> ]; }`, optionally inside a
  # function header `(<args>: ...)`. Greedy `.*` in the function-header
  # capture is safe because the only depth-0 `: ` in canonical Nix
  # output is the args→body separator; greedy `.*` for the list body is
  # safe because a well-formed body contains exactly one `]; }`.
  shape_re='^(\(.*: )?\{ imports = \[.*\]; \}\)?$'
  if [[ ! $parsed =~ $shape_re ]]; then
    echo "ERROR: $file violates bundle-purity (top level must be exactly { imports = [ ... ]; } — no inline config, no extra attributes)." >&2
    echo "  parsed: $parsed" >&2
    failures=$((failures + 1))
    continue
  fi
done

if ((failures > 0)); then
  echo >&2
  echo "$failures aggregator file(s) failed bundle-purity check." >&2
  echo "Override (intentional shape deviation): git commit --no-verify" >&2
  exit 1
fi

exit 0
