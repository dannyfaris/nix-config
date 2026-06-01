# Typed option layer for hostContext on Darwin hosts. Mirrors
# modules/nixos/host-context.nix; differs only in the `flakePath`
# default, which resolves to the operator's Darwin home (`/Users/dbf`)
# rather than the Linux home (`/home/dbf`).
#
# ADR-019 names the typed-option pattern. The `_module.args.hostContext
# = config.hostContext;` write bridges the option layer back to
# function-arg consumption — keeps home-manager.nix, editor.nix,
# nix-tooling.nix unchanged (they still receive hostContext as a
# fn-arg) and sidesteps the imports-evaluation-timing trap that reading
# `config.hostContext` to compute home-manager imports would otherwise
# create.
{ lib, config, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
  options.hostContext = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The host's unique name (matches darwinConfigurations.<name>).";
        };
        flakePath = lib.mkOption {
          type = lib.types.str;
          default = "${operator.darwinHome}/${operator.flakeRepoDirname}";
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
