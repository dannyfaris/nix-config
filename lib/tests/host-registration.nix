# Unit tests for lib/host-registration.nix's four-surface set-diff — the
# agreement check between hosts/ directories, the flake registrations, and
# the per-host host-*/stances-* checks. A silent bug here would let a host
# fall out of the deliberate-stance net (or a retired host linger in a
# check) without CI noticing. Evaluated via pkgs.lib.runTests, which returns
# a list of failure records ({ name; expected; result; }); parts/checks.nix
# renders that list into a CI-gated derivation. See ADR-033 and
# docs/design/host-registration-binding.md.
{ lib }:
let
  hostReg = import ../host-registration.nix { inherit lib; };
  inherit (hostReg) failures;

  # The real-fleet shape (3 nixos, 1 darwin), all four surfaces agreeing —
  # the baseline every drift fixture perturbs by exactly one edit.
  clean = {
    dirs = [
      "alcyone"
      "alnair"
      "electra"
      "celaeno"
    ];
    nixosRegs = [
      "alcyone"
      "alnair"
      "electra"
    ];
    darwinRegs = [
      "celaeno"
    ];
    nixosChecks = [
      "host-alcyone"
      "host-alnair"
      "host-electra"
      "stances-alcyone"
      "stances-alnair"
      "stances-electra"
      "lib-capabilities"
      "keybinds-table"
      "pre-commit"
      "treefmt"
    ];
    darwinChecks = [
      "host-celaeno"
      "stances-celaeno"
      "pre-commit"
      "treefmt"
    ];
  };
in
lib.runTests {
  # 1 — Clean fleet: all four surfaces agree ⇒ no failures.
  testCleanPass = {
    expr = failures clean;
    expected = [ ];
  };

  # 2 — A directory with no registration is the invisible-orphan case.
  testDirNoRegistration = {
    expr = failures (clean // { dirs = clean.dirs ++ [ "foo" ]; });
    expected = [
      "hosts/foo/ exists but foo is registered in neither parts/nixos.nix nor parts/darwin.nix → add `foo = mkHost { hostname = \"foo\"; };` to parts/nixos.nix, or remove hosts/foo/"
    ];
  };

  # 3 — A registration with no directory (a half-removed retirement).
  testRegistrationNoDir = {
    expr = failures (clean // { nixosRegs = clean.nixosRegs ++ [ "ghost" ]; });
    expected = [
      "ghost is registered but hosts/ghost/ does not exist → remove the registration, or add hosts/ghost/"
      "ghost is in parts/nixos.nix but has no host-ghost build check → add `host-ghost = self.nixosConfigurations.ghost.config.system.build.toplevel;` to parts/checks.nix (flake.checks.x86_64-linux)"
      "ghost is in parts/nixos.nix but has no stances-ghost check → add `stances-ghost = mkStanceCheck \"x86_64-linux\" \"nixos\" \"ghost\" self.nixosConfigurations.ghost.config;` to parts/checks.nix"
    ];
  };

  # 4 — Registered with a dir but no host-* build check.
  testRegisteredNoHostCheck = {
    expr = failures (
      clean
      // {
        dirs = clean.dirs ++ [ "bar" ];
        nixosRegs = clean.nixosRegs ++ [ "bar" ];
        nixosChecks = clean.nixosChecks ++ [ "stances-bar" ];
      }
    );
    expected = [
      "bar is in parts/nixos.nix but has no host-bar build check → add `host-bar = self.nixosConfigurations.bar.config.system.build.toplevel;` to parts/checks.nix (flake.checks.x86_64-linux)"
    ];
  };

  # 5 — Registered with a dir and a host-* build but no stances-* check:
  # the built-but-stance-unchecked orphan #710 most wants to catch.
  testRegisteredNoStanceCheck = {
    expr = failures (
      clean
      // {
        dirs = clean.dirs ++ [ "bar" ];
        nixosRegs = clean.nixosRegs ++ [ "bar" ];
        nixosChecks = clean.nixosChecks ++ [ "host-bar" ];
      }
    );
    expected = [
      "bar is in parts/nixos.nix but has no stances-bar check → add `stances-bar = mkStanceCheck \"x86_64-linux\" \"nixos\" \"bar\" self.nixosConfigurations.bar.config;` to parts/checks.nix"
    ];
  };

  # 6 — A darwin host's host-* check placed under the x86_64-linux set.
  testWrongPlatformPlacement = {
    expr = failures (clean // { nixosChecks = clean.nixosChecks ++ [ "host-celaeno" ]; });
    expected = [
      "host-celaeno appears under checks.x86_64-linux but celaeno is a darwinConfiguration → move it to flake.checks.aarch64-darwin"
    ];
  };

  # 7 — Darwin leg of fixture 2: a darwin directory with no registration.
  testDarwinDirNoRegistration = {
    expr = failures (clean // { dirs = clean.dirs ++ [ "phobos" ]; });
    expected = [
      "hosts/phobos/ exists but phobos is registered in neither parts/nixos.nix nor parts/darwin.nix → add `phobos = mkHost { hostname = \"phobos\"; };` to parts/nixos.nix, or remove hosts/phobos/"
    ];
  };

  # 8 — Darwin leg of fixture 5: a registered darwin host with a build but
  # no stances-* check, in the darwin voice (parts/darwin.nix, aarch64).
  testDarwinRegisteredNoStanceCheck = {
    expr = failures (
      clean
      // {
        dirs = clean.dirs ++ [ "titan" ];
        darwinRegs = clean.darwinRegs ++ [ "titan" ];
        darwinChecks = clean.darwinChecks ++ [ "host-titan" ];
      }
    );
    expected = [
      "titan is in parts/darwin.nix but has no stances-titan check → add `stances-titan = mkStanceCheck \"aarch64-darwin\" \"darwin\" \"titan\" self.darwinConfigurations.titan.config;` to parts/checks.nix"
    ];
  };

  # 9 — Two independent drifts at once: a dir-orphan and a missing stance.
  # The full list is asserted (order-stable), not just the count.
  testMultipleDrifts = {
    expr = failures (
      clean
      // {
        dirs = clean.dirs ++ [ "foo" ];
        nixosChecks = lib.filter (n: n != "stances-alnair") clean.nixosChecks;
      }
    );
    expected = [
      "hosts/foo/ exists but foo is registered in neither parts/nixos.nix nor parts/darwin.nix → add `foo = mkHost { hostname = \"foo\"; };` to parts/nixos.nix, or remove hosts/foo/"
      "alnair is in parts/nixos.nix but has no stances-alnair check → add `stances-alnair = mkStanceCheck \"x86_64-linux\" \"nixos\" \"alnair\" self.nixosConfigurations.alnair.config;` to parts/checks.nix"
    ];
  };

  # 10 — Empty fleet: every set empty ⇒ no synthesized phantom failure.
  testEmptyFleet = {
    expr = failures {
      dirs = [ ];
      nixosRegs = [ ];
      darwinRegs = [ ];
      nixosChecks = [ ];
      darwinChecks = [ ];
    };
    expected = [ ];
  };

  # 11 — Prefix-pair non-masking: electra registered, electra-2 dir-only.
  # electra-2 must be flagged and electra must NOT be — a substring/hasPrefix
  # match on "electra" would wrongly satisfy electra-2 (the census
  # metis/metis-2 lesson).
  #
  # Fixtures are self-contained rather than derived from `clean`: the pair's
  # registered half must stay registered for the test to discriminate at all,
  # and deriving it from the fleet let a host retirement silently disarm this
  # case once already (#387 — the prior pair was metis/metis-2, and removing
  # metis from `clean` made the assertion pass under the very bug it guards).
  testPrefixPairNonMasking = {
    expr = failures {
      dirs = [
        "electra"
        "electra-2"
      ];
      nixosRegs = [ "electra" ];
      darwinRegs = [ ];
      nixosChecks = [
        "host-electra"
        "stances-electra"
      ];
      darwinChecks = [ ];
    };
    expected = [
      "hosts/electra-2/ exists but electra-2 is registered in neither parts/nixos.nix nor parts/darwin.nix → add `electra-2 = mkHost { hostname = \"electra-2\"; };` to parts/nixos.nix, or remove hosts/electra-2/"
    ];
  };
}
