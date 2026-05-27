# Editor — helix (with nixd LSP, OSC52 clipboard, format-on-save).
# See docs/decisions/ADR-005-editor.md for rationale.
#
# Two different resolution mechanisms are at play for nix tooling:
#   - nixfmt is invoked by absolute store path (lib.getExe pins it into
#     the closure). format-on-save works regardless of PATH.
#   - nixd is invoked by name and resolved against PATH at runtime.
#
# Both binaries are installed by home/core/shared/nix-tooling.nix.
#
# Parametrisation: `hostContext.{flakePath,hostName}` come from each host's
# `_module.args.hostContext` via the HM extraSpecialArgs forwarder in
# modules/core/nixos/home-manager.nix. See ADR-019.
{ lib, pkgs, hostContext, ... }:
let
  inherit (hostContext) flakePath hostName;
in
{
  programs.helix = {
    enable = true;

    settings = {
      theme = "default";   # TODO: choose a theme at first use (ADR-005)

      editor = {
        line-number = "relative";
        bufferline = "multiple";

        lsp.display-messages = true;

        # OSC52 — yank in helix lands in the Mac clipboard via the
        # terminal emulator. See docs/decisions/ADR-011-remote-dev-qol.md.
        clipboard-provider = "termcode";
      };
    };

    # nixd language-server configuration. Without this, nixd can only do
    # syntax-level analysis; with it, hovers and completions over
    # NixOS/home-manager option attributes (users.users.dbf.shell,
    # programs.git.settings.user.name, etc.) show their type and
    # description. The `options` expressions tell nixd how to evaluate
    # this flake's option schema at hover-time.
    languages.language-server.nixd = {
      command = "nixd";
      config.nixd.options = {
        nixos = {
          expr = ''(builtins.getFlake "${flakePath}").nixosConfigurations.${hostName}.options'';
        };
        # home-manager options live inside a submodule;
        # .type.getSubOptions [] unwraps them so nixd sees the option tree.
        home-manager = {
          expr = ''(builtins.getFlake "${flakePath}").nixosConfigurations.${hostName}.options.home-manager.users.type.getSubOptions []'';
        };
      };
    };

    # programs.helix.languages.language is a LIST of attribute sets (one per
    # language), not a single attrset.
    languages.language = [{
      name = "nix";
      auto-format = true;
      # pkgs.nixfmt is the RFC-style formatter. Don't swap with:
      #   - pkgs.nixfmt-classic — separate package, pre-RFC Serokell style.
      #   - pkgs.nixfmt-rfc-style — deprecated alias, emits warnings.
      formatter.command = "${lib.getExe pkgs.nixfmt}";
      language-servers = [ "nixd" ];
    }];
  };
}
