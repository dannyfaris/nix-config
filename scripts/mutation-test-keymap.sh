#!/usr/bin/env bash
# On-demand mutation audit for the keybind guard net (lib/capabilities.nix's
# I1-I4 registry-shape validator, the niri/skhd collision lints, and
# home/darwin/skhd.nix's both-directions completeness assert). Deliberately
# NOT wired into CI: this is a slow (many `nix eval`/`nix build` passes),
# destructive-to-a-scratch-copy exercise that answers "does the net still
# have teeth?", not "did this commit break the build?" — CI already asks the
# latter via keybind-collisions[-skhd]/keybind-registry-shape/keybinds-table/
# lib-capabilities. Running it on every push would be paying full mutation-
# testing cost for a question that only changes answer when the guard layer
# itself moves (ADR-032: enforcement proportionate to what's being guarded).
#
# Run this by hand after changing:
#   - lib/capabilities.nix's guard layer (the I1-I4 checks, the collision
#     lints, the chord renderers/grammar they gate)
#   - lib/tests/capabilities.nix (the unit-test fixtures for the above)
#   - home/darwin/skhd.nix's both-directions asserts (the #537 pattern)
#
# A SURVIVED result means a hole in the net: some class of registry/keymap
# corruption that would ship silently because nothing in the guard layer
# fires on it. Either harden the guard (add/fix an assertion) or, if the gap
# is consciously acceptable, say so in a comment and update this script's
# catalogue to match — never just ignore a SURVIVED and move on.
#
# Never touches the real repo: every mutation lands in a throwaway `mktemp -d`
# copy, git-inited fresh (gen-keybinds-table.sh resolves its repo root via
# `git rev-parse --show-toplevel`, and `nix flake eval` on a path needs
# tracked — not just present — files, so the copy needs its own `git init` +
# `git add -A` + one commit before any of the five guards can see it).
set -euo pipefail

# Insulate the throwaway copy's git init/commit from the operator's global
# git config (a global commit.gpgsign=true would hang this non-interactively;
# a global excludesFile/templateDir could change what `git add -A` tracks).
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

REPO_ROOT="$(git rev-parse --show-toplevel)"
# Resolved to its physical path: macOS's /tmp is a symlink to /private/tmp,
# and `nix eval path:...` rejects a symlinked path component outright
# ("path '//var' is a symlink") — bit the first run of this script.
COPY="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$COPY"' EXIT

cp -a "$REPO_ROOT"/. "$COPY"/
rm -rf "${COPY:?}/.git"
(
  cd "$COPY"
  git init -q
  git add -A
  git -c user.name="mutation-test-keymap" -c user.email="mutation-test@localhost" \
    -c commit.gpgsign=false commit -q -m "mutation-test-keymap snapshot"
)

# ── The guard battery ────────────────────────────────────────────────────
# Each g<N> function evaluates (or builds/diffs) the COPY and returns 0 when
# it FIRED — a kill — and 1 when it stayed green. An eval error is treated
# as a fire: a mutation that makes the flake fail to evaluate at all is a
# kill by definition, not a false negative to chase down.

# try_eval <nix-expr> — runs `nix eval --impure --json`, leaves the raw
# stdout+stderr in EVAL_OUT, returns nix's own exit status.
EVAL_OUT=""
try_eval() {
  if EVAL_OUT=$(nix eval --impure --json --expr "$1" 2>&1); then
    return 0
  else
    return 1
  fi
}

# g1 — registry lints: validationFailures (I1-I4) + skhdCollisions +
# collisions, evaluated from the COPY's own lib/capabilities.nix via the
# COPY's own flake-pinned nixpkgs (so the mutation is judged by the lib
# version it will actually ship with).
g1() {
  local expr
  expr="let lib = (builtins.getFlake \"path:$COPY\").inputs.nixpkgs.lib; caps = import \"$COPY/lib/capabilities.nix\" { inherit lib; }; in caps.validationFailures ++ caps.skhdCollisions ++ caps.collisions"
  if try_eval "$expr"; then
    [[ $EVAL_OUT == "[]" ]] && return 1
    echo "  g1: registry lints non-empty: $EVAL_OUT" >&2
    return 0
  fi
  echo "  g1: eval error: $EVAL_OUT" >&2
  return 0
}

# g2 — the full unit-test suite: lib/tests/capabilities.nix's `lib.runTests`
# call already IS the module's return value (a list of failure records,
# empty when clean) — importing it is running it.
g2() {
  local expr
  expr="let lib = (builtins.getFlake \"path:$COPY\").inputs.nixpkgs.lib; in import \"$COPY/lib/tests/capabilities.nix\" { inherit lib; }"
  if try_eval "$expr"; then
    [[ $EVAL_OUT == "[]" ]] && return 1
    echo "  g2: unit-test failures: $EVAL_OUT" >&2
    return 0
  fi
  echo "  g2: eval error: $EVAL_OUT" >&2
  return 0
}

# g3 — host eval: forces home/darwin/skhd.nix's both-directions completeness
# throw (the #537 pattern) by evaluating celaeno's toplevel drvPath. Only
# eval, never build — the throw fires long before anything would build.
g3() {
  if EVAL_OUT=$(nix eval "path:$COPY#darwinConfigurations.celaeno.config.system.build.toplevel.drvPath" 2>&1); then
    return 1
  fi
  echo "  g3: host eval failed: $EVAL_OUT" >&2
  return 0
}

# g4 — keybinds-table drift: run the COPY's own gen-keybinds-table.sh and
# diff the result against a pre-run backup of the same file, then restore
# the backup regardless of outcome (this function must leave the COPY as it
# found it — the mutant's own restore-and-cmp-verify step, below, isn't
# scoped to files this function touches).
g4() {
  local doc="$COPY/docs/desktop/keybinds.md"
  local backup
  backup="$(mktemp)"
  cp "$doc" "$backup"
  local out rc
  if out=$(cd "$COPY" && bash scripts/gen-keybinds-table.sh 2>&1); then
    if cmp -s "$doc" "$backup"; then
      rc=1
    else
      echo "  g4: keybinds-table drift detected" >&2
      rc=0
    fi
  else
    echo "  g4: gen-keybinds-table.sh failed: $out" >&2
    rc=0
  fi
  cp "$backup" "$doc"
  rm -f "$backup"
  return "$rc"
}

# g5 — check-registration presence (closes the C3 blind spot the live audit
# found: a deleted `flake.checks` entry is invisible to g1-g4, which only
# ever look at lib/capabilities.nix's pure eval output, never at whether
# that output is actually wired to a check anyone runs).
g5() {
  local want=(keybind-collisions-skhd keybind-registry-shape keybinds-table lib-capabilities)
  if EVAL_OUT=$(nix eval "path:$COPY#checks.x86_64-linux" --apply builtins.attrNames --json 2>&1); then
    local missing=() name
    for name in "${want[@]}"; do
      [[ $EVAL_OUT == *"\"$name\""* ]] || missing+=("$name")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
      return 1
    fi
    echo "  g5: missing check registration(s): ${missing[*]}" >&2
    return 0
  fi
  echo "  g5: eval error: $EVAL_OUT" >&2
  return 0
}

GUARDS=(g1 g2 g3 g4 g5)

# run_battery — short-circuits on the first guard that fires; echoes the
# winning guard's name, or SURVIVED if all five stayed green.
run_battery() {
  local g
  for g in "${GUARDS[@]}"; do
    if "$g"; then
      echo "$g"
      return
    fi
  done
  echo "SURVIVED"
}

echo "== BASELINE: all five guards on the unmutated copy =="
baseline_failed=()
for g in "${GUARDS[@]}"; do
  if "$g"; then
    baseline_failed+=("$g")
  fi
done
if [[ ${#baseline_failed[@]} -gt 0 ]]; then
  echo "ABORT: baseline is RED on an unmutated copy (${baseline_failed[*]} fired)." >&2
  echo "Fix the guard net (or this script) before trusting any mutant result below." >&2
  exit 1
fi
echo "Baseline: all five guards green."
echo

# ── Mutant catalogue ─────────────────────────────────────────────────────
# One (description, target file, required-present pattern, sed substitution)
# tuple per guard class, chosen from the live audit's proven kills — as
# parallel arrays, indices aligned. `pattern` is checked with `grep -qF`
# before mutating (STALE if absent — the mutant no longer applies, e.g. after
# a refactor moved or renamed the guarded code — rather than silently
# no-op'ing and reporting a false KILLED/SURVIVED). `subst` is a `sed`
# script applied to the WHOLE file; every pattern below occurs on exactly
# one physical line each place it appears, so a plain (non-`g`) substitution
# naturally rewrites every matching line — the intended blast radius for
# each mutant (see each description). `#` is the sed delimiter throughout:
# every pattern/replacement is Nix syntax full of `.`, `"`, `(`, `)`, and
# none contains a literal `#`.
#
# The last two are deliberately not registry/keymap mutants at all: they
# corrupt a `lib.runTests` `expected` value in lib/tests/capabilities.nix
# itself. They MUST be killed by g2 — a survived control means the battery
# isn't actually sensitive to a broken unit-test file, which would silently
# invalidate every other row's g2 verdict too.
MUT_DESC=()
MUT_FILE=()
MUT_PATTERN=()
MUT_SUBST=()
MUT_CONTROL=()

add_mutant() {
  MUT_DESC+=("$1")
  MUT_FILE+=("$2")
  MUT_PATTERN+=("$3")
  MUT_SUBST+=("$4")
  MUT_CONTROL+=("${5:-no}")
}

add_mutant \
  "realization typo (niri-action -> niri-actoin, registry-wide fat-finger)" \
  "lib/capabilities.nix" \
  'realization = "niri-action";' \
  's#realization = "niri-action";#realization = "niri-actoin";#'

add_mutant \
  "forbidden action attached to every skhd-exec cap (bodies must be hand-authored in skhd.nix)" \
  "lib/capabilities.nix" \
  'platforms.darwin.realization = "skhd-exec";' \
  's#platforms.darwin.realization = "skhd-exec";#platforms.darwin.realization = "skhd-exec"; platforms.darwin.action = "stray";#'

add_mutant \
  "chord collision (open-outlook's key retargeted onto open-messages' Hyper+M)" \
  "lib/capabilities.nix" \
  'key = "E";' \
  's#key = "E";#key = "M";#'

add_mutant \
  "duplicate capability id (open-slack's id retargeted onto open-messages)" \
  "lib/capabilities.nix" \
  'id = "open-slack";' \
  's#id = "open-slack";#id = "open-messages";#'

add_mutant \
  "hex-case flip 0x2B -> 0x2b (truncates to 0x2 in skhd's eat_hex)" \
  "lib/capabilities.nix" \
  'Comma = "0x2B";' \
  's#Comma = "0x2B";#Comma = "0x2b";#'

add_mutant \
  "literal-name flip return -> enter (AeroSpace's old spelling, not skhd's)" \
  "lib/capabilities.nix" \
  'Return = "return";' \
  's#Return = "return";#Return = "enter";#'

add_mutant \
  "darwinMod token misspelled ctrl -> ctl (only visible in the rendered chord)" \
  "lib/capabilities.nix" \
  'Ctrl = "ctrl";' \
  's#Ctrl = "ctrl";#Ctrl = "ctl";#'

add_mutant \
  'skhd mod join collapsed (" + " -> "+"), breaks every rendered chord' \
  "lib/capabilities.nix" \
  'concatStringsSep " + " (darwinModTokens chord)' \
  's#concatStringsSep " + " (darwinModTokens chord)#concatStringsSep "+" (darwinModTokens chord)#'

add_mutant \
  "validationFailuresFor lobotomy (I1 duplicate-id term dropped from the ++ chain)" \
  "lib/capabilities.nix" \
  'idDuplicateFailuresFor reg' \
  's#idDuplicateFailuresFor reg#[ ]#'

add_mutant \
  "skhdCollisionsFor lobotomy (duplicate threshold neutered, length > 1 -> length > 999999)" \
  "lib/capabilities.nix" \
  '_c: es: lib.length es > 1) byChord' \
  's#_c: es: lib.length es > 1) byChord#_c: es: lib.length es > 999999) byChord#'

add_mutant \
  'skhd.nix body deletion (focus-window-up dropped from the bodies attrset)' \
  "home/darwin/skhd.nix" \
  'focus-window-up = y "window --focus north";' \
  's#focus-window-up = y "window --focus north";##'

add_mutant \
  "LIVENESS CONTROL 1/2: unit-test expectation corrupted (testNiriChordBase) — MUST be killed, or g2 isn't actually reading the test file" \
  "lib/tests/capabilities.nix" \
  'expected = "Ctrl+Alt+Left";' \
  's#expected = "Ctrl+Alt+Left";#expected = "WRONG";#' \
  "yes"

add_mutant \
  "LIVENESS CONTROL 2/2: unit-test expectation corrupted (testSkhdChordBase) — MUST be killed, or g2 isn't actually reading the test file" \
  "lib/tests/capabilities.nix" \
  'expected = "ctrl + alt - b";' \
  's#expected = "ctrl + alt - b";#expected = "WRONG";#' \
  "yes"

# ── Run the catalogue ────────────────────────────────────────────────────
RESULTS=()
n=${#MUT_DESC[@]}
i=0
while [[ $i -lt $n ]]; do
  desc="${MUT_DESC[$i]}"
  rel="${MUT_FILE[$i]}"
  pattern="${MUT_PATTERN[$i]}"
  subst="${MUT_SUBST[$i]}"
  target="$COPY/$rel"

  echo "== mutant $((i + 1))/$n: $desc =="

  if ! grep -qF -- "$pattern" "$target"; then
    echo "  STALE: pattern not found in $rel" >&2
    RESULTS+=("STALE")
    i=$((i + 1))
    echo
    continue
  fi

  backup="$target.pristine-backup"
  cp "$target" "$backup"

  sed "$subst" "$target" >"$target.mutated"
  mv "$target.mutated" "$target"

  result="$(run_battery)"
  RESULTS+=("$result")
  echo "  -> $result"

  cp "$backup" "$target"
  if ! cmp -s "$backup" "$target"; then
    echo "ABORT: restore of $rel from backup failed to verify byte-identical." >&2
    exit 1
  fi
  rm -f "$backup"

  i=$((i + 1))
  echo
done

# ── Summary table ────────────────────────────────────────────────────────
echo "== Summary =="
printf '%-4s %-9s %-70s %s\n' "#" "RESULT" "DESCRIPTION" "FILE"
survived=0
stale=0
i=0
while [[ $i -lt $n ]]; do
  tag=""
  [[ ${MUT_CONTROL[$i]} == "yes" ]] && tag=" [control]"
  printf '%-4s %-9s %-70s %s\n' "$((i + 1))" "${RESULTS[$i]}" "${MUT_DESC[$i]}$tag" "${MUT_FILE[$i]}"
  [[ ${RESULTS[$i]} == "SURVIVED" ]] && survived=$((survived + 1))
  [[ ${RESULTS[$i]} == "STALE" ]] && stale=$((stale + 1))
  i=$((i + 1))
done
echo
echo "$n mutants: $((n - survived - stale)) killed, $survived survived, $stale stale."

if [[ $survived -gt 0 || $stale -gt 0 ]]; then
  echo "FAIL: the keybind guard net has a hole (SURVIVED) or the catalogue is out of date (STALE)." >&2
  exit 1
fi

echo "All mutants killed. The keybind guard net holds."
