# Default devShell. `nix develop` (or direnv-reload via the repo's .envrc,
# per ADR-003) drops the operator into a shell with the repo's nix/sops
# tooling and — crucially — runs config.pre-commit.shellHook on entry,
# which writes .git/hooks/pre-commit and clears core.hooksPath. That
# installs the hooks declared in parts/checks.nix automatically; no
# `just install-hooks` step (the old imperative install path is removed
# in a follow-up commit per ADR-025).
_:

{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        inherit (config.pre-commit) shellHook;
        packages = with pkgs; [
          just
          nixfmt
          shfmt
          statix
          deadnix
          actionlint
          nix-output-monitor
          sops
          age
        ];
      };
    };
}
