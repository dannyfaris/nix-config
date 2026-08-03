#!/usr/bin/env bash
# Installs the six packaged linters CI's pre-commit set runs, pinned to the
# versions this flake's nixpkgs supplies, so a nix-less cloud container can
# reach the same verdicts locally. See docs/design/cloud-session-lint-toolchain.md.

set -euo pipefail
export LC_ALL=C

# Every pin below was read from this one nixpkgs rev: git-hooks-nix and
# treefmt-nix both follow the root `nixpkgs` input, so it is the single source
# of the binaries CI runs.
NIXPKGS_REV="148bab9c1c3c53136ecb44a6ea356a0ed5b39b06"

# `TOFU` marks a sha256 computed at pin time (2026-08-02) because upstream
# publishes no checksum file; actionlint's is transcribed from its published
# actionlint_1.7.12_checksums.txt.
SHELLCHECK_VERSION="0.11.0"
SHELLCHECK_URL="https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz"
SHELLCHECK_SHA256="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198" # TOFU
SHELLCHECK_MEMBER="shellcheck-v0.11.0/shellcheck"

ACTIONLINT_VERSION="1.7.12"
ACTIONLINT_URL="https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz"
ACTIONLINT_SHA256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
ACTIONLINT_MEMBER="actionlint"

SHFMT_VERSION="3.13.1"
SHFMT_URL="https://github.com/mvdan/sh/releases/download/v3.13.1/shfmt_v3.13.1_linux_amd64"
SHFMT_SHA256="fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1" # TOFU

# The nixfmt asset carries no platform suffix at all — one more reason the
# platform guard below refuses rather than guesses.
NIXFMT_VERSION="1.4.0"
NIXFMT_URL="https://github.com/NixOS/nixfmt/releases/download/v1.4.0/nixfmt"
NIXFMT_SHA256="62488394d5233283096466350487ed46470366f57db4bec824a87ecbacce960a" # TOFU

# deadnix publishes no binaries anywhere; cargo verifies the crates.io checksum.
DEADNIX_VERSION="1.3.2"

# nixpkgs pins a mid-branch commit of a fork, so no release corresponds to the
# statix CI runs and the rev is the only pin available. That build has no
# --version flag, so idempotence is stamped on the rev instead of read back.
STATIX_REPO="https://github.com/molybdenumsoftware/statix"
STATIX_REV="52530001bdbc8e94aae0d406a929c7ad7f09d9d1"

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nix-config-lint-toolchain"

# Resolved from the script's own location rather than $PWD: the fetcher installs
# into $HOME and is useful from anywhere, but the drift check needs this repo.
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# The bare-binary assets are amd64-only or unsuffixed, so a wrong-arch install
# would be silent rather than loud. Hosts have nix and do not need this script.
os="$(uname -s)"
arch="$(uname -m)"
if [ "$os" != "Linux" ] || [ "$arch" != "x86_64" ]; then
  echo "ERROR: these pins are Linux/x86_64 only (found $os/$arch)." >&2
  echo "  → Where nix is available, build the check derivation instead:" >&2
  echo "    nix build .#checks.<system>.pre-commit --no-link" >&2
  exit 1
fi

# A moved lock may mean a moved linter version. A warning, never a gate — the
# design note's §"Version-pin sync story" argues that trade.
lock="$REPO_ROOT/flake.lock"
if command -v jq >/dev/null && [ -r "$lock" ]; then
  lock_rev="$(jq -r '.nodes.nixpkgs.locked.rev // empty' "$lock" 2>/dev/null || true)"
  if [ -n "$lock_rev" ] && [ "$lock_rev" != "$NIXPKGS_REV" ]; then
    echo "WARNING: flake.lock nixpkgs is $lock_rev; these pins were read from $NIXPKGS_REV." >&2
    echo "         The versions installed below may no longer be the ones CI runs." >&2
  fi
fi

mkdir -p "$BIN_DIR" "$STATE_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Download to a temp file and verify the vendored sha256 before anything is
# extracted or installed. --fail is load-bearing: without it a proxy denial body
# is written to the target path and installed as a "binary".
fetch_verified() {
  local url="$1" sha="$2" dest="$3"
  curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 --max-time 120 \
    --output "$dest" "$url" || return 1
  if ! printf '%s  %s\n' "$sha" "$dest" | sha256sum --check --status -; then
    echo "ERROR: sha256 mismatch for $url — nothing installed." >&2
    rm -f "$dest"
    return 1
  fi
}

# Stage beside the target and rename: rename(2) within $BIN_DIR is atomic, so a
# run cancelled mid-copy can never leave a truncated binary first on PATH.
install_atomic() {
  local src="$1" tool="$2"
  install -m 755 "$src" "$BIN_DIR/.$tool.new" || return 1
  mv -f "$BIN_DIR/.$tool.new" "$BIN_DIR/$tool" || return 1
}

install_bare() {
  local tool="$1" url="$2" sha="$3"
  local dl="$tmp_dir/$tool.download"
  fetch_verified "$url" "$sha" "$dl" || return 1
  install_atomic "$dl" "$tool" || return 1
}

install_from_archive() {
  local tool="$1" url="$2" sha="$3" member="$4"
  local dl="$tmp_dir/$tool.archive" out="$tmp_dir/$tool.unpacked"
  fetch_verified "$url" "$sha" "$dl" || return 1
  mkdir -p "$out" || return 1
  tar --extract --file "$dl" --directory "$out" "$member" || return 1
  install_atomic "$out/$member" "$tool" || return 1
}

# cargo builds into a staging root so that only the binary reaches $BIN_DIR —
# its .crates.toml bookkeeping has no business in a PATH directory.
install_from_cargo() {
  local tool="$1"
  shift
  local stage="$tmp_dir/cargo-$tool"
  if ! command -v cargo >/dev/null; then
    echo "ERROR: $tool is built from source and cargo is not on PATH." >&2
    return 1
  fi
  # Fetch git deps with the git CLI: libgit2 ignores git's url.insteadOf
  # rewrite, which is the only route to github.com in a proxied session.
  CARGO_NET_GIT_FETCH_WITH_CLI=true \
    cargo install "$@" --locked --root "$stage" || return 1
  install_atomic "$stage/bin/$tool" "$tool" || return 1
}

# Five of the six self-report a version, which is what makes a re-run cheap.
# Deliberately not a pipeline into grep: under `set -o pipefail` the producer's
# SIGPIPE reads as a failure, and every run would reinstall.
is_installed() {
  local tool="$1" version="$2" out
  [ -x "$BIN_DIR/$tool" ] || return 1
  out="$("$BIN_DIR/$tool" --version 2>/dev/null)" || return 1
  case "$out" in
  *"$version"*) return 0 ;;
  *) return 1 ;;
  esac
}

# Return 2 for "already at the pinned version"; the caller reports it as a skip.
static_tool() {
  local tool="$1" version="$2" url="$3" sha="$4" member="${5:-}"
  if is_installed "$tool" "$version"; then
    return 2
  fi
  if [ -n "$member" ]; then
    install_from_archive "$tool" "$url" "$sha" "$member"
  else
    install_bare "$tool" "$url" "$sha"
  fi
}

cargo_crate_tool() {
  local tool="$1" version="$2"
  if is_installed "$tool" "$version"; then
    return 2
  fi
  install_from_cargo "$tool" "$tool" --version "$version"
}

# The --help execution stands in for the missing --version: statix is the one
# dynamically linked tool here, so "the stamp matches" must not outlive "the
# binary still runs on this libc".
statix_tool() {
  local stamp="$STATE_DIR/statix.rev"
  if [ -r "$stamp" ] && [ "$(cat "$stamp")" = "$STATIX_REV" ] &&
    "$BIN_DIR/statix" --help >/dev/null 2>&1; then
    return 2
  fi
  install_from_cargo statix --git "$STATIX_REPO" --rev "$STATIX_REV" || return 1
  printf '%s\n' "$STATIX_REV" >"$stamp" || return 1
}

summary=()
failures=0

record() {
  local rc="$1" label="$2"
  if [ "$rc" -eq 0 ]; then
    summary+=("ok    $label")
  elif [ "$rc" -eq 2 ]; then
    summary+=("skip  $label (already installed)")
  else
    summary+=("FAIL  $label")
    failures=$((failures + 1))
  fi
}

# Per-tool isolation: a failed tool never aborts the others, so one unreachable
# asset still leaves five usable linters and a summary that names the gap.
rc=0
static_tool shellcheck "$SHELLCHECK_VERSION" \
  "$SHELLCHECK_URL" "$SHELLCHECK_SHA256" "$SHELLCHECK_MEMBER" || rc=$?
record "$rc" "shellcheck $SHELLCHECK_VERSION"

rc=0
static_tool actionlint "$ACTIONLINT_VERSION" \
  "$ACTIONLINT_URL" "$ACTIONLINT_SHA256" "$ACTIONLINT_MEMBER" || rc=$?
record "$rc" "actionlint $ACTIONLINT_VERSION"

rc=0
static_tool shfmt "$SHFMT_VERSION" "$SHFMT_URL" "$SHFMT_SHA256" || rc=$?
record "$rc" "shfmt $SHFMT_VERSION"

rc=0
static_tool nixfmt "$NIXFMT_VERSION" "$NIXFMT_URL" "$NIXFMT_SHA256" || rc=$?
record "$rc" "nixfmt $NIXFMT_VERSION"

rc=0
cargo_crate_tool deadnix "$DEADNIX_VERSION" || rc=$?
record "$rc" "deadnix $DEADNIX_VERSION"

rc=0
statix_tool || rc=$?
record "$rc" "statix @ $STATIX_REV"

echo
echo "Lint toolchain in $BIN_DIR:"
printf '  %s\n' "${summary[@]}"

if [ "$failures" -gt 0 ]; then
  echo >&2
  echo "ERROR: $failures of 6 tools failed; the lint set is incomplete." >&2
  exit 1
fi

exit 0
