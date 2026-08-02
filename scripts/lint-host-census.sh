#!/usr/bin/env bash
# Binds CLAUDE.md's host census to the `hosts/` tree (#583). The entry-point
# doc is loaded into every session and declared to override default
# behaviour, yet no PR is obligated to touch it when a host is added or
# retired — so its census silently rots (it was three hosts stale when this
# lint landed).
#
# Asserts two-way set equality between the directories under `hosts/` and the
# host names named in CLAUDE.md's two marked census regions (`CENSUS: hosts`
# in §Purpose, `CENSUS: break-glass` in §Break-glass). A host directory with
# no bullet fails; a bullet with no host directory fails.
#
# Wired into the pre-commit framework via parts/checks.nix. Whole-tree: the
# host directories come from the index, CLAUDE.md is read from the worktree
# (pre-commit stashes unstaged changes, so at commit time the two agree).
# It takes no positional args and must run from the repo root.
#
# Scope, stated not hidden: names only. Role, arch, chassis and the
# `(retiring)` annotation are free prose inside the bullets — none of it is
# machine-readable anywhere in the repo, and minting a fleet record to lint
# it is not this guardrail's job (ADR-032: the lightest mechanism that holds
# the guarantee). Host mentions outside the two marked regions are unbound.
#
# Dependencies: bash builtins + grep/sed/comm/sort/cut + git — the same
# posture as lint-case-collisions.sh.
#
# Override (deliberately partial mid-migration commit):
#   git commit --no-verify
#
# See ADR-025 for this framework, ADR-032 for the proportionality stance.

set -euo pipefail
export LC_ALL=C

DOC="CLAUDE.md"

[ -r "$DOC" ] || {
  echo "ERROR: $DOC not found or not readable (run from the repo root)." >&2
  exit 1
}

# Directories under hosts/ carrying at least one TRACKED file. The index, not
# the worktree: what is being committed is what is checked. The 'hosts/*/*'
# pathspec ignores a stray file directly under hosts/ by construction — it
# yields no directory component.
host_dirs=$(git ls-files -- 'hosts/*/*' | cut -d/ -f2 | sort -u)

# Emit a newline-separated list, or nothing at all when it is empty. A bare
# `printf '%s\n' ""` would emit one blank line, which comm would then read as
# a nameless host.
emit() {
  [ -n "$1" ] || return 0
  printf '%s\n' "$1"
}

# The lines strictly between a region's column-0 markers.
region() {
  local tag="$1" inside=0 line
  while IFS= read -r line; do
    case $line in
    "<!-- END CENSUS: $tag"*) inside=0 ;;
    "<!-- BEGIN CENSUS: $tag"*) inside=1 ;;
    *) if [ "$inside" = 1 ]; then printf '%s\n' "$line"; fi ;;
    esac
  done <"$DOC"
}

# The leading inline-code-or-bold token of each `- ` bullet in a region: the
# two regions differ in bullet style (`` `name` `` in §Purpose, `**name**` in
# §Break-glass), so one extractor accepts both. Set comparison, never
# substring matching — a `metis` / `metis-2` prefix pair must not mask a miss
# (which any `grep -w` approach would, since `-w` treats `-` as a boundary).
names() {
  region "$1" | { grep -oE '^- (`|\*\*)[a-z0-9][a-z0-9-]*(`|\*\*)' || true; } |
    tr -d '`*' | sed 's/^- //' | sort -u
}

# Markers first: a region the extractor cannot delimit would otherwise
# degrade into "every host missing" or a census that silently satisfies
# itself, both of which name the wrong defect. So the gate is anchored to
# column 0 exactly like region()'s `case` prefix globs — the marker text
# holds no BRE metacharacter, so trading -F for the ^ anchor is free — and
# it demands exactly one BEGIN and one END per tag, BEGIN first: a
# duplicated pair unions two regions, an inverted one runs to EOF and
# swallows its neighbour. One distinct message per marker defect.
marker_errs=()
for tag in hosts break-glass; do
  n_begin=$(grep -c "^<!-- BEGIN CENSUS: $tag" "$DOC") || true
  n_end=$(grep -c "^<!-- END CENSUS: $tag" "$DOC") || true

  if [ "$n_begin" -eq 0 ]; then
    marker_errs+=("$DOC is missing the $tag census BEGIN marker (<!-- BEGIN CENSUS: $tag ... -->)")
  elif [ "$n_begin" -gt 1 ]; then
    marker_errs+=("$DOC has $n_begin $tag census BEGIN markers; exactly one is required")
  fi

  if [ "$n_end" -eq 0 ]; then
    marker_errs+=("$DOC is missing the $tag census END marker (<!-- END CENSUS: $tag -->)")
  elif [ "$n_end" -gt 1 ]; then
    marker_errs+=("$DOC has $n_end $tag census END markers; exactly one is required")
  fi

  if [ "$n_begin" -eq 1 ] && [ "$n_end" -eq 1 ]; then
    begin_at=$(grep -n "^<!-- BEGIN CENSUS: $tag" "$DOC" | cut -d: -f1)
    end_at=$(grep -n "^<!-- END CENSUS: $tag" "$DOC" | cut -d: -f1)
    [ "$begin_at" -lt "$end_at" ] ||
      marker_errs+=("$DOC's $tag census END marker (line $end_at) precedes its BEGIN marker (line $begin_at)")
  fi
done

if [ ${#marker_errs[@]} -gt 0 ]; then
  {
    echo "ERROR: CLAUDE.md census markers are missing or malformed:"
    printf '  %s\n' "${marker_errs[@]}"
    echo "  → Each census region needs exactly one BEGIN and one END marker, in that"
    echo "    order and at column 0; scripts/lint-host-census.sh extracts the host"
    echo "    names from between them."
    echo
    echo "Override (deliberately partial mid-migration commit): git commit --no-verify"
  } >&2
  exit 1
fi

errs=()
unnamed=0
ghosts=0
for tag in hosts break-glass; do
  case $tag in
  hosts) label="§Purpose census" ;;
  break-glass) label="§Break-glass" ;;
  esac
  named=$(names "$tag")

  missing=$(comm -23 <(emit "$host_dirs") <(emit "$named"))
  if [ -n "$missing" ]; then
    errs+=("  $label — exists under hosts/ but not named:")
    while IFS= read -r h; do errs+=("    - $h"); done <<<"$missing"
    unnamed=1
  fi

  ghost=$(comm -13 <(emit "$host_dirs") <(emit "$named"))
  if [ -n "$ghost" ]; then
    errs+=("  $label — named in the census but no hosts/<name>/ directory:")
    while IFS= read -r h; do errs+=("    - $h"); done <<<"$ghost"
    ghosts=1
  fi
done

if [ ${#errs[@]} -gt 0 ]; then
  {
    echo "ERROR: CLAUDE.md host census disagrees with hosts/"
    printf '%s\n' "${errs[@]}"
    if [ "$unnamed" = 1 ]; then
      echo "  → Every directory under hosts/ must appear in both marked census regions"
      echo "    of CLAUDE.md. Add the missing bullets, or remove the host directory."
    fi
    if [ "$ghosts" = 1 ]; then
      echo "  → Remove the bullet, or add hosts/<name>/."
    fi
    echo
    echo "Override (deliberately partial mid-migration commit): git commit --no-verify"
  } >&2
  exit 1
fi

exit 0
