#!/usr/bin/env bash
# Exercises scripts/lint-bundle-purity.sh against synthetic positive
# and negative fixtures so the lint's behaviour is verifiable in
# isolation — locking in the *negative* paths (the lint's own
# detection logic) against regression. The lint's *positive* path is
# already exercised continuously by the bundle-purity pre-commit hook.
#
# Wired into the pre-commit framework via parts/checks.nix as the
# `test-bundle-purity` hook, gated on edits to lint-bundle-purity.sh, so
# it runs in `nix flake check`/CI and at commit-time whenever the linter
# changes (#193). Also runnable standalone: `bash scripts/test-lint-bundle-purity.sh`.
#
# Fixtures live in a per-run TMPDIR; no committed test data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Locate the linter under test. Standalone runs find it as a sibling;
# the pre-commit hook sets LINT_SCRIPT to its Nix-store path, because the
# store interns each file separately — the sibling lookup would miss it.
LINT="${LINT_SCRIPT:-$SCRIPT_DIR/lint-bundle-purity.sh}"

# Readable, not executable: the test always invokes via `bash "$LINT"`,
# and the store path the hook passes need not carry the executable bit.
if [[ ! -r $LINT ]]; then
  echo "ERROR: $LINT not found or not readable" >&2
  exit 2
fi

fixtures=$(mktemp -d)
trap 'rm -rf "$fixtures"' EXIT

# Positive case: clean bundle (≥ 2 distinct path imports).
cat >"$fixtures/clean.nix" <<'EOF'
{
  imports = [
    ./a.nix
    ./b.nix
  ];
}
EOF

# Positive case: function-wrapped clean bundle.
cat >"$fixtures/clean-fn.nix" <<'EOF'
{ ... }:
{
  imports = [
    ./a.nix
    ./b.nix
    ./c.nix
  ];
}
EOF

# Negative case: inline option setting alongside imports.
cat >"$fixtures/inline-config.nix" <<'EOF'
{
  imports = [
    ./a.nix
    ./b.nix
  ];
  services.foo.enable = true;
}
EOF

# Negative case: explicit `config` block.
cat >"$fixtures/config-block.nix" <<'EOF'
{ ... }: {
  imports = [
    ./a.nix
    ./b.nix
  ];
  config.services.bar.enable = true;
}
EOF

# Negative case: single import (< 2).
cat >"$fixtures/single-import.nix" <<'EOF'
{
  imports = [
    ./only.nix
  ];
}
EOF

# Negative case: empty imports list.
cat >"$fixtures/empty-imports.nix" <<'EOF'
{
  imports = [ ];
}
EOF

# Negative case: duplicate entries.
cat >"$fixtures/duplicate.nix" <<'EOF'
{
  imports = [
    ./a.nix
    ./b.nix
    ./a.nix
  ];
}
EOF

failures=0

assert_pass() {
  local fixture=$1
  if bash "$LINT" "$fixture" >/dev/null 2>&1; then
    echo "OK   pass:  $(basename "$fixture")"
  else
    echo "FAIL pass:  $(basename "$fixture") — expected to pass but lint rejected it" >&2
    failures=$((failures + 1))
  fi
}

assert_fail() {
  local fixture=$1
  if bash "$LINT" "$fixture" >/dev/null 2>&1; then
    echo "FAIL fail:  $(basename "$fixture") — expected lint to reject but it passed" >&2
    failures=$((failures + 1))
  else
    echo "OK   fail:  $(basename "$fixture")"
  fi
}

assert_pass "$fixtures/clean.nix"
assert_pass "$fixtures/clean-fn.nix"
assert_fail "$fixtures/inline-config.nix"
assert_fail "$fixtures/config-block.nix"
assert_fail "$fixtures/single-import.nix"
assert_fail "$fixtures/empty-imports.nix"
assert_fail "$fixtures/duplicate.nix"

echo
if ((failures > 0)); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All bundle-purity lint tests passed."
