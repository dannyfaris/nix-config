# File manager (system side) — Thunar + the gvfs/tumbler daemons behind it.
# Home side (trash timer, directory handler): home/nixos/file-manager.nix.
# Selection + rationale: docs/desktop/file-manager.md (#762).
_: {
  programs.thunar = {
    enable = true; # also pulls programs.xfconf (settings storage)
    plugins = [ ]; # deliberately none — see the doc's plugin call
  };

  # Default full-backend build from the binary cache — rationale in the doc.
  services.gvfs.enable = true;

  services.tumbler.enable = true; # D-Bus thumbnailer Thunar delegates to
}
