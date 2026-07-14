# dark-mode-notify — the macOS appearance watcher and the fan-out it
# drives (#499). Owns the `appearance.onChange` hook option, the runner
# that executes the hooks, and two launchd user agents: the watcher
# (immediate delivery when notifications arrive) and a periodic sweep
# (bounds staleness when they don't).
#
# This is the Class-2 half of runtime theme switching: surfaces with no
# native ear on the appearance signal (JankyBorders, wallpaper)
# contribute named hooks from their own modules; Class-1 surfaces
# (Ghostty, fish, bat) follow the signal natively and appear nowhere
# here. See docs/design/macos-live-theme-switching.md §Design.
#
# HM-level (not nix-darwin) because everything involved is user-session:
# distributed notifications are delivered per-user, and the hooks talk
# to the user's borders instance and desktop. The watcher runs the hooks
# once at agent startup and again on wake from sleep (upstream
# behaviour), so the fan-out self-heals at login and catches flips that
# happen while the machine sleeps.
#
# The watcher alone is insufficient: distributed-notification delivery
# to long-idle clients is empirically unreliable on this macOS build —
# receiver-side mitigations (.deliverImmediately, ProcessType=Interactive,
# beginActivity App-Nap opt-out) were all A/B-soaked and failed at the
# same ~50% rate (#620). The sweep is the belt-and-braces fallback: it
# unconditionally re-applies current polarity every 300 s, bounding
# visible staleness regardless of watcher delivery.
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
  # Computes current polarity from the defaults database and execs the
  # runner — same DARKMODE=1|0 contract used by the watcher and the
  # theme CLI. Unconditional execution is correct because hooks are
  # idempotent: re-applying current state is a no-op in effect.
  selfHealScript = pkgs.writeShellScript "appearance-self-heal" ''
    if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
      export DARKMODE=1
    else
      export DARKMODE=0
    fi
    exec ${runner}
  '';
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

  # The assembled runner, exposed read-only so the theme switcher
  # (home/darwin/theme-menu.nix, #605) fires the identical hook path
  # with a computed DARKMODE — one code path for every gesture.
  options.appearance.runner = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "The assembled appearance.onChange runner script.";
  };

  config = {
    appearance.runner = runner;

    launchd.agents.dark-mode-notify = {
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

    launchd.agents.appearance-self-heal = {
      enable = true;
      config = {
        ProgramArguments = [ "${selfHealScript}" ];
        # 300 s: bounds visible staleness to ≤5 min — noticeable but not
        # disruptive — while keeping sweep noise low. No KeepAlive or
        # RunAtLoad: this is a periodic correction, not a persistent observer.
        StartInterval = 300;
        # Separate logs: sweep runs are frequent and independent of watcher
        # events; keeping them apart makes each mechanism independently
        # observable without one drowning out the other.
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/appearance-self-heal.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/appearance-self-heal.err.log";
      };
    };
  };
}
