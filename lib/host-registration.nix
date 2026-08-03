# Machine-checkable agreement between the four hand-maintained surfaces
# that must name the same fleet: the `hosts/<name>/` directories, the
# flake's nixos/darwin registrations (parts/{nixos,darwin}.nix), and the
# per-host `host-*` build + `stances-*` eval checks (parts/checks.nix).
# Each of these is edited by hand when a host is added or retired, and
# nothing binds them — a host registered but never given a `stances-*`
# check builds green while silently exempt from the deliberate-stance net
# it should be under. This function returns a list of human-legible
# failure strings (empty ⇒ every surface agrees); parts/checks.nix renders
# the list into a CI-gated derivation via mkReportCheck, so a drift fails
# `nix flake check` instead of merging invisibly. #710 extends #583's
# census-binding direction from prose to flake data.
#
# Names only, deliberately: the inputs are attr-name/dir-name *sets*, so a
# hostname-string arg that disagrees with its attr key
# (foo = mkHost { hostname = "bar"; }, or a wrong mkStanceCheck host arg)
# is an accepted gap — catching it needs source-parsing or forced config
# eval. Mirrors #583's own names-only scope. See
# docs/design/host-registration-binding.md §Unresolved questions.
#
# Consumed by parts/checks.nix; tested by lib/tests/host-registration.nix.
# See ADR-032 (proportionate enforcement — lightest mechanism that holds)
# and ADR-033 (pure-eval checks producing failure lists).
{ lib }:
let
  # Set difference as a sorted list: elements of `a` absent from `b`.
  minus = a: b: lib.filter (x: !(lib.elem x b)) a;

  # Strip a fixed prefix from every element that carries it, dropping the
  # rest — turns the `host-*`/`stances-*` slice of a check-name set into the
  # bare host-name set it certifies.
  namesWithPrefix =
    prefix: names: map (lib.removePrefix prefix) (lib.filter (lib.hasPrefix prefix) names);
in
{
  # dirs         : attr-name list of hosts/<name>/ directories (readDir, filtered to "directory")
  # nixosRegs    : builtins.attrNames self.nixosConfigurations
  # darwinRegs   : builtins.attrNames self.darwinConfigurations
  # nixosChecks  : builtins.attrNames self.checks.x86_64-linux
  # darwinChecks : builtins.attrNames self.checks.aarch64-darwin
  failures =
    {
      dirs,
      nixosRegs,
      darwinRegs,
      nixosChecks,
      darwinChecks,
    }:
    let
      allRegs = nixosRegs ++ darwinRegs;

      # (1) Directory set ↔ union of both registrations. The dirs carry no
      # intrinsic platform tag; registration is the platform authority.
      dirNoReg = map (
        n:
        "hosts/${n}/ exists but ${n} is registered in neither parts/nixos.nix nor parts/darwin.nix → add `${n} = mkHost { hostname = \"${n}\"; };` to parts/nixos.nix, or remove hosts/${n}/"
      ) (minus dirs allRegs);
      regNoDir = map (
        n: "${n} is registered but hosts/${n}/ does not exist → remove the registration, or add hosts/${n}/"
      ) (minus allRegs dirs);

      # (2) Per-platform registration ↔ host-* build check.
      nixosHostChecks = namesWithPrefix "host-" nixosChecks;
      darwinHostChecks = namesWithPrefix "host-" darwinChecks;

      regNoHostCheck =
        platform: file: alias: system: regs: hostCheckNames:
        map (
          n:
          "${n} is in ${file} but has no host-${n} build check → add `host-${n} = self.${platform}.${n}.${alias};` to parts/checks.nix (flake.checks.${system})"
        ) (minus regs hostCheckNames);

      # (3) Per-platform registration ↔ stances-* eval check.
      nixosStanceChecks = namesWithPrefix "stances-" nixosChecks;
      darwinStanceChecks = namesWithPrefix "stances-" darwinChecks;

      regNoStanceCheck =
        platform: file: mkArgs: regs: stanceCheckNames:
        map (
          n:
          "${n} is in ${file} but has no stances-${n} check → add `stances-${n} = mkStanceCheck ${mkArgs} \"${n}\" self.${platform}.${n}.config;` to parts/checks.nix"
        ) (minus regs stanceCheckNames);

      # Stray host-*/stances-* checks whose name is registered on neither
      # platform — an unregistered leftover under either check set.
      strayCheck =
        kind: system: checkNames:
        map (
          n:
          "${kind}-${n} appears under checks.${system} but ${n} is registered in no configuration → remove the check, or register ${n}"
        ) (minus checkNames allRegs);

      # (4) Cross-platform placement: a host-*/stances-* check for one
      # platform's host must not sit under the other platform's check set
      # (e.g. host-neptune, a darwinConfiguration, under checks.x86_64-linux).
      wrongPlatform =
        kind: system: otherSystem: checkNames: otherRegs:
        map (
          n:
          "${kind}-${n} appears under checks.${system} but ${n} is a ${
            if system == "x86_64-linux" then "darwinConfiguration" else "nixosConfiguration"
          } → move it to flake.checks.${otherSystem}"
        ) (lib.filter (n: lib.elem n otherRegs) checkNames);
    in
    dirNoReg
    ++ regNoDir
    ++
      regNoHostCheck "nixosConfigurations" "parts/nixos.nix" "config.system.build.toplevel" "x86_64-linux"
        nixosRegs
        nixosHostChecks
    ++
      regNoHostCheck "darwinConfigurations" "parts/darwin.nix" "system" "aarch64-darwin" darwinRegs
        darwinHostChecks
    ++
      regNoStanceCheck "nixosConfigurations" "parts/nixos.nix" "\"x86_64-linux\" \"nixos\"" nixosRegs
        nixosStanceChecks
    ++
      regNoStanceCheck "darwinConfigurations" "parts/darwin.nix" "\"aarch64-darwin\" \"darwin\""
        darwinRegs
        darwinStanceChecks
    ++ wrongPlatform "host" "x86_64-linux" "aarch64-darwin" nixosHostChecks darwinRegs
    ++ wrongPlatform "host" "aarch64-darwin" "x86_64-linux" darwinHostChecks nixosRegs
    ++ wrongPlatform "stances" "x86_64-linux" "aarch64-darwin" nixosStanceChecks darwinRegs
    ++ wrongPlatform "stances" "aarch64-darwin" "x86_64-linux" darwinStanceChecks nixosRegs
    ++ strayCheck "host" "x86_64-linux" (minus nixosHostChecks darwinRegs)
    ++ strayCheck "host" "aarch64-darwin" (minus darwinHostChecks nixosRegs)
    ++ strayCheck "stances" "x86_64-linux" (minus nixosStanceChecks darwinRegs)
    ++ strayCheck "stances" "aarch64-darwin" (minus darwinStanceChecks nixosRegs);
}
