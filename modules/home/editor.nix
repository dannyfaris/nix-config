# Editor — helix (with nixd LSP, OSC52 clipboard, format-on-save).
# See docs/decisions/ADR-005-editor.md for rationale.
#
# Two different resolution mechanisms are at play for nix tooling:
#   - nixfmt is invoked by absolute store path (lib.getExe pins it into
#     the closure). format-on-save works regardless of PATH.
#   - nixd is invoked by name and resolved against PATH at runtime.
#
# Both binaries are installed by modules/home/nix-tooling.nix (Slice 5d).
# Until that slice lands, format-on-save still works (nixfmt is embedded
# by store path), but LSP attach for nix files fails silently (nixd is
# not on PATH yet).
{ lib, pkgs, ... }: {
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

    # programs.helix.languages.language is a LIST of attrsets (one per
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
