# dark-mode-notify — the macOS appearance watcher and the fan-out it
# drives (#499). Owns the `appearance.onChange` hook option, the runner
# that executes the hooks, and the launchd user agent that invokes the
# runner on every appearance change.
#
# This is the Class-2 half of runtime theme switching: surfaces with no
# native ear on the appearance signal (JankyBorders, wallpaper)
# contribute named hooks from their own modules; Class-1 surfaces
# (Ghostty, fish, bat) follow the signal natively and appear nowhere
# here. See docs/design/macos-live-theme-switching.md §Design.
#
# HM-level (not nix-darwin) because everything involved is user-session:
# distributed notifications are delivered per-user, and the hooks talk
# to the user's borders instance and desktop. The watcher also runs the
# hooks once at agent startup and again on wake from sleep (upstream
# behaviour), so the fan-out self-heals at login and catches flips that
# happen while the machine sleeps.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.appearance;
  # Name-sorted execution (mapAttrsToList iterates attrs in name order)
  # with per-hook invocation + failure log lines — the observability that
  # makes a silently rotted hook findable in the agent log. Deliberately
  # no `set -e`: hooks are isolated (subshell per hook), one failing must
  # not stop the rest of the fan-out.
  runner = pkgs.writeShellScript "appearance-onchange-runner" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: hook: ''
        echo "appearance.onChange ${name}: DARKMODE=''${DARKMODE:-unset}"
        (
          ${hook}
        ) || echo "appearance.onChange ${name}: failed ($?)"
      '') cfg.onChange
    )
  );
in
{
  # Typed-option pattern per ADR-019 (hostContext precedent) — the
  # repo's second custom option. Named attrs over a bare list buy
  # deterministic order, per-hook logging, and per-surface disable.
  options.appearance.onChange = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = ''
      Named shell hooks run on every macOS appearance change (and once
      at agent startup / on wake). The new polarity arrives as
      DARKMODE=1|0 in the environment.
    '';
  };

  config.launchd.agents.dark-mode-notify = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.dark-mode-notify}/bin/dark-mode-notify"
        "${runner}"
      ];
      # The watcher is a long-lived observer process; KeepAlive restarts
      # it if it dies, RunAtLoad starts it at login (which also fires the
      # hooks once — the self-heal).
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/dark-mode-notify.out.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/dark-mode-notify.err.log";
    };
  };
}
