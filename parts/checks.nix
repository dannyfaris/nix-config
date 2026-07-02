# Continuous-integration outputs: per-host system.build.toplevel checks,
# the deliberate-stance + lib unit-test eval checks (ADR-033), plus
# git-hooks.nix pre-commit hooks. The formatter list (nixfmt + shfmt)
# and its exclude globs are defined once in parts/formatter.nix; the
# treefmt pre-commit hook below reuses that same wrapper rather than
# re-declaring the tools, so format enforcement at commit-time and at
# `nix flake check`/CI-time share a single source of truth.
#
# See docs/decisions/ADR-025-ci-in-flake.md for the framework rationale,
# and docs/decisions/ADR-033-eval-checks-stances-and-lib-units.md for the
# stance/unit-test layer the toplevel builds structurally can't cover.
{ inputs, self, ... }:

let
  lib = inputs.nixpkgs.lib;

  # The deliberate-stance assertions (lib/stances.nix) and the lib unit
  # tests (lib/tests/auto-gen-paths.nix) are pure eval — they produce
  # lists of failures, which mkReportCheck turns into check derivations.
  stances = import ../lib/stances.nix { inherit lib; };
  autoGenPathsFailures = import ../lib/tests/auto-gen-paths.nix { inherit lib; };
  capabilitiesFailures = import ../lib/tests/capabilities.nix { inherit lib; };

  # Keybind capability registry (lib/capabilities.nix): the collision lint is
  # platform data, not per-host config, so it rides mkReportCheck once on the
  # x86_64-linux runner (like the lib unit tests), not per host. See #384 / ADR-039.
  capabilities = import ../lib/capabilities.nix { inherit lib; };

  pkgsFor = system: inputs.nixpkgs.legacyPackages.${system};

  # Render a list of failure strings into a check derivation: a no-op
  # success when empty, otherwise a build that prints the report to stderr
  # and fails. The report passes through a file (passAsFile) so the
  # messages need no shell-escaping.
  mkReportCheck =
    system: name: header: failures:
    let
      pkgs = pkgsFor system;
    in
    if failures == [ ] then
      pkgs.runCommand name { } ''echo "${header}: ok" > "$out"''
    else
      pkgs.runCommand name
        {
          report = header + ":\n" + lib.concatMapStrings (f: "  - ${f}\n") failures;
          passAsFile = [ "report" ];
        }
        ''
          cat "$reportPath" >&2
          exit 1
        '';

  # One deliberate-stance check per host: evaluate the platform's stance
  # assertions against the host config; fail with the violation list.
  mkStanceCheck =
    system: platform: hostName: config:
    mkReportCheck system "stances-${hostName}"
      "Deliberate-stance violations on ${hostName} (CLAUDE.md §Deliberate stances; ADR-033)"
      (stances.${platform} config);

  # The keybinds.md generated table (#457; ADR-039 §Impl step 3). The fragment
  # is the registry-emitted markdown (trailing newline so the byte-diff against
  # the doc's marked region is exact); exposed as a package so the writer
  # (scripts/gen-keybinds-table.sh, via `just gen-keybinds`) and this check share
  # one source. First concrete instance of ADR-037's "Generated — the facts"
  # rung 3 (the generate-and-diff harness).
  keybindsTableFragment =
    pkgs: pkgs.writeText "keybinds-table.md" (capabilities.keybindsTable + "\n");

  # Extract the region between the doc's BEGIN/END markers and diff it against the
  # fragment; fail with the diff if the committed table is stale.
  mkKeybindsTableCheck =
    system:
    let
      pkgs = pkgsFor system;
      fragment = keybindsTableFragment pkgs;
      doc = ../docs/desktop/keybinds.md;
    in
    pkgs.runCommand "keybinds-table" { } ''
      ${pkgs.gawk}/bin/awk '
        /^<!-- END GENERATED: hyper-bindings/ { capture = 0 }
        capture { print }
        /^<!-- BEGIN GENERATED: hyper-bindings/ { capture = 1 }
      ' ${doc} > region.md
      if ${pkgs.diffutils}/bin/diff -u ${fragment} region.md > diff.txt; then
        echo "keybinds.md hyper table is up to date" > "$out"
      else
        echo "docs/desktop/keybinds.md generated region is STALE — run 'just gen-keybinds':" >&2
        cat diff.txt >&2
        exit 1
      fi
    '';

  # lib.runTests returns records { name; expected; result; }; flatten each
  # to a legible one-liner for the report.
  mkUnitTestCheck =
    system: name: runTestsFailures:
    mkReportCheck system "unit-${name}" "lib.runTests failures in ${name} (ADR-033)" (
      map (
        f:
        "${f.name}: expected ${lib.generators.toPretty { } f.expected}, got ${
          lib.generators.toPretty { } f.result
        }"
      ) runTestsFailures
    );
in
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  # Per-host toplevel derivations. Defined at the top-level flake namespace
  # (rather than inside perSystem) because flake-parts deliberately scrubs
  # `self` out of perSystem args. The system in the attribute path scopes
  # each check to the right runner — aarch64-linux builds nixos-vm;
  # x86_64-linux builds mercury + metis; aarch64-darwin builds neptune.
  # For NixOS hosts the derivation is `nixosConfigurations.<name>.config
  # .system.build.toplevel`; for Darwin it's the nix-darwin convenience
  # alias `darwinConfigurations.<name>.system` (same derivation as
  # `.config.system.build.toplevel`, verified by drvPath equality). Either
  # way, Nix's store deduplicates: no double build.
  #
  # The Darwin entry closes the CI-coverage gap that issue #190 named —
  # before this entry, modules/darwin/*, home/darwin/*, and the
  # hosts/neptune composition had zero structural verification. The
  # README's "CI builds every host on every PR" claim becomes true again
  # alongside (the same PR fixes the README's stale "Three hosts today"
  # line that lagged the 2026-06-02 onboarding of neptune, then named
  # mac-mini). The matching macOS runner is declared in the ci.yaml matrix
  # (see that file for the runner-pinning + cache-budget rationale).
  # Each host carries a `host-*` toplevel build (does it compile?) and a
  # `stances-*` eval check (does it still hold the deliberate stances?).
  # The lib unit tests are pure eval and platform-independent, so they run
  # once on the x86_64-linux runner rather than redundantly on each.
  flake.checks = {
    aarch64-linux = {
      host-nixos-vm = self.nixosConfigurations.nixos-vm.config.system.build.toplevel;
      stances-nixos-vm =
        mkStanceCheck "aarch64-linux" "nixos" "nixos-vm"
          self.nixosConfigurations.nixos-vm.config;
    };
    x86_64-linux = {
      host-mercury = self.nixosConfigurations.mercury.config.system.build.toplevel;
      host-metis = self.nixosConfigurations.metis.config.system.build.toplevel;
      stances-mercury =
        mkStanceCheck "x86_64-linux" "nixos" "mercury"
          self.nixosConfigurations.mercury.config;
      stances-metis = mkStanceCheck "x86_64-linux" "nixos" "metis" self.nixosConfigurations.metis.config;
      lib-auto-gen-paths = mkUnitTestCheck "x86_64-linux" "auto-gen-paths" autoGenPathsFailures;
      lib-capabilities = mkUnitTestCheck "x86_64-linux" "capabilities" capabilitiesFailures;
      keybind-collisions =
        mkReportCheck "x86_64-linux" "keybind-collisions"
          "Keybind chord collisions (lib/capabilities.nix; ADR-039 §8)"
          capabilities.collisions;
      keybind-collisions-darwin =
        mkReportCheck "x86_64-linux" "keybind-collisions-darwin"
          "Keybind chord collisions — darwin/AeroSpace (lib/capabilities.nix; ADR-039 §8, ADR-040)"
          capabilities.darwinCollisions;
      # Doc-freshness gate: the keybinds.md generated region must equal the
      # registry's emitted table. Platform-independent like the unit tests, so it
      # rides the x86_64-linux runner once (#457; ADR-037 rung 3).
      keybinds-table = mkKeybindsTableCheck "x86_64-linux";
    };
    aarch64-darwin = {
      host-neptune = self.darwinConfigurations.neptune.system;
      stances-neptune =
        mkStanceCheck "aarch64-darwin" "darwin" "neptune"
          self.darwinConfigurations.neptune.config;
    };
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
      # The registry-emitted keybinds.md fragment, exposed per-system so the
      # writer (`just gen-keybinds` → scripts/gen-keybinds-table.sh) can
      # `nix build .#keybinds-table` on whichever host the operator is on
      # (metis/x86_64-linux, neptune/aarch64-darwin). Same source the
      # keybinds-table check diffs against (#457).
      packages.keybinds-table = keybindsTableFragment pkgs;

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

          # Shell correctness for the repo's own bash. shfmt (via the treefmt
          # hook) only formats; shellcheck catches unquoted expansions,
          # set -e foot-guns, and unused/undefined vars. The built-in hook
          # selects files by `types = [ "shell" ]` — pre-commit detects the
          # bash dialect from each script's shebang, so every scripts/*.sh
          # and the home/shared/*-statusline.sh files are covered at default
          # severity with no per-file directives. Lifts to
          # checks.<system>.pre-commit like the others, so it gates CI too.
          #
          # Out of scope: the justfile's embedded bash. `just` recipes aren't
          # standalone .sh files (no shebang for pre-commit to detect), and
          # linting them would mean parsing `just --dump` — fragile for the
          # marginal gain. The install/bootstrap recipes stay reviewer-side.
          shellcheck.enable = true;

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

          # Enforces ADR-027 §Decision / PRD §8.1 #3 bundle-purity on
          # foundation.nix and every bundles/<X>.nix file: an aggregator
          # must be exactly `{ imports = [ ... ]; }` and nothing else — no
          # inline option setting, no extra top-level attributes. Gates the
          # shape only; the ≥2-distinct sub-rule is a convention per ADR-032.
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

          # Regression coverage for the shared-purity linter itself
          # (#193). The linter gates every shared/ file at commit-time, but
          # a change that broke its detection — e.g. made it pass everything
          # silently — would otherwise sail through and the purity guarantee
          # would quietly evaporate. This self-test exercises the linter's
          # negative paths against synthetic fixtures. (bundle-purity has no
          # parallel self-test — retired under ADR-032 item 3.)
          #
          # Wired as a system hook (not a separate flake.checks derivation):
          # the linter is a pre-commit hook, and git-hooks.nix lifts this to
          # checks.<system>.pre-commit too, so it lives inside
          # `nix flake check` per ADR-025 with no extra derivation plumbing.
          #
          # `files` gates the test to its linter: at commit-time it runs
          # only when the linter is edited; in CI (`pre-commit run
          # --all-files`) the linter file always matches, so it always runs.
          # `pass_filenames = false` — the test generates its own fixtures
          # and ignores positional args. LINT_SCRIPT points the test at the
          # linter's store path (the store interns each file separately, so
          # the test's sibling-lookup default can't find it).
          test-shared-purity = {
            enable = true;
            name = "test-shared-purity";
            entry = "env LINT_SCRIPT=${../scripts/lint-shared-purity.sh} bash ${../scripts/test-lint-shared-purity.sh}";
            files = "^scripts/lint-shared-purity\\.sh$";
            language = "system";
            pass_filenames = false;
            # No extraPackages: the shared linter is pure grep, no Nix.
          };

          # The *audit* rung of the design loop's enforcement ladder
          # (docs/design/design-loop.md §The reconcile hypothesis). Gates the
          # structural PRESENCE of a design note — template sections present,
          # in order, none left unfilled — not its QUALITY, which is a
          # judgment call left to peer review (ADR-032: presence-only keeps
          # this out of the brittleness trap). README/_template are skipped
          # by the linter (basename). The `/design` skill runs the same
          # script as an in-loop self-check, so CI and the skill share one
          # source of truth.
          design-note-structure = {
            enable = true;
            name = "design-note-structure";
            entry = "bash ${../scripts/lint-design-note.sh}";
            files = "^docs/design/.*\\.md$";
            language = "system";
            pass_filenames = true;
            # No extraPackages: pure bash builtins + grep, no Nix.
          };

          # Regression coverage for the design-note linter, mirroring
          # test-shared-purity (#193): a change that made the structure lint
          # silently pass everything would evaporate the guarantee. Gated to
          # the linter at commit-time; always runs in CI. pass_filenames =
          # false — the test builds its own fixtures.
          test-design-note-structure = {
            enable = true;
            name = "test-design-note-structure";
            entry = "env LINT_SCRIPT=${../scripts/lint-design-note.sh} bash ${../scripts/test-lint-design-note.sh}";
            files = "^scripts/lint-design-note\\.sh$";
            language = "system";
            pass_filenames = false;
          };
        };
    };
}
