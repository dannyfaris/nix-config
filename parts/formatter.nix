# Tree-wide formatter. Wires `nix fmt` (via formatter.<system>) and the
# format-correctness check (via checks.<system>.treefmt). nixfmt formats
# Nix files; shfmt formats shell scripts.
#
# The assembled wrapper (config.treefmt.build.wrapper) is also consumed by
# the treefmt pre-commit hook in parts/checks.nix, so format-checking runs
# at commit-time as well as at `nix flake check`-time off this single
# config. This file stays the source of truth for the formatter list and
# its exclude globs; the hook re-declares neither (see #64, ADR-025
# §History).
#
# pkgs.nixfmt is the canonical RFC-style formatter (nixfmt 1.2+). Don't
# swap with pkgs.nixfmt-rfc-style (deprecated alias) or pkgs.nixfmt-classic
# (pre-RFC Serokell style). See home/core/shared/nix-tooling.nix for the
# comment block that's the source of truth.
{ inputs, ... }:

{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;
      programs.shfmt.enable = true;

      # Auto-generated hardware configs (per ADR-023) are overwritten in
      # their entirety by `nixos-anywhere --generate-hardware-config` on
      # regenerate; nixos-generate-config's output shape would diff
      # against the formatter on every regenerate. Excluding here keeps
      # the drop-in property intact. Same carve-out as statix.toml /
      # parts/checks.nix's autoGenExcludes.
      settings.global.excludes = [
        "hosts/*/hardware-configuration.nix"
        "hosts/nixos-vm/hardware.nix"
      ];
    };
  };
}
