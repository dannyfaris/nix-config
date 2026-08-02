#!/usr/bin/env bash
# Smoke-test for scripts/lint-host-census.sh: one fixture per drift class the
# linter exists to catch — a host directory named in neither region, a ghost
# bullet with no directory, a deleted/displaced/duplicated/inverted marker —
# plus the non-drift shapes that must NOT fire (an untracked host dir, a
# stray file directly under hosts/, either bullet markup, the degenerate
# empty fleet).
#
# Both sides of this lint are repo state, so each case builds a throwaway git
# repo rather than a snippet: host dirs come from the index, the census from
# a generated CLAUDE.md. No commit is made, so no git identity is needed.
#
# Wired via parts/checks.nix as `test-host-census`, gated on edits to
# lint-host-census.sh; runs in `nix flake check`/CI and at commit-time when
# the linter changes. Also runnable standalone:
#   bash scripts/test-lint-host-census.sh
#
# Mirrors test-lint-shared-purity.sh (#193): a linter that gates a guarantee
# needs its own negative-path coverage, or a change that quietly made it pass
# everything would evaporate the guarantee unnoticed (ADR-032). Cases 2, 4,
# 6, 7, 11, 13, 14, 15 and 16 assert the failure TEXT as well as the exit
# status — a linter that fails for the wrong reason is the classic self-test
# blind spot, and for the marker cases the wrong reason ("every host
# missing") is the specific misdiagnosis the marker gate exists to prevent,
# so case 13 asserts its absence too.

set -euo pipefail
export LC_ALL=C
# The fixtures are disposable repos; the operator's git config must not reach
# them (a global `core.excludesFile` or `init.templateDir` could change what
# `git add -A` tracks, and the whole test turns on exactly that).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The pre-commit hook passes the linter's Nix-store path via LINT_SCRIPT (the
# store interns each file separately, so the sibling default can't find it);
# standalone runs fall back to the sibling.
LINT="${LINT_SCRIPT:-$SCRIPT_DIR/lint-host-census.sh}"
[[ -r $LINT ]] || {
  echo "ERROR: $LINT not found or not readable" >&2
  exit 2
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

BEGIN_HOSTS='<!-- BEGIN CENSUS: hosts — bound to hosts/ by scripts/lint-host-census.sh (#583) -->'
END_HOSTS='<!-- END CENSUS: hosts -->'
BEGIN_BG='<!-- BEGIN CENSUS: break-glass — bound to hosts/ by scripts/lint-host-census.sh (#583) -->'
END_BG='<!-- END CENSUS: break-glass -->'

# bullets <code|bold> <name>... — census-style or break-glass-style bullets.
bullets() {
  local markup=$1 n
  shift
  for n in "$@"; do
    # shellcheck disable=SC2016 # the backticks are literal markdown markup being emitted, not a substitution
    case $markup in
    code) printf -- '- `%s` — a fixture host.\n' "$n" ;;
    bold) printf -- '- **%s**: a fixture console.\n' "$n" ;;
    esac
  done
}

# build <name> <host-dirs> <census-bullets> <bg-bullets> [extra-tracked-file...]
# — a throwaway repo at $tmp/<name>; echoes its path.
build() {
  local hosts=$2 census=$3 bg=$4 dir="$tmp/$1" h f
  local -a host_list
  shift 4
  # Deliberate split of the space-separated host list; the `[@]+` guard keeps
  # the empty-fleet fixture from tripping `set -u`.
  read -r -a host_list <<<"$hosts"
  mkdir -p "$dir"
  git -C "$dir" init -q
  for h in ${host_list[@]+"${host_list[@]}"}; do
    mkdir -p "$dir/hosts/$h"
    : >"$dir/hosts/$h/default.nix"
  done
  for f in "$@"; do
    mkdir -p "$(dirname "$dir/$f")"
    : >"$dir/$f"
  done
  {
    printf '# fixture\n\n## Purpose\n\n%s\n' "$BEGIN_HOSTS"
    if [ -n "$census" ]; then printf '%s\n' "$census"; fi
    printf '%s\n\n## Break-glass\n\n%s\n' "$END_HOSTS" "$BEGIN_BG"
    if [ -n "$bg" ]; then printf '%s\n' "$bg"; fi
    printf '%s\n' "$END_BG"
  } >"$dir/CLAUDE.md"
  git -C "$dir" add -A
  printf '%s\n' "$dir"
}

# swap_markers <file> <a> <b> — exchange two whole lines in place. Awk, not
# sed: the marker strings carry em dashes and slashes, and this compares
# whole lines rather than interpreting either side as a pattern.
swap_markers() {
  awk -v a="$2" -v b="$3" '$0==a{print b;next} $0==b{print a;next} {print}' \
    "$1" >"$1.new" && mv "$1.new" "$1"
}

# check <pass|fail> <label> <dir> [expected-output-substring...]
# — a substring prefixed with `!` must be ABSENT from the output.
check() {
  local expect=$1 label=$2 dir=$3 out got pat
  shift 3
  if out=$(cd "$dir" && bash "$LINT" 2>&1); then got=pass; else got=fail; fi
  if [[ $got != "$expect" ]]; then
    echo "FAIL want=$expect got=$got: $label" >&2
    printf '%s\n' "$out" | sed 's/^/     | /' >&2
    failures=$((failures + 1))
    return 0
  fi
  for pat in "$@"; do
    if [[ $pat == '!'* ]]; then
      if grep -qF -- "${pat#!}" <<<"$out"; then
        echo "FAIL $label: output carries text it must not: ${pat#!}" >&2
        failures=$((failures + 1))
        return 0
      fi
    elif ! grep -qF -- "$pat" <<<"$out"; then
      echo "FAIL $label: output is missing expected text: $pat" >&2
      failures=$((failures + 1))
      return 0
    fi
  done
  echo "OK   $expect: $label"
}

# 1 — the clean baseline: two hosts, both named in both regions.
d=$(build case1 "a b" "$(bullets code a b)" "$(bullets code a b)")
check pass "census matches hosts/" "$d"

# 2 — the live drift: a host directory nothing names in §Purpose.
d=$(build case2 "a b c" "$(bullets code a b)" "$(bullets code a b c)")
check fail "host dir missing from the §Purpose census" "$d" \
  "exists under hosts/ but not named" "- c"

# 3 — same drift, break-glass side.
d=$(build case3 "a b c" "$(bullets code a b c)" "$(bullets code a b)")
check fail "host dir missing from §Break-glass" "$d"

# 4 — the decommission direction: a bullet outliving its host directory.
d=$(build case4 "a b" "$(bullets code a b ghost)" "$(bullets code a b)")
check fail "ghost name in the §Purpose census" "$d" \
  "named in the census but no hosts/<name>/ directory" "- ghost"

# 5 — same ghost, break-glass side.
d=$(build case5 "a b" "$(bullets code a b)" "$(bullets code a b ghost)")
check fail "ghost name in §Break-glass" "$d"

# 6 — a deleted BEGIN marker must be named as such, not degrade into
# "every host missing" (which would point at the wrong defect).
d=$(build case6 "a b" "$(bullets code a b)" "$(bullets code a b)")
grep -vF "$BEGIN_HOSTS" "$d/CLAUDE.md" >"$d/CLAUDE.md.new" && mv "$d/CLAUDE.md.new" "$d/CLAUDE.md"
check fail "hosts BEGIN marker deleted" "$d" "missing the hosts census BEGIN marker"

# 7 — and a deleted END marker, on the other region.
d=$(build case7 "a b" "$(bullets code a b)" "$(bullets code a b)")
grep -vF "$END_BG" "$d/CLAUDE.md" >"$d/CLAUDE.md.new" && mv "$d/CLAUDE.md.new" "$d/CLAUDE.md"
check fail "break-glass END marker deleted" "$d" "missing the break-glass census END marker"

# 8 — the index, not the worktree: an untracked host dir is not yet a host.
d=$(build case8 "a b" "$(bullets code a b)" "$(bullets code a b)")
mkdir -p "$d/hosts/wip"
: >"$d/hosts/wip/default.nix"
check pass "untracked hosts/wip/ ignored" "$d"

# 9 — a tracked stray file directly under hosts/ is not a host directory.
d=$(build case9 "a b" "$(bullets code a b)" "$(bullets code a b)" "hosts/README.md")
check pass "stray hosts/README.md ignored" "$d"

# 10 — both bullet markups are accepted, which is what lets the two regions
# keep their own house styles (backticked names, bolded break-glass entries).
d=$(build case10 "a b" "$(bullets code a b)" "$(bullets bold a b)")
check pass "backtick census, bold break-glass" "$d"

# 11 — set equality, not substring matching: `metis` must not satisfy
# `metis-2`. (`grep -w` would wrongly pass this — it treats `-` as a word
# boundary.)
d=$(build case11 "metis metis-2" "$(bullets code metis)" "$(bullets code metis)")
check fail "prefix pair does not mask a miss" "$d" "- metis-2"

# 12 — the degenerate case: no hosts, empty regions. Must not crash on the
# empty lists (`set -u`, and a blank line read as a nameless host).
d=$(build case12 "" "" "")
check pass "empty fleet, empty regions" "$d"

# 13 — a marker displaced off column 0 (an editor auto-indent, a reflow) is
# invisible to the extractor, so the gate must see it that way too: name the
# marker, and specifically NOT report every host as missing.
d=$(build case13 "a b" "$(bullets code a b)" "$(bullets code a b)")
awk -v m="$BEGIN_HOSTS" '$0==m{print "  " m; next} {print}' \
  "$d/CLAUDE.md" >"$d/CLAUDE.md.new" && mv "$d/CLAUDE.md.new" "$d/CLAUDE.md"
check fail "indented hosts BEGIN marker" "$d" \
  "missing the hosts census BEGIN marker" '!exists under hosts/ but not named'

# 14 — an inverted pair: the region would otherwise run from the BEGIN
# marker to EOF and swallow whatever follows, which here is the break-glass
# list — a bounded-looking census that is not bounded.
d=$(build case14 "a b" "$(bullets code a b)" "$(bullets code a b)")
swap_markers "$d/CLAUDE.md" "$BEGIN_HOSTS" "$END_HOSTS"
check fail "hosts END marker precedes BEGIN" "$d" \
  "census END marker (line" "precedes its BEGIN marker"

# 15 — a duplicated pair (the copy-paste slip) unions two regions, so a
# bullet in either one satisfies the census. Exactly one pair per tag.
d=$(build case15 "a b" "$(bullets code a)" "$(bullets code a b)")
{
  printf '%s\n' "$BEGIN_HOSTS"
  bullets code b
  printf '%s\n' "$END_HOSTS"
} >>"$d/CLAUDE.md"
check fail "duplicated hosts marker pair" "$d" \
  "has 2 hosts census BEGIN markers"

# 16 — the same inversion around an EMPTY region, which is the silent-pass
# shape: with no bullets of its own the runaway region is satisfied entirely
# by the break-glass bullets it swallows. Distinct from case 12, whose empty
# region is correctly ordered and must still pass.
d=$(build case16 "a b" "" "$(bullets bold a b)")
swap_markers "$d/CLAUDE.md" "$BEGIN_HOSTS" "$END_HOSTS"
check fail "inverted markers around an empty hosts region" "$d" \
  "precedes its BEGIN marker"

echo
if ((failures > 0)); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All host-census lint tests passed."
