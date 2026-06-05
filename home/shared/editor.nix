# Editor — helix (with nixd LSP, OSC52 clipboard, format-on-save).
# See docs/decisions/ADR-005-editor.md for rationale.
#
# Two different resolution mechanisms are at play for nix tooling:
#   - nixfmt is invoked by absolute store path (lib.getExe pins it into
#     the closure). format-on-save works regardless of PATH.
#   - nixd is invoked by name and resolved against PATH at runtime.
#
# Both binaries are installed by home/shared/nix-tooling.nix.
#
# Parametrisation: `hostContext.{flakePath,hostName}` come from each host's
# `_module.args.hostContext` via the HM extraSpecialArgs forwarder in
# modules/nixos/home-manager.nix. See ADR-019.
{
  lib,
  pkgs,
  hostContext,
  ...
}:
let
  inherit (hostContext) flakePath hostName;
in
{
  programs.helix = {
    enable = true;

    settings = {
      # `programs.helix.settings.theme` is owned by Stylix's helix target
      # (enabled via home/shared/stylix-targets.nix per ADR-028).
      # Stylix writes the theme name here at default priority.

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
    languages.language = [
      {
        name = "nix";
        auto-format = true;
        # pkgs.nixfmt is the RFC-style formatter. Don't swap with:
        #   - pkgs.nixfmt-classic — separate package, pre-RFC Serokell style.
        #   - pkgs.nixfmt-rfc-style — deprecated alias, emits warnings.
        formatter.command = "${lib.getExe pkgs.nixfmt}";
        language-servers = [ "nixd" ];
      }
      {
        name = "markdown";
        # Repo markdown is authored soft-wrapped (one line per paragraph)
        # per docs/workflow.md §"Markdown is soft-wrapped"; without
        # display-side soft-wrap those long lines need horizontal scroll
        # to read in helix.
        # Display-only — does not alter file content. See #266.
        soft-wrap.enable = true;
      }
    ];
  };

  # User-shell defaults. System-mediated tools (sudoedit, visudo, systemctl
  # edit) get their parallel SUDO_EDITOR / SYSTEMD_EDITOR from
  # modules/shared/editor-defaults.nix — sudo strips PATH so that
  # layer uses absolute store paths. VISUAL complements EDITOR for tools
  # (notably git) that check VISUAL first.
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
