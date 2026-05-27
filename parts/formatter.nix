# Tree-wide formatter. Wires `nix fmt` (via formatter.<system>); the
# matching `nix flake check` enforcement (via checks.<system>.treefmt) is
# deferred until the follow-up conformance commit reformats the existing
# files. nixfmt formats Nix files; shfmt formats shell scripts.
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
      # Deferred to a follow-up conformance commit; existing files pre-date
      # the nixfmt-RFC formatter and would block CI on the initial landing.
      # `nix fmt` still works for opt-in formatting in the meantime.
      flakeCheck = false;
    };
  };
}
