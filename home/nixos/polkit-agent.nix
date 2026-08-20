# polkit authentication agent — mate-polkit (GTK3), replacing niri-flake's
# default KDE agent.
#
# Runs as a home-manager systemd user service bound to
# graphical-session.target — the standard agent-registration pattern. There
# is no home-manager module for mate-polkit, so the unit is hand-rolled; it
# mirrors how upstream `services.polkit-gnome` builds its unit.
#
# The KDE agent niri-flake otherwise runs (`niri-flake-polkit`) is disabled
# at the system layer (modules/nixos/niri.nix). Rationale — styling
# (mate-polkit is GTK, so it picks up the toolkit theme in
# home/nixos/gtk.nix and Noctalia's gtk3 colours; the KDE/Kirigami agent
# renders off-theme stock Breeze for want of kdeglobals) plus the 573 MiB
# Qt-stack removal — lives in docs/desktop/polkit.md.
#
# Per #103.
{ config, pkgs, ... }:
{
  systemd.user.services.mate-polkit = {
    Unit = {
      Description = "MATE PolicyKit authentication agent";
      Documentation = [ "man:polkit(8)" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Restart the agent when its GTK font config changes — it reads it
      # only at startup, so without this an `nh os switch` leaves the
      # dialog on a stale font until relogin. gtk.css is deliberately NOT a
      # trigger (resolves #876): home-manager doesn't write that path —
      # Noctalia owns it (#874) — so the attr has no value to read. See
      # docs/desktop/polkit.md §Sharp edges (same pattern as fnott #350).
      X-Restart-Triggers = [ config.xdg.configFile."gtk-3.0/settings.ini".source ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.mate-polkit}/libexec/polkit-mate-authentication-agent-1";
      Restart = "on-failure";
      # Match niri-flake's KDE unit and slow any crash-loop on the
      # privilege-escalation path (systemd's default is 100 ms).
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
