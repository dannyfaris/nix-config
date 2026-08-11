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

  # Host-registration set-diff (lib/host-registration.nix): fleet-global data
  # binding hosts/ ↔ the flake registrations ↔ the per-host checks, so like
  # the keybind/lib checks it rides x86_64-linux once, not per host. See
  # docs/design/host-registration-binding.md.
  hostRegistration = import ../lib/host-registration.nix { inherit lib; };
  hostRegistrationTestFailures = import ../lib/tests/host-registration.nix { inherit lib; };

  # Keybind capability registry (lib/capabilities.nix): the collision lint is
  # platform data, not per-host config, so it rides mkReportCheck once on the
  # x86_64-linux runner (like the lib unit tests), not per host. See #384 / ADR-039.
  capabilities = import ../lib/capabilities.nix { inherit lib; };

  # niri config document (lib/niri-config.nix): the host builds only ever render
  # the shape their own `laptop` flag selects, so a regression in the other
  # branch would surface on one host and not the other. Force both shapes here.
  # Fixture args, not host config: the point is that the document *renders*, and
  # reading real hosts would drag Stylix eval in for no added coverage. (What
  # niri makes of the render is the separate `niri validate` gate in
  # home/nixos/niri.nix — see docs/design/niri-sourcing.md.)
  niriConfigFailures =
    let
      render =
        laptop:
        (import ../lib/niri-config.nix {
          inherit lib laptop;
          tokens = import ../lib/theme-tokens.nix { config = { }; };
          cursor = {
            theme = "check-fixture";
            size = 24;
          };
          noctalia = "/nix/store/0000000000000000000000000000000-check-fixture/bin/noctalia";
        }).text;
      # Rendering is where a bad node shape throws; the length forces it.
      probe =
        laptop:
        let
          text = render laptop;
        in
        lib.optional (
          builtins.stringLength text == 0
        ) "niri-config (laptop=${lib.boolToString laptop}) rendered an empty document";
    in
    probe false ++ probe true;

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

  # Every check for a system except the per-host toplevel builds — the set a
  # docs-only PR still must satisfy (the pre-commit hooks, treefmt, the stance
  # and lib eval checks, the keybind gates, the keybinds-table doc diff).
  # Derived by exclusion from the merged check set, so a future check is picked
  # up with no allowlist to rot. Built by ci.yaml's docs-only path instead of
  # `nix flake check`, and reproducible off-CI with
  # `nix build .#checks-without-hosts` — see docs/ci.md §"Docs-only
  # short-circuit".
  mkChecksWithoutHosts =
    system:
    let
      pkgs = pkgsFor system;
    in
    pkgs.linkFarm "checks-without-hosts" (
      lib.mapAttrsToList (name: path: { inherit name path; }) (
        lib.filterAttrs (n: _: !(lib.hasPrefix "host-" n)) self.checks.${system}
      )
    );

  # What the CI cache must carry because nothing else can supply it. The
  # Actions pool is capped at 10 GB and is worth spending only on bytes no
  # substituter serves; anything else is cheaper to re-fetch than to hoard —
  # the union of the x86_64 host closures does not fit the pool at all
  # (measured 2026-08-02, then five hosts). See docs/ci.md §"Cache sweep".
  unsubstitutable = {
    x86_64-linux = {
      # The same attribute home/nixos/noctalia.nix reads, so this is the
      # derivation the desktop hosts build rather than a parallel one.
      # v5 has no binary cache anywhere (docs/design/noctalia-v5-migration.md
      # §Cost). niri stays out for the opposite reason: since #763 it comes
      # from nixpkgs and cache.nixos.org serves it.
      noctalia = inputs.noctalia.packages.x86_64-linux.default;
      # nvidia-settings has no substituter (unfree; cache.nixos.org 404s it —
      # measured on metis 2026-08-03) and rebuilds ~90 s every warm run (#721).
      # Routed through alcyone's own config so this is the derivation alcyone
      # builds, not a parallel pkgs.linuxPackages one — kernel-coupled via
      # boot.kernelPackages. See modules/nixos/nvidia.nix.
      nvidia-settings = self.nixosConfigurations.alcyone.config.hardware.nvidia.package.settings;
    };
    # The Darwin closure has no source-only build.
    aarch64-darwin = { };
  };

  # Built with `--out-link` in CI so the save-time `nix store gc` cannot take
  # the set above. An empty farm on the legs that root nothing, so the
  # workflow keeps one command under one condition across the matrix.
  mkCiGcRoot =
    system:
    (pkgsFor system).linkFarm "ci-gc-root" (
      lib.mapAttrsToList (name: path: { inherit name path; }) unsubstitutable.${system}
    );

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
  # each check to the right runner — each leg below builds the toplevels of
  # the hosts on that system.
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
    x86_64-linux = {
      host-alcyone = self.nixosConfigurations.alcyone.config.system.build.toplevel;
      host-alnair = self.nixosConfigurations.alnair.config.system.build.toplevel;
      host-electra = self.nixosConfigurations.electra.config.system.build.toplevel;
      stances-alcyone =
        mkStanceCheck "x86_64-linux" "nixos" "alcyone"
          self.nixosConfigurations.alcyone.config;
      stances-alnair =
        mkStanceCheck "x86_64-linux" "nixos" "alnair"
          self.nixosConfigurations.alnair.config;
      stances-electra =
        mkStanceCheck "x86_64-linux" "nixos" "electra"
          self.nixosConfigurations.electra.config;
      lib-auto-gen-paths = mkUnitTestCheck "x86_64-linux" "auto-gen-paths" autoGenPathsFailures;
      lib-capabilities = mkUnitTestCheck "x86_64-linux" "capabilities" capabilitiesFailures;
      lib-host-registration =
        mkUnitTestCheck "x86_64-linux" "host-registration"
          hostRegistrationTestFailures;
      # Named `hosts-registration` (plural), not `host-registration`, so
      # mkChecksWithoutHosts's `host-` prefix filter can't eat it from the
      # docs-only set. See docs/design/host-registration-binding.md.
      hosts-registration =
        mkReportCheck "x86_64-linux" "hosts-registration"
          "Host-registration drift — hosts/ vs parts/{nixos,darwin}.nix vs parts/checks.nix (#710)"
          (
            hostRegistration.failures {
              dirs = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../hosts));
              nixosRegs = builtins.attrNames self.nixosConfigurations;
              darwinRegs = builtins.attrNames self.darwinConfigurations;
              nixosChecks = builtins.attrNames self.checks.x86_64-linux;
              darwinChecks = builtins.attrNames self.checks.aarch64-darwin;
            }
          );
      niri-config-renders =
        mkReportCheck "x86_64-linux" "niri-config-renders"
          "niri config document fails to render (lib/niri-config.nix; docs/design/niri-sourcing.md)"
          niriConfigFailures;
      keybind-collisions =
        mkReportCheck "x86_64-linux" "keybind-collisions"
          "Keybind chord collisions (lib/capabilities.nix; ADR-039 §8)"
          capabilities.collisions;
      keybind-collisions-darwin =
        mkReportCheck "x86_64-linux" "keybind-collisions-darwin"
          "Keybind chord collisions — darwin/AeroSpace (lib/capabilities.nix; ADR-039 §8, ADR-040)"
          capabilities.darwinCollisions;
      # Registry shape gate: a malformed entry (typo'd realization tag,
      # misspelled field, unmapped darwin key) is silently dropped by the
      # emitters, so its absence must fail here instead (#535).
      keybind-registry-shape =
        mkReportCheck "x86_64-linux" "keybind-registry-shape"
          "Keybind registry shape violations (lib/capabilities.nix; #535)"
          capabilities.validationFailures;
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

  flake.packages = {
    x86_64-linux = {
      # The ephemeral-root de-risk gate: a nixosTest booting off a real btrfs
      # @root/@persist/@nix layout to prove the archive-rollback mechanism before
      # any host adopts (docs/design/ephemeral-root.md §De-risk, #553). A package,
      # deliberately NOT a check: `nix flake check` builds checks, and CI runs it
      # wholesale, so a checks entry would make every hosted runner boot the
      # six-node KVM suite per PR. As a package it is evaluated by CI (pin bumps
      # that break its eval still fail) but built only on demand —
      # `nix build .#ephemeral-root-vm`, the locally-run gate. Moves into
      # checks when #546 self-hosts the x86_64-linux leg on alcyone.
      ephemeral-root-vm = import ../tests/ephemeral-root.nix {
        pkgs = pkgsFor "x86_64-linux";
        inherit self inputs;
      };

      # The docs-only CI path's build target, one per matrix leg (see
      # mkChecksWithoutHosts above). A package rather than a check: it is a
      # re-aggregation of checks this flake already exposes, so making it a check
      # would double every one of them under `nix flake check`.
      checks-without-hosts = mkChecksWithoutHosts "x86_64-linux";

      # The save-time GC root, one per matrix leg (see `unsubstitutable`
      # above). A package rather than a check: it gates nothing and returns no
      # verdict — it exists only to be built with `--out-link` in CI.
      ci-gc-root = mkCiGcRoot "x86_64-linux";
    };
    aarch64-darwin.checks-without-hosts = mkChecksWithoutHosts "aarch64-darwin";
    aarch64-darwin.ci-gc-root = mkCiGcRoot "aarch64-darwin";
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
      # (alcyone/x86_64-linux, neptune/aarch64-darwin). Same source the
      # keybinds-table check diffs against (#457).
      packages.keybinds-table = keybindsTableFragment pkgs;

      pre-commit.settings.hooks =
        let
          # Auto-generated hardware-configuration.nix files (per ADR-023) have
          # inherent statix/deadnix violations that can't be refactored
          # without breaking the regenerate-via-nixos-anywhere contract.
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
          # rule.
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

          # CLAUDE.md's host census must name exactly the directories under
          # hosts/ (#583). The lint reads the index itself, so `files`
          # matches everything and no filenames are passed — the same
          # posture as case-collisions. Enumerating the two sides instead
          # cannot work: pre-commit's staged-file list excludes deletions
          # (`--diff-filter=ACMRTUXB`), so a retire-a-host commit — which
          # only removes hosts/<name>/ — would present no matching path and
          # the hook would skip the very ghost-bullet direction it exists to
          # catch. git is injected explicitly for the same reason
          # case-collisions does: the git-hooks.nix `run` derivation scrubs
          # PATH. Lint, not generation: the census's per-host clauses are
          # hardware/role prose with no machine-readable source (ADR-032
          # Rule 1; ADR-037 adopts generation only on evidence, after the
          # lints land).
          host-census = {
            enable = true;
            name = "host-census";
            entry = "bash ${../scripts/lint-host-census.sh}";
            files = "^.*$";
            language = "system";
            pass_filenames = false;
            extraPackages = [ pkgs.git ];
          };

          # Regression coverage for the host-census linter, mirroring
          # test-shared-purity (#193). Region extraction plus a two-way set
          # diff has enough logic to break silently — a change that made it
          # pass everything would let the entry-point doc rot unnoticed,
          # which is the exact failure #583 exists to stop. Gated to the
          # linter at commit-time; always runs in CI. The fixtures are
          # throwaway git repos, so git is injected here too.
          test-host-census = {
            enable = true;
            name = "test-host-census";
            entry = "env LINT_SCRIPT=${../scripts/lint-host-census.sh} bash ${../scripts/test-lint-host-census.sh}";
            files = "^scripts/lint-host-census\\.sh$";
            language = "system";
            pass_filenames = false;
            extraPackages = [ pkgs.git ];
          };

          # Guards against two tracked paths differing only by case, which
          # cannot coexist in a checkout on a case-insensitive filesystem
          # (APFS: neptune, the macos-15 CI leg) — one silently
          # clobbers the other, and the Linux box that authored the pair
          # cannot see the breakage. The lint reads the index itself, so
          # `files` matches everything and no filenames are passed. git is
          # injected explicitly: the git-hooks.nix `run` derivation scrubs
          # PATH (same reason bundle-purity injects pkgs.nix). No paired
          # self-test, deliberately — ADR-032 item 3 retired bundle-purity's,
          # and this pipeline is far simpler than that one.
          case-collisions = {
            enable = true;
            name = "case-collisions";
            entry = "bash ${../scripts/lint-case-collisions.sh}";
            files = "^.*$";
            language = "system";
            pass_filenames = false;
            extraPackages = [ pkgs.git ];
          };
        };
    };
}
