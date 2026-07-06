# Constructor for the hostContext typed-option module — the per-host
# parametrisation set that flows into home-manager modules (editor.nix's
# nixd hostname, nix-tooling.nix's NH_FLAKE) via extraSpecialArgs. Both
# platform twins (modules/{nixos,darwin}/host-context.nix) are built from
# this one schema with explicit per-platform args, so the hostContext
# contract cannot fork between platforms (#541 — the values-only twin
# criterion, CLAUDE.md §Conventions).
#
# ADR-019 named the ~5-field threshold for typing this. Fired early at
# 3 fields + 3 hosts because slice 6 C1's shared/ migration provided a
# clean moment, and Darwin onboarding added consumers soon after —
# early-firing the trigger is cheaper than ratcheting it up.
#
# `_module.args.hostContext = config.hostContext;` bridges the option
# layer back to function-arg consumption — keeps home-manager.nix,
# editor.nix, nix-tooling.nix unchanged (they still receive hostContext
# as a fn-arg) and sidesteps the imports-evaluation-timing trap that
# reading `config.hostContext` to compute home-manager imports would
# otherwise create.
{ defaultFlakePath }:
{ lib, config, ... }:
{
  options.hostContext = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The host's unique name (matches this platform's flake configurations attr).";
        };
        flakePath = lib.mkOption {
          type = lib.types.str;
          default = defaultFlakePath;
          description = "Filesystem path to this flake on the host. Used by nh + nixd.";
        };
        extraHomeModules = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "Home-manager modules imported on top of the home base.";
        };
      };
    };
    description = "Per-host parametrisation forwarded into home-manager modules.";
  };

  config._module.args.hostContext = config.hostContext;
}
