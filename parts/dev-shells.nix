# Default devShell. `nix develop` (or direnv-reload via the repo's .envrc,
# per ADR-003) drops the operator into a shell with the repo's nix/sops
# tooling and — crucially — runs config.pre-commit.shellHook on entry,
# which writes .git/hooks/pre-commit and clears any stale core.hooksPath.
# That installs the hooks declared in parts/checks.nix automatically; no
# separate install step. See ADR-025 for the framework rationale.
_:

{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        # macOS lacks the XDG path sops searches on Linux for the age key, so
        # without this `sops --decrypt` errors with no-identity. Scoped to the
        # devShell because secret editing only happens inside the repo.
        shellHook = ''
          ${config.pre-commit.shellHook}
          export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
        '';
        packages = with pkgs; [
          just
          # JSON wrangling for `gh --json`, `nix eval --json`, and flake.lock —
          # the repo's routine query surfaces. Not pulled in transitively.
          jq
          nixfmt
          shfmt
          shellcheck
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
