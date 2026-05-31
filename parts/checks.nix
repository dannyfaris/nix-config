# Continuous-integration outputs: per-host system.build.toplevel checks
# plus git-hooks.nix pre-commit hooks. The formatter list (nixfmt + shfmt)
# and its exclude globs are defined once in parts/formatter.nix; the
# treefmt pre-commit hook below reuses that same wrapper rather than
# re-declaring the tools, so format enforcement at commit-time and at
# `nix flake check`/CI-time share a single source of truth.
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
  #
  # `config` is in scope so the treefmt hook can reuse the wrapper that
  # parts/formatter.nix builds (config.treefmt.build.wrapper) — flake-parts
  # merges every perSystem module, so the formatter's config resolves here.
  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit.settings.hooks =
        let
          # Auto-generated hardware-configuration.nix files (per ADR-023) have
          # inherent statix/deadnix violations that can't be refactored
          # without breaking the regenerate-via-nixos-anywhere contract. The
          # nixos-vm legacy two-file shape (hardware.nix) is the same story.
          # Deadnix consumes this as its per-file filter. Statix runs
          # whole-tree (pass_filenames = false in git-hooks.nix) and reads
          # statix.toml at run-time for its own ignore set; this list only
          # spares pre-commit from invoking statix when a commit touches
          # *only* the listed files. Canonical list lives in statix.toml;
          # lib/auto-gen-paths.nix reads it and exposes the regex form.
          autoGenExcludes = (import ../lib/auto-gen-paths.nix).regexes;
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

          # Format enforcement at commit-time. Reuses the treefmt wrapper
          # built by parts/formatter.nix (config.treefmt.build.wrapper)
          # rather than re-declaring nixfmt/shfmt or their exclude globs,
          # so the formatter list and carve-outs stay single-source. Before
          # this hook, format violations were caught only at
          # `nix flake check`/CI-time (via checks.<system>.treefmt), which
          # stays in place as the belt-and-braces CI gate — a multiline
          # string mis-format in greetd.nix slipped past a local commit and
          # only failed in CI (#54 P5.5). Per #64.
          treefmt = {
            enable = true;
            packageOverrides.treefmt = config.treefmt.build.wrapper;
          };

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

          # Enforces platform-purity in shared/ trees: code under
          # modules/shared/ and home/shared/ must be platform-
          # agnostic (no stdenv.isDarwin etc.). Preventative — both trees
          # are clean today; lint protects against drift as Darwin onboards.
          shared-purity = {
            enable = true;
            name = "shared-purity";
            entry = "bash ${../scripts/lint-shared-purity.sh}";
            files = "^(modules|home)/shared/.*\\.nix$";
            language = "system";
            pass_filenames = true;
          };

          # Enforces ADR-027 §Decision / PRD §8.1 #4 bundle-purity on
          # foundation.nix and every bundles/<X>.nix file: an aggregator
          # must contain `{ imports = [ ≥ 2 distinct entries ]; }` and
          # nothing else — no inline option setting, no extra top-level
          # attributes. Replaces the retired role-purity rule.
          bundle-purity = {
            enable = true;
            name = "bundle-purity";
            entry = "bash ${../scripts/lint-bundle-purity.sh}";
            files = "^(modules|home)/[^/]+/(bundles/.*|foundation)\\.nix$";
            language = "system";
            pass_filenames = true;
            # git-hooks.nix's `run` derivation scrubs PATH; the lint
            # uses `nix-instantiate --parse` for canonicalisation and
            # needs the binary injected explicitly. `pkgs.nix` pins
            # the parser to the same Nix the flake itself uses, so the
            # lint's parsed-AST shape can't drift from what other tools
            # in the dev-shell see.
            extraPackages = [ pkgs.nix ];
          };
        };
    };
}
