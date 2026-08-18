#!/usr/bin/env bash
# Noctalia declared-vs-runtime config audit — the seed-posture visibility
# layer (docs/design/noctalia-config-surface-overlap.md §Design).
#
# Reports, as mechanical facts only (no intent-guessing):
#   FORBIDDEN — sidecar entries under an authoritative key (manifest:
#               home/nixos/noctalia-authoritative-keys.conf). The pre-spawn
#               reconcile removes these at next session start; this audit is
#               the backstop in between.
#   REDUNDANT — sidecar leaves equal to the declared value. Safe to clear,
#               and worth clearing: they silently block future flake changes.
#   DIVERGED  — sidecar leaves differing from declared. Operator judgment;
#               tuned-vs-dragged is NOT machine-decidable and is not guessed.
#   REGISTRY  — GUI-writable paths at the pin vs the checked-in baseline
#               (scripts/noctalia-gui-registry.baseline) — per-bump drift.
#
# Read-only throughout: this script NEVER writes under
# ~/.local/state/noctalia/ or ~/.config/noctalia/. Recovery commands are
# printed for the operator, not executed.
#
# Exit codes: 0 clean or seed-only divergence; 2 forbidden entries found;
# 3 environment/input failure.
#
# Usage: scripts/noctalia-config-audit.sh [--bump-check]
#   --bump-check  also re-derive the GUI registry from the pinned source and
#                 diff against the baseline (per-bump ritual step,
#                 docs/desktop/noctalia.md §Sharp edges).
set -euo pipefail

case "${1:-}" in
"" | --bump-check) ;;
*)
  echo "audit: unknown argument: $1 (usage: noctalia-config-audit.sh [--bump-check])" >&2
  exit 3
  ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/home/nixos/noctalia-authoritative-keys.conf"
baseline="$repo_root/scripts/noctalia-gui-registry.baseline"
declared="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml"
sidecar="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"

fail() {
  echo "audit: $1" >&2
  exit 3
}

[ -f "$manifest" ] || fail "manifest not found: $manifest"
[ -f "$declared" ] || fail "declared config not found: $declared (is this a desktop host with the Noctalia HM module active?)"

# Authoritative prefixes from the manifest — the same single source the
# reconcile is generated from.
auth_prefixes=()
while read -r kind a b; do
  case "$kind" in
  table) auth_prefixes+=("$a") ;;
  leaf) auth_prefixes+=("$a.$b") ;;
  "" | "#"*) ;;
  *) fail "manifest line not understood: $kind $a $b" ;;
  esac
done <"$manifest"

# Flatten a TOML file to sorted "dotted.path<TAB>json-value" lines via nix
# (fromTOML + a builtins-only walk) — no TOML parser dependency beyond nix
# itself, which every host running this config has.
flatten() {
  nix eval --impure --raw --expr "
    let
      f = p: v:
        if builtins.isAttrs v then
          builtins.concatLists (map (k: f (p ++ [ k ]) v.\${k}) (builtins.attrNames v))
        else
          [ \"\${builtins.concatStringsSep \".\" p}\t\${builtins.toJSON v}\" ];
    in
    builtins.concatStringsSep \"\n\" (
      f [ ] (builtins.fromTOML (builtins.unsafeDiscardStringContext (builtins.readFile $1)))
    )
  " | sort
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

flatten "$declared" >"$tmp/declared" || fail "could not flatten $declared"

if [ ! -f "$sidecar" ]; then
  echo "sidecar: absent — no GUI overrides exist; the declared config governs everything."
  sidecar_present=0
else
  flatten "$sidecar" >"$tmp/sidecar" || fail "could not flatten $sidecar"
  sidecar_present=1
fi

status=0
if [ "$sidecar_present" -eq 1 ]; then
  forbidden=0 redundant=0 diverged=0 gui_only=0
  : >"$tmp/report"
  while IFS=$'\t' read -r path value; do
    hit=""
    for pfx in "${auth_prefixes[@]}"; do
      case "$path" in
      "$pfx" | "$pfx".*) hit="$pfx" ;;
      esac
    done
    decl="$(awk -F '\t' -v p="$path" '$1 == p { print $2 }' "$tmp/declared")"
    if [ -n "$hit" ]; then
      forbidden=$((forbidden + 1))
      printf 'FORBIDDEN  %s = %s (authoritative under "%s")\n' "$path" "$value" "$hit" >>"$tmp/report"
    elif [ -z "$decl" ]; then
      gui_only=$((gui_only + 1))
    elif [ "$decl" = "$value" ]; then
      redundant=$((redundant + 1))
      printf 'REDUNDANT  %s = %s (equals declared — clear it or it blocks future flake changes)\n' "$path" "$value" >>"$tmp/report"
    else
      diverged=$((diverged + 1))
      printf 'DIVERGED   %s: declared %s, sidecar %s\n' "$path" "$decl" "$value" >>"$tmp/report"
    fi
  done <"$tmp/sidecar"

  cat "$tmp/report"
  echo "sidecar: $forbidden forbidden, $redundant redundant, $diverged diverged, $gui_only GUI-only (delegated runtime state, not reported)."
  if [ "$forbidden" -gt 0 ]; then
    status=2
    echo "recovery: the pre-spawn reconcile clears forbidden keys at next session start;"
    echo "  to clear now, follow docs/desktop/noctalia.md §Theming (operator action — agents never write under ~/.local/state/noctalia/)."
  fi
fi

if [ "${1:-}" = "--bump-check" ]; then
  src="$(nix eval --impure --raw --expr "(builtins.getFlake (toString $repo_root)).inputs.noctalia.outPath")" ||
    fail "could not resolve the pinned noctalia source"
  reg_dir="$src/src/shell/settings"
  [ -d "$reg_dir" ] || fail "registry dir not found at pin: $reg_dir (upstream layout moved — the extraction needs re-pointing)"

  # Literal-path extraction: {"a","b",...} literals in the settings sources.
  # Segments deliberately exclude '.' — real path segments never contain
  # dots, and allowing them pulled in ~38 value/i18n option-pairs (stage-6
  # review finding 2). TWO KNOWN GAPS, reported not silent (gate v +
  # stage-6 finding 1): (a) a helper-lambda idiom registers ~86 per-instance
  # paths (bar.*, wallpaper.monitor.*) — none declared by this repo; (b) the
  # hooks family is registered in a runtime loop over kHookKinds
  # (settings_registry.cpp ~2833, {"hooks", key} per kind) — handled
  # explicitly below because this repo DOES declare hooks.colors_changed.
  # The coverage line is the honesty mechanism; if matched/total shifts
  # sharply on a bump, re-verify the extraction against the new layout.
  if ! grep -ohE '\{"[a-z0-9_]+"(,[[:space:]]*"[a-z0-9_-]+")+\}' "$reg_dir"/*.cpp |
    sed -e 's/[{}"]//g' -e 's/,[[:space:]]*/./g' | sort -u >"$tmp/registry" ||
    [ ! -s "$tmp/registry" ]; then
    fail "registry extraction matched NOTHING at the pin — upstream layout moved; the F8 check is broken, not passed"
  fi
  # Known dynamically-registered families the literal pattern cannot see,
  # declared-relevant only (single line each, cited above).
  echo "hooks" >>"$tmp/registry"
  sort -u -o "$tmp/registry" "$tmp/registry"
  total_sites="$(cat "$reg_dir"/*.cpp | { grep -c 'makeEntry(' || true; })"
  matched="$(wc -l <"$tmp/registry")"
  echo "registry: $matched GUI-writable paths (literal extraction + known dynamic families; $total_sites makeEntry sites at the pin — the residue is the per-instance helper idiom, none declared here)."

  if [ -f "$baseline" ]; then
    if diff -u "$baseline" "$tmp/registry" >"$tmp/regdiff"; then
      echo "registry: no drift against the checked-in baseline."
    else
      echo "registry: DRIFT against the baseline — review, then update $baseline deliberately:"
      grep -E '^[+-][^+-]' "$tmp/regdiff" || true
    fi
  else
    echo "registry: no baseline at $baseline — seed it from this run's extraction (deliberate, reviewed commit)."
  fi

  # Declared-key reachability: which declared leaves are GUI-writable at the
  # pin (bucket 2) vs unreachable (bucket 3, accidentally safe). A leaf is
  # reachable if the registry carries the exact path OR any ancestor — the
  # GUI registers some controls at collection granularity (e.g.
  # `idle.behavior` is ONE control whose write serialises every leaf of
  # every row; gate iii / design note §Motivation), so an exact-match check
  # would wrongly certify those leaves as unreachable.
  while IFS=$'\t' read -r path _; do
    probe="$path" via=""
    while :; do
      if grep -qx "$probe" "$tmp/registry"; then
        via="$probe"
        break
      fi
      case "$probe" in
      *.*) probe="${probe%.*}" ;;
      *) break ;;
      esac
    done
    if [ -n "$via" ] && [ "$via" = "$path" ]; then
      echo "bucket-2: $path (declared, GUI-writable)"
    elif [ -n "$via" ]; then
      echo "bucket-2: $path (declared, GUI-writable via ancestor control \"$via\")"
    else
      echo "bucket-3: $path (declared, not GUI-reachable at this pin)"
    fi
  done <"$tmp/declared"
fi

exit "$status"
