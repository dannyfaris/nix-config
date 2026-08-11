{
  description = "nix-config — personal NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin — declarative configuration for macOS hosts. Mirrors
    # the NixOS module system at the system level; consumes home-manager
    # via its `darwinModules.home-manager` and sops-nix via its
    # `darwinModules.sops` (sibling to the respective `nixosModules.*`).
    # Wired into the flake by parts/darwin.nix; instantiated via the
    # mk-darwin-host constructor at lib/mk-darwin-host.nix. Adopted as
    # part of the mac-mini onboarding epic (#11).
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew + the two upstream taps pinned as flake inputs.
    # Wired into modules/darwin/homebrew.nix per ADR-031: nix-homebrew
    # bootstraps the Homebrew prefix and surfaces taps as flake inputs;
    # nix-darwin's own `homebrew` module manages the declarative cask
    # list. `mutableTaps = false` requires the taps to be inputs so brew
    # never reaches out for them at runtime — combined with
    # `HOMEBREW_NO_AUTO_UPDATE=1`, no surprise tap refreshes during
    # activation or interactive use.
    # nix-homebrew has no nixpkgs input to override — brew is loaded
    # via the `brew-src` GitHub source pinned in nix-homebrew's own
    # flake.lock. No follows directive needed (and nix warns if one
    # is set for a non-existent input).
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia Shell (v5, native C++ rewrite) — cohesive Wayland desktop
    # shell for the Linux desktop (ADR-036; v5 re-integration #644,
    # docs/design/noctalia-v5-migration.md). Pinned to the release tag —
    # v5 is beta and `main` moves daily. Upstream renamed the repo
    # noctalia-shell → noctalia; v4's co-locked `noctalia-qs` Quickshell
    # runtime is gone (meson-built binary, no Qt).
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.0.0-beta.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # impermanence — declarative persist-whitelist for the ephemeral-root
    # mechanism (docs/design/ephemeral-root.md, #553). Supplies the
    # `environment.persistence."/persist"` bind-mount surface that modules
    # contribute to independently (module-owns-its-state). Its home-manager
    # input also follows ours — impermanence only uses it for the HM-module
    # integration, and a second pinned home-manager in the lock buys nothing.
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Claude Desktop for Linux — see modules/nixos/claude-desktop.nix
    # (the consumer) and #683 (selection rationale). Both transitive
    # inputs follow ours so no second nixpkgs/flake-parts enters the lock.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Systems this flake targets. Needed by flake-parts perSystem.
      # aarch64-darwin lands as part of the mac-mini onboarding epic (#11);
      # the Darwin host is Apple Silicon, so x86_64-darwin is intentionally
      # omitted until a real x86_64 Mac arrives.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [
        ./parts/nixos.nix
        ./parts/darwin.nix
        ./parts/checks.nix
        ./parts/formatter.nix
        ./parts/dev-shells.nix
      ];
    };
}
