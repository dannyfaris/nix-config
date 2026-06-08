# Unit tests for lib/auto-gen-paths.nix's glob→regex translation — the
# one piece of real logic in lib/ (a silent bug here mis-scopes the
# formatter and the statix/deadnix excludes across the whole tree).
# Evaluated via pkgs.lib.runTests, which returns a list of failure
# records ({ name; expected; result; }); parts/checks.nix renders that
# list into a CI-gated derivation. See ADR-033.
{ lib }:
let
  autoGenPaths = import ../auto-gen-paths.nix;
  inherit (autoGenPaths) globToRegex globs regexes;
in
lib.runTests {
  # `.` is a regex metacharacter, so it must be escaped to match a
  # literal dot (otherwise `hardware.nix` would also match `hardwareXnix`).
  testDotIsEscaped = {
    expr = globToRegex "a.b";
    expected = "^a\\.b$";
  };

  # `*` expands to "any run of non-slash chars" — a single path segment,
  # not a cross-directory `**`.
  testStarBecomesNonSlash = {
    expr = globToRegex "*";
    expected = "^[^/]*$";
  };

  # The canonical ADR-023 carve-out glob: one `*` segment plus an escaped
  # dot, anchored at both ends.
  testHardwareConfigGlob = {
    expr = globToRegex "hosts/*/hardware-configuration.nix";
    expected = "^hosts/[^/]*/hardware-configuration\\.nix$";
  };

  # A literal path (no `*`) round-trips with only the dot escaped.
  testLiteralPathNoStar = {
    expr = globToRegex "hosts/nixos-vm/hardware.nix";
    expected = "^hosts/nixos-vm/hardware\\.nix$";
  };

  # Multiple `*` each expand independently.
  testMultipleStars = {
    expr = globToRegex "x*y*z";
    expected = "^x[^/]*y[^/]*z$";
  };

  # Integration: the public `regexes` really is `globToRegex` mapped over
  # the canonical glob list parsed from statix.toml — the contract every
  # Nix-side consumer relies on.
  testRegexesDerivedFromGlobs = {
    expr = regexes == map globToRegex globs;
    expected = true;
  };

  # statix.toml's `ignore` list is non-empty, so the parse + read path
  # actually produced something (guards against a silently-empty carve-out).
  testGlobsNonEmpty = {
    expr = globs != [ ];
    expected = true;
  };
}
