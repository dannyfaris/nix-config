# Darwin variant of home/shared/agent-clis-extras.nix. Same opt-in
# extras (Codex + Gemini CLI), but with `codex` overridden to use the
# upstream-published prebuilt aarch64-darwin binary instead of
# nixpkgs's `rustPlatform.buildRustPackage` source build.
#
# Why: nixpkgs's source build of codex (Rust crate + librusty_v8 link
# = the V8 JavaScript engine) is the dominant cost in cold-cache
# Darwin CI runs — empirically 15-20 min of the 40-55 min wall-clock
# observed in PR #218's first runs (#220 diagnostic). cache.nixos.org
# doesn't carry a substitute for the current version on aarch64-darwin
# (verified 404), so CI rebuilds it from scratch every cold runner.
# The upstream prebuilt at `github.com/openai/codex/releases` is the
# same vendor, same Apache-2.0 license, same Mach-O arm64 executable
# linked only against macOS system frameworks (verified via `otool -L`)
# — drop-in replacement. Build cost collapses to `curl + tar + cp`
# (~30s on a runner), eliminating the V8 link entirely.
#
# Trade-off: we trust OpenAI's release-signing chain instead of
# rebuilding from audited Rust source. Same trust shape as the
# `pkgs.cursor-cli` prebuilt-binary path we already accept (also
# `sourceProvenance = [ binaryNativeCode ]`; vendor-published Mach-O
# binary downloaded via `fetchurl`, no source build).
#
# Linux hosts (mercury, metis, nixos-vm) are unaffected — they continue
# to import home/shared/agent-clis-extras.nix and use pkgs.codex
# unchanged. cache.nixos.org has aarch64-linux / x86_64-linux substitutes
# for codex, so Linux pays no cold-rebuild cost. This override is purely
# a Darwin-side optimisation.
#
# Per-version maintenance: bumping codex on Darwin is a two-line change
# (version + hash). Operator should bump in lockstep with whatever
# version they want to track — no obligation to follow nixpkgs's Hydra
# cadence. See #220 for the full alternatives analysis (this file
# is "Option A" from that issue).
#
# Bump recipe:
#   1. Update `version` below to the new upstream release tag (the
#      bare semver — `version` is interpolated into the `rust-v<N>`
#      release-tag path). Latest tags at
#      https://github.com/openai/codex/releases.
#   2. Re-hash the tarball:
#        nix store prefetch-file --hash-type sha256 \
#          "https://github.com/openai/codex/releases/download/rust-v<NEW>/codex-aarch64-apple-darwin.tar.gz"
#      Paste the printed `sha256-...=` SRI value into `hash` below.
#
# `nh darwin switch` will fetch from GitHub on first build —
# cache.nixos.org doesn't substitute this Darwin prebuilt path.
# No update-automation hook (no `passthru.updateScript`, no
# `nix-update` integration) — operator-driven by design; a stale
# version is a feature-delivery decision, not a bug.
{ pkgs, ... }:
let
  codex-prebuilt = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "codex";
    version = "0.137.0";

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-Yo0ieLH6KkZ0UmNfL9Wq7umN5KlPKvBgMeR5DaaEQEY=";
    };

    # The tarball contains a single binary at its root with the asset
    # name (`codex-aarch64-apple-darwin`); no enclosing directory.
    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.installShellFiles ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      install -m 0755 codex-aarch64-apple-darwin $out/bin/codex

      # Generate shell completions from the binary (the prebuilt
      # tarball doesn't ship them; nixpkgs's source build runs this
      # same step via installShellCompletion). Fish is the operator's
      # daily-driver shell — without this, `codex <TAB>` is a no-op
      # on this host. bash + zsh included for completeness / portability.
      $out/bin/codex completion bash > codex.bash
      $out/bin/codex completion fish > codex.fish
      $out/bin/codex completion zsh  > codex.zsh
      installShellCompletion --cmd codex \
        --bash codex.bash \
        --fish codex.fish \
        --zsh codex.zsh

      runHook postInstall
    '';

    # Build meta from scratch rather than inheriting from
    # `pkgs.codex.meta` — that would carry `position` and
    # `maintainersPosition` pointing at upstream nixpkgs's package.nix
    # (misleading: the derivation is actually defined here) and
    # `maintainers` (we'd appear to credit nixpkgs's codex maintainers
    # for our override). Whitelist what we actually want.
    meta = {
      description = "OpenAI Codex CLI (prebuilt aarch64-darwin binary override)";
      homepage = "https://github.com/openai/codex";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = with pkgs.lib.sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  home.packages = [
    codex-prebuilt
    pkgs.gemini-cli
  ];
}
