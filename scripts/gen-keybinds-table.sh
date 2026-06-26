#!/usr/bin/env bash
# Regenerate the Hyper bindings table in docs/desktop/keybinds.md from the
# capability registry (lib/capabilities.nix). Splices the registry-emitted
# fragment between the BEGIN/END markers — splice-not-rewrite, so the Living
# prose around the table is never touched (ADR-037 rung 3, #457).
#
# Run via `just gen-keybinds`. The keybinds-table CI check fails if the
# committed region drifts from what this would produce.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
doc="docs/desktop/keybinds.md"

# Build the fragment package (resolves to the current host's system).
fragment="$(nix build --no-link --print-out-paths .#keybinds-table)"

# Guard against a silent table-wipe: a non-existent / empty fragment, or a
# multi-line print-out-paths result (which makes "$fragment" an unreadable
# path), would otherwise leave awk's getline loop empty and splice a blank
# region — overwriting the committed table while reporting success.
if [[ ! -s $fragment ]]; then
  echo "ERROR: fragment build produced no readable output: '$fragment'" >&2
  exit 1
fi

# Splice: keep everything outside the markers verbatim; replace the region
# between them with the fragment's contents. Markers are anchored to column 0
# so prose that merely mentions the marker text can't trip the match.
awk -v frag="$fragment" '
  /^<!-- BEGIN GENERATED: hyper-bindings/ {
    print
    while ((getline line < frag) > 0) print line
    skip = 1
    next
  }
  /^<!-- END GENERATED: hyper-bindings/ { skip = 0 }
  !skip { print }
' "$doc" >"$doc.tmp"
mv "$doc.tmp" "$doc"

echo "Regenerated $doc Hyper bindings table."
