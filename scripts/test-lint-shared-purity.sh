#!/usr/bin/env bash
# Exercises scripts/lint-shared-purity.sh against synthetic positive and
# negative fixtures so the platform-purity lint's detection logic is
# verifiable in isolation — locking in the *negative* paths (one per
# flagged pattern family) against regression. The lint's *positive* path
# is already exercised continuously by the shared-purity pre-commit hook.
#
# Wired into the pre-commit framework via parts/checks.nix as the
# `test-shared-purity` hook, gated on edits to lint-shared-purity.sh, so
# it runs in `nix flake check`/CI and at commit-time whenever the linter
# changes (#193). Also runnable standalone: `bash scripts/test-lint-shared-purity.sh`.
#
# Pure grep — no Nix needed (unlike the bundle linter, which
# canonicalises via nix-instantiate). The bundle linter had a parallel
# self-test until 2026-06-06, retired with its tokeniser when
# bundle-purity was narrowed to the shape check (ADR-032).
#
# Fixtures live in a per-run TMPDIR; no committed test data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Locate the linter under test. Standalone runs find it as a sibling;
# the pre-commit hook sets LINT_SCRIPT to its Nix-store path, because the
# store interns each file separately — the sibling lookup would miss it.
LINT="${LINT_SCRIPT:-$SCRIPT_DIR/lint-shared-purity.sh}"

# Readable, not executable: the test always invokes via `bash "$LINT"`,
# and the store path the hook passes need not carry the executable bit.
if [[ ! -r $LINT ]]; then
  echo "ERROR: $LINT not found or not readable" >&2
  exit 2
fi

fixtures=$(mktemp -d)
trap 'rm -rf "$fixtures"' EXIT

# Positive case: platform-agnostic module — no flagged pattern.
cat >"$fixtures/clean.nix" <<'EOF'
{ pkgs, ... }:
{
  home.packages = [ pkgs.ripgrep ];
  programs.git.enable = true;
}
EOF

# Positive case: the word "Darwin" in a comment/string is not a pattern.
# Locks in that prose mentioning a platform doesn't false-positive — only
# the conditional constructs do.
cat >"$fixtures/prose-mentions-platform.nix" <<'EOF'
{ ... }:
{
  # Works identically on Darwin and Linux; no conditional needed.
  programs.foo.description = "a linux-friendly tool";
}
EOF

# Negative case: stdenv.isDarwin.
cat >"$fixtures/stdenv-isdarwin.nix" <<'EOF'
{ stdenv, ... }:
{
  home.packages = stdenv.lib.optionals stdenv.isDarwin [ ];
}
EOF

# Negative case: stdenv.isLinux.
cat >"$fixtures/stdenv-islinux.nix" <<'EOF'
{ stdenv, ... }:
{
  services.foo.enable = stdenv.isLinux;
}
EOF

# Negative case: pkgs.stdenv.isDarwin (qualified prefix).
cat >"$fixtures/pkgs-stdenv-isdarwin.nix" <<'EOF'
{ pkgs, ... }:
{
  home.packages = pkgs.lib.optionals pkgs.stdenv.isDarwin [ ];
}
EOF

# Negative case: stdenv.hostPlatform.isDarwin.
cat >"$fixtures/hostplatform-isdarwin.nix" <<'EOF'
{ stdenv, ... }:
{
  programs.foo.enable = stdenv.hostPlatform.isDarwin;
}
EOF

# Negative case: pkgs.hostPlatform.isLinux.
cat >"$fixtures/pkgs-hostplatform-islinux.nix" <<'EOF'
{ pkgs, ... }:
{
  programs.foo.enable = pkgs.hostPlatform.isLinux;
}
EOF

# Negative case: system == "<arch>-darwin" string comparison, qualified
# (exercises the optional `(pkgs.stdenv.)?` prefix present).
cat >"$fixtures/system-eq-darwin.nix" <<'EOF'
{ pkgs, ... }:
{
  programs.foo.enable = pkgs.stdenv.system == "aarch64-darwin";
}
EOF

# Negative case: bare `system == "<arch>-linux"` (the same prefix absent),
# locking in that the linter's `(pkgs.stdenv.)?` quantifier stays optional.
cat >"$fixtures/system-eq-linux-bare.nix" <<'EOF'
{ system, ... }:
{
  programs.foo.enable = system == "x86_64-linux";
}
EOF

# Negative case: lib.platforms.linux.
cat >"$fixtures/lib-platforms-linux.nix" <<'EOF'
{ lib, ... }:
{
  meta.platforms = lib.platforms.linux;
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
assert_pass "$fixtures/prose-mentions-platform.nix"
assert_fail "$fixtures/stdenv-isdarwin.nix"
assert_fail "$fixtures/stdenv-islinux.nix"
assert_fail "$fixtures/pkgs-stdenv-isdarwin.nix"
assert_fail "$fixtures/hostplatform-isdarwin.nix"
assert_fail "$fixtures/pkgs-hostplatform-islinux.nix"
assert_fail "$fixtures/system-eq-darwin.nix"
assert_fail "$fixtures/system-eq-linux-bare.nix"
assert_fail "$fixtures/lib-platforms-linux.nix"

echo
if ((failures > 0)); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All shared-purity lint tests passed."
