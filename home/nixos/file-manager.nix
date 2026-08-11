# File manager (home side) — trash semantics + the directory handler.
# System side (Thunar/gvfs/tumbler daemons): modules/nixos/file-manager.nix.
# Trash policy rationale: docs/desktop/file-manager.md §Trash (#762).
{ pkgs, ... }:
{
  # CLI door into the shared freedesktop trash + the purge timer's engine.
  home.packages = [ pkgs.trash-cli ];

  # Hand-authored unit — no NixOS/HM module for trash purging exists.
  systemd.user.services.trash-purge = {
    Unit.Description = "Purge trashed files older than 30 days";
    Service = {
      Type = "oneshot";
      # -f: non-interactive — a confirmation prompt would hang a unit.
      ExecStart = "${pkgs.trash-cli}/bin/trash-empty -f 30";
    };
  };
  systemd.user.timers.trash-purge = {
    Unit.Description = "Daily trash purge";
    # Persistent: fire on next boot if the host slept through a due run.
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Only the practically-exercised type (firefox.md precedent); rides the
  # xdg.mimeApps.enable already set by firefox.nix in this bundle.
  xdg.mimeApps.defaultApplications."inode/directory" = "thunar.desktop";
}
