#!/usr/bin/env bash
# Smoke-test for scripts/lint-shared-purity.sh: each `fail` snippet must be
# flagged (one representative per pattern family in the linter's PATTERNS
# alternation), each `pass` snippet must not be (locking in that clean code,
# and prose/strings that merely mention a platform, don't false-positive —
# the real risk with grep-based linting). Pure grep, no Nix.
#
# Wired via parts/checks.nix as the `test-shared-purity` hook, gated on edits
# to lint-shared-purity.sh (#193); runs in `nix flake check`/CI and at
# commit-time when the linter changes. Also runnable standalone:
#   bash scripts/test-lint-shared-purity.sh
#
# Compact data-driven form — shrunk 2026-06-06 from per-fixture heredocs to a
# single loop, keeping the same coverage in a third of the lines, per ADR-032
# (proportionate enforcement: lightest mechanism that holds the guarantee).
# The bundle linter's parallel self-test was retired entirely in the same
# spirit when bundle-purity narrowed to the shape check (ADR-032 item 3).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The pre-commit hook passes the linter's Nix-store path via LINT_SCRIPT (the
# store interns each file separately, so the sibling default can't find it);
# standalone runs fall back to the sibling.
LINT="${LINT_SCRIPT:-$SCRIPT_DIR/lint-shared-purity.sh}"
[[ -r $LINT ]] || {
  echo "ERROR: $LINT not found or not readable" >&2
  exit 2
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# check <pass|fail> <snippet> — write the snippet as a module line and assert
# the linter's verdict. lint-shared-purity.sh is line-based grep, so a
# one-line snippet exercises each pattern exactly.
check() {
  local expect=$1 snippet=$2 f="$tmp/case.nix" got
  printf '{ ... }: {\n  x = %s;\n}\n' "$snippet" >"$f"
  if bash "$LINT" "$f" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ $got == "$expect" ]]; then
    echo "OK   $expect: $snippet"
  else
    echo "FAIL want=$expect got=$got: $snippet" >&2
    failures=$((failures + 1))
  fi
}

# Positives — must NOT flag.
check pass 'pkgs.ripgrep'
check pass '"runs on Darwin and Linux"  # a linux-friendly tool'
# Negatives — one representative per PATTERNS family; both sides of the
# is(Darwin|Linux) alternation and the optional (pkgs.)? / (pkgs.stdenv.)?
# prefixes, so a one-sided or prefix-dropping regex edit is caught.
check fail 'stdenv.isDarwin'
check fail 'stdenv.isLinux'
check fail 'pkgs.stdenv.isDarwin'
check fail 'stdenv.hostPlatform.isDarwin'
check fail 'pkgs.stdenv.hostPlatform.isLinux'
check fail 'pkgs.hostPlatform.isLinux'
check fail 'pkgs.stdenv.system == "aarch64-darwin"'
check fail 'system == "x86_64-linux"'
check fail 'lib.platforms.linux'
check fail 'lib.platforms.darwin'

echo
if ((failures > 0)); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All shared-purity lint tests passed."
