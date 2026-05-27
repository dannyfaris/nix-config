# Continuous-integration outputs: per-host system.build.toplevel checks
# plus git-hooks.nix pre-commit hooks. nixfmt lives in parts/formatter.nix
# (treefmt-managed), not here, so each .nix file gets exactly one nixfmt
# pass per `nix flake check`.
#
# See docs/decisions/ADR-025-ci-in-flake.md for the framework rationale.
{ inputs, self, ... }:

{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  # Per-host toplevel derivations. Defined at the top-level flake namespace
  # (rather than inside perSystem) because flake-parts deliberately scrubs
  # `self` out of perSystem args. The system in the attribute path scopes
  # each check to the right runner — aarch64 builds nixos-vm; x86_64 builds
  # mercury + metis. Same derivation as `nixosConfigurations.<name>.config
  # .system.build.toplevel`, so Nix's store deduplicates: no double build.
  flake.checks = {
    aarch64-linux.host-nixos-vm = self.nixosConfigurations.nixos-vm.config.system.build.toplevel;
    x86_64-linux.host-mercury = self.nixosConfigurations.mercury.config.system.build.toplevel;
    x86_64-linux.host-metis = self.nixosConfigurations.metis.config.system.build.toplevel;
  };

  # Pre-commit hooks. git-hooks.nix lifts these to checks.<system>.pre-commit
  # automatically; the local hook is installed by config.pre-commit.shellHook
  # from parts/dev-shells.nix on `nix develop`.
  perSystem = _: {
    pre-commit.settings.hooks =
      let
        # Auto-generated hardware-configuration.nix files (per ADR-023) have
        # inherent statix/deadnix violations that can't be refactored
        # without breaking the regenerate-via-nixos-anywhere contract. The
        # nixos-vm legacy two-file shape (hardware.nix) is the same story.
        # Deadnix consumes this as its per-file filter. Statix runs
        # whole-tree (pass_filenames = false in git-hooks.nix), so the
        # load-bearing exclude lives in ./statix.toml; this list only
        # spares pre-commit from invoking statix when a commit touches
        # *only* the listed files.
        autoGenExcludes = [
          "^hosts/[^/]+/hardware-configuration\\.nix$"
          "^hosts/nixos-vm/hardware\\.nix$"
        ];
      in
      {
        statix = {
          enable = true;
          excludes = autoGenExcludes;
        };
        deadnix = {
          enable = true;
          excludes = autoGenExcludes;
        };
        actionlint.enable = true;

        # Enforces ADR-023's "do not hand-edit hardware-configuration.nix"
        # rule. Regex excludes hosts/nixos-vm/hardware.nix (legacy two-file
        # shape) — intentional carve-out per ADR-023.
        hardware-config-banner = {
          enable = true;
          name = "hardware-config-banner";
          entry = "bash ${../scripts/hardware-config-banner.sh}";
          files = "^hosts/[^/]+/hardware-configuration\\.nix$";
          language = "system";
          pass_filenames = true;
        };
      };
  };
}
