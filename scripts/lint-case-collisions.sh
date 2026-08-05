#!/usr/bin/env bash
# Fails if two tracked paths differ only by ASCII case. Such a pair cannot
# both exist in a checkout on a case-insensitive filesystem (APFS: neptune
# and the macos-15 CI leg), where one silently clobbers the other.
# The Linux legs are the real enforcers — on Darwin the collision is already
# collapsed by the time the source reaches the store, so the check cannot
# see it there. Deliberately ASCII-only: `tr` is byte-oriented, so Unicode
# case pairs and NFC/NFD variants are not folded. Under-approximates (false
# negatives, never false positives) — acceptable for an ASCII-path repo.
#
# Wired into the pre-commit framework via parts/checks.nix. Whole-tree
# (it reads the index itself), so it takes no positional args.
#
# Known limits, stated not hidden: Unicode case-folding and macOS NFD
# normalisation are not covered; directory-only collisions (`dir/a` vs
# `DIR/b`) produce no duplicate full-path key and are not flagged (benign —
# the directories merge, no file is lost).
#
# See ADR-025 for this framework, ADR-032 for the proportionality stance.

set -euo pipefail
export LC_ALL=C

# Plain `ls-files`, not `-z`: git C-quotes newlines and control characters,
# so its output is genuinely one path per line, and the reporting loop below
# compares against that same quoted form. `-z` emits raw paths instead, which
# would split a newline-containing path into fragments and report them as
# collisions with unrelated files.
dupes=$(git -c core.quotePath=false ls-files |
  tr '[:upper:]' '[:lower:]' |
  sort |
  uniq -d)

[ -z "$dupes" ] && exit 0

echo "ERROR: paths differing only by case:" >&2
while IFS= read -r key; do
  git -c core.quotePath=false ls-files |
    grep -ixF -- "$key" |
    sed 's/^/  - /' >&2
done <<<"$dupes"
exit 1
