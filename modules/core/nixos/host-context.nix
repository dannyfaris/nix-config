# Typed option layer for hostContext, the per-host parametrisation set
# that flows into home-manager modules (editor.nix's nixd hostname,
# nix-tooling.nix's NH_FLAKE) via extraSpecialArgs.
#
# ADR-019 named the ~5-field threshold for typing this. We're firing
# early at 3 fields + 3 hosts because slice 6 C1's shared/ migration
# provided a clean moment, and Darwin onboarding will add more fields
# before long. Early-firing the trigger is cheaper than ratcheting the
# trigger up.
#
# `_module.args.hostContext = config.hostContext;` bridges the option
# layer back to function-arg consumption — keeps home-manager.nix,
# editor.nix, nix-tooling.nix unchanged (they still receive hostContext
# as a fn-arg) and sidesteps the imports-evaluation-timing trap that
# reading `config.hostContext` to compute home-manager imports would
# otherwise create.
{ lib, config, ... }:
{
  options.hostContext = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The host's unique name (matches nixosConfigurations.<name>).";
        };
        flakePath = lib.mkOption {
          type = lib.types.str;
          default = "/home/dbf/nix-config";
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
