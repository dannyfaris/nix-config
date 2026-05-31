{
  description = "nix-config — personal NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Community flake for the Zen browser. Tracks the `beta` release
    # stream by default via `homeModules.default`; `homeModules.twilight`
    # and `homeModules.twilight-official` are available for pre-release
    # tracks (not used). nixpkgs has open-but-stalled re-init PR for Zen
    # (NixOS/nixpkgs#496647); we use this flake until that lands.
    # Audit-phase wiring per #127; see docs/desktop/zen.md.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Systems this flake targets. Needed by flake-parts perSystem.
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        ./parts/nixos.nix
        ./parts/checks.nix
        ./parts/formatter.nix
        ./parts/dev-shells.nix
      ];
    };
}
