#!/usr/bin/env bash
# Enforces ADR-027 / PRD §8.1 #4 "bundle-purity" on aggregator files
# (foundation.nix plus any bundle under bundles/).
#
# Wired into the pre-commit framework via parts/checks.nix; the framework
# filters tracked files through the configured `files` regex
# (^(modules|home)/[^/]+/(bundles/.*|foundation)\.nix$) and passes the
# matches as positional args.
#
# Rule (ADR-027 §Decision, PRD §8.1 #4):
#   "aggregator files (foundation and bundles) contain an `imports` list
#    of two or more distinct modules and no inline configuration."
#
# Strategy: `nix-instantiate --parse` canonicalises the file to a single
# line (whitespace folded, every list item wrapped in parens, relative
# paths resolved to absolute). The canonical body is exactly
# `{ imports = [ X1 X2 ... Xn ]; }`, optionally wrapped in a function
# header `(<args>: ...)`. Any extra top-level attribute, any inline
# `services.X.enable`, any non-`imports` setting produces text the shape
# regex below refuses. Items are then tokenised paren-balanced (X1 = `(/abs/path)`,
# `(ident)`, `((expr).attr.chain)`, etc.) so we can count them and check
# pairwise distinctness.
#
# Out of scope deliberately: aggregators that wrap their imports list in
# `let ... in` bindings or top-level `assert <cond>;` clauses. ADR-027
# reserves aggregators for pure import composition; a `let`-bound name
# is already a small piece of inline logic and belongs in a wrapped
# standalone module (the same shape stylix-palette.nix uses to keep
# foundation.nix imports-only). If real-world need arises, broaden the
# header capture and update the rule.
#
# Violations:
#   - top-level attrset with any attribute other than `imports`
#   - `imports` value that isn't a list
#   - `imports` list with fewer than 2 entries
#   - `imports` list with duplicate entries
#
# Override (intentional one-off shape deviation):
#   git commit --no-verify
#
# See ADR-027 (bundle-purity, replacing role-purity) and PRD §8.1 #4
# for rationale; ADR-025 for the lint framework.

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

  # Strict shape: `{ imports = [<content>]; }`, optionally inside a
  # function header `(<args>: ...)`. Greedy `.*` in the function-header
  # capture is safe because the only depth-0 `: ` in canonical Nix
  # output is the args→body separator. Greedy `(.*)` for the list body
  # is safe because a well-formed body contains exactly one `]; }`.
  shape_re='^(\(.*: )?\{ imports = \[(.*)\]; \}\)?$'
  if [[ ! $parsed =~ $shape_re ]]; then
    echo "ERROR: $file violates bundle-purity (top-level must be exactly { imports = [ ... ]; } — no inline config, no extra attributes)." >&2
    echo "  parsed: $parsed" >&2
    failures=$((failures + 1))
    continue
  fi

  list_content="${BASH_REMATCH[2]}"

  # Tokenise list items. `nix-instantiate --parse` wraps every list entry
  # in parens (paths → `(/abs/path)`, identifiers → `(ident)`, attribute
  # chains → `((ident).attr.path)`, function calls → `((f arg))`). Walking
  # char-by-char with a paren-depth counter splits cleanly at depth-0
  # close-paren boundaries, regardless of how deep an individual entry nests.
  items=()
  buf=""
  depth=0
  for ((i = 0; i < ${#list_content}; i++)); do
    c="${list_content:i:1}"
    case "$c" in
    "(")
      depth=$((depth + 1))
      buf+="$c"
      ;;
    ")")
      depth=$((depth - 1))
      buf+="$c"
      if ((depth == 0)); then
        items+=("$buf")
        buf=""
      fi
      ;;
    *)
      # Whitespace between items at depth 0 is the separator we split
      # on; only content *inside* a parenthesised item belongs in the
      # buffer.
      if ((depth > 0)); then
        buf+="$c"
      fi
      ;;
    esac
  done

  count=${#items[@]}
  if ((count < 2)); then
    echo "ERROR: $file violates bundle-purity (imports list has $count entries; rule requires ≥ 2 — a single-import aggregator should be inlined at its callsite)." >&2
    failures=$((failures + 1))
    continue
  fi

  unique_count=$(printf '%s\n' "${items[@]}" | sort -u | wc -l)
  if ((unique_count != count)); then
    duplicates=$(printf '%s\n' "${items[@]}" | sort | uniq -d)
    echo "ERROR: $file violates bundle-purity (imports list contains duplicate entries):" >&2
    printf '%s\n' "$duplicates" | sed 's/^/  duplicate: /' >&2
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
