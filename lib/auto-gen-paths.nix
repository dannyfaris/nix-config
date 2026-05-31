# Single source of truth for ADR-023's "auto-generated, do not hand-edit"
# carve-out — the set of files (per-host `hardware-configuration.nix` plus
# the legacy `nixos-vm/hardware.nix` two-file exception) that:
#
#   - statix must ignore (its own structural warnings on
#     nixos-generate-config's output shape can't be fixed without
#     breaking ADR-023's regenerate-via-nixos-anywhere contract),
#   - deadnix's pre-commit hook must skip,
#   - treefmt must not reformat (regenerate would overwrite formatting
#     on next run, churning the diff every refresh).
#
# The list is canonical in `statix.toml` — statix-the-CLI reads it
# directly from a fixed path when run, so that file *has* to exist with
# the right content. This module reads the same file and exposes the
# list to the Nix-side consumers (parts/checks.nix's pre-commit
# excludes, parts/formatter.nix's treefmt excludes), in both the glob
# form they were authored in and a derived POSIX-extended regex form
# for consumers (git-hooks.nix) that key off regex.
#
# Adding a new auto-generated file: append one glob to `statix.toml`'s
# `ignore` array; every consumer derives from here.
#
# Glob → regex translation is narrow on purpose: only `*` (any chars
# except `/`) and the literal `.` are special-cased. If the canonical
# list ever needs `**`, character classes, or other glob features,
# widen the helper rather than letting consumers diverge again.
let
  toml = builtins.fromTOML (builtins.readFile ../statix.toml);
  globs = toml.ignore;
  globToRegex =
    glob:
    let
      dotEscaped = builtins.replaceStrings [ "." ] [ "\\." ] glob;
      starExpanded = builtins.replaceStrings [ "*" ] [ "[^/]*" ] dotEscaped;
    in
    "^${starExpanded}$";
in
{
  inherit globs;
  regexes = map globToRegex globs;
}
