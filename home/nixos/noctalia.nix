# Noctalia Shell v5 — cohesive Wayland desktop shell on the Linux desktop
# (ADR-036; v5 re-integration #644, docs/design/noctalia-v5-migration.md).
# Native C++ binary (`noctalia`) via the flake's home-manager module —
# no Quickshell/Qt runtime, IPC is `noctalia msg <verb>`.
#
# The shell is spawned from niri (`spawn-at-startup` in home/nixos/niri.nix);
# the HM module's systemd unit stays at its default (off). `validateConfig`
# stays at its default (true): the baseline below is validated by the v5
# binary's own schema engine at build time, so schema drift on a bump fails
# the build, not the session.
#
# Config posture (design note §Design): a minimal declared baseline in
# read-only config.toml — theming wiring, idle, posture toggles — while
# look/layout stay runtime/GUI state in v5's settings.toml overrides layer.
# The palette itself is the theme-menu conductor's constant-name custom
# palette (home/nixos/theme-menu.nix); Noctalia's own theme pickers stay
# inert-by-convention (ADR-044 — the conductor owns the selection).
{
  inputs,
  lib,
  pkgs,
  hostContext,
  ...
}:
let
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  bootPolarity = (import ../../lib/palette-for.nix hostContext.hostName).polarity;

  # Idle-suspend guard — the `[idle.behavior.suspend]` command. Ordered
  # skip-checks, failure direction "stays awake" (correct for a remotely-used
  # box — design note §Design): (1) Noctalia's caffeine logind inhibitor
  # (who=noctalia, why=Caffeine). Runtime verification (probe S4) showed
  # caffeine natively suppresses idle behaviours at beta.4 — this check is
  # defence-in-depth against a future regression, not the primary gate;
  # (2) live inbound SSH; (3) detached agent workloads (linger is on — SSH
  # teardown does not imply idle; pattern starts conservative, tune on
  # evidence). Otherwise delegate to Noctalia's own locked-event-gated
  # suspend. `--dry-run` prints + logs the decision without acting (probe S3).
  idleGuard = pkgs.writeShellApplication {
    name = "noctalia-idle-guard";
    runtimeInputs = [
      pkgs.systemd # systemd-inhibit
      pkgs.iproute2 # ss
      pkgs.procps # pgrep
      pkgs.coreutils
      pkgs.gnugrep
      noctaliaPkg
    ];
    text = ''
      decision="suspend"
      if systemd-inhibit --list --no-pager 2>/dev/null | grep -qE 'noctalia.*Caffeine'; then
        decision="skip: caffeine inhibitor present"
      elif [ -n "$(ss -H -tn state established '( sport = :22 )')" ]; then
        decision="skip: live inbound SSH session"
      elif pgrep -u "$(id -un)" -f 'claude|tmux' >/dev/null 2>&1; then
        decision="skip: detached agent session running"
      fi

      if [ "''${1:-}" = "--dry-run" ]; then
        log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
        printf '%s %s\n' "$(date -Is)" "$decision" >> "$log_dir/noctalia-idle-guard.log"
        echo "noctalia-idle-guard (dry-run): $decision"
        exit 0
      fi

      if [ "$decision" != "suspend" ]; then
        echo "noctalia-idle-guard: $decision" >&2
        exit 0
      fi
      exec noctalia msg session lock-and-suspend
    '';
  };

  # `[hooks] started` polarity reconcile — dconf is the polarity authority
  # (ADR-044 axis 2); `theme-mode-set` unavoidably persists a theme.mode echo
  # into v5's settings.toml, and this hook re-converges Noctalia to dconf on
  # every shell start so that echo can never go stale (design note §Design;
  # probe V4). Compare-first via theme-mode-get skips the redundant persist.
  # The IPC socket is initialised before the hooks phase, so `noctalia msg`
  # from here is served (design note §De-risk).
  polarityReconcile = pkgs.writeShellApplication {
    name = "noctalia-polarity-reconcile";
    runtimeInputs = [
      pkgs.dconf
      pkgs.coreutils
      noctaliaPkg
    ];
    text = ''
      val=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
      if [ "$val" = "'prefer-dark'" ]; then target="dark"; else target="light"; fi
      current=$(noctalia msg theme-mode-get 2>/dev/null || true)
      case "$current" in
        *"$target"*) exit 0 ;;
      esac
      noctalia msg theme-mode-set "$target" >/dev/null 2>&1 || true
    '';
  };

  # Lock engagement for the user-level sleep.target that
  # modules/nixos/lock-before-sleep.nix bridges (systemd-lock-handler holds
  # the logind delay-inhibitor, so sleep waits for this oneshot). The short
  # settle covers the niri round-trip — v5's IPC has no lock-state query.
  # If the shell is dead nothing locks, but nothing idle-suspends either
  # (accepted residual, design note §Design).
  lockOnSleep = pkgs.writeShellApplication {
    name = "noctalia-lock-on-sleep";
    runtimeInputs = [
      pkgs.coreutils
      noctaliaPkg
    ];
    text = ''
      noctalia msg session lock >/dev/null 2>&1 || true
      sleep 0.3
    '';
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;

    settings = {
      # Skip the first-run wizard: its guided theme selection would persist
      # theme.* overrides into settings.toml on day one — the exact shadowing
      # channel the palette seam is designed to keep empty (probe C2).
      shell.setup_wizard_enabled = false;

      theme = {
        # The conductor's constant-name palette — the family selection lives
        # solely in theme-menu's pointer; Noctalia dereferences this name
        # through the symlink chain on every resolve. mode is a boot default
        # only (runtime polarity rides dconf + the started hook).
        source = "custom";
        custom_palette = "theme-menu";
        mode = bootPolarity;

        # ADR-044: Nix owns every external surface — the template engine
        # stays off, explicitly rather than resting on empty-list defaults.
        templates = {
          enable_builtin_templates = false;
          enable_community_templates = false;
        };
      };

      hooks.started = lib.getExe polarityReconcile;

      idle = {
        # Nobody is at the desk when idle actions fire; the fade overlay
        # countdown is noise.
        pre_action_fade_seconds = 0;

        behavior = {
          lock = {
            enabled = true;
            timeout = 600;
            action = "lock";
          };
          screen-off = {
            enabled = true;
            timeout = 660;
            action = "screen_off";
          };
          # Guarded suspend (stance change, #644). Per-host flag: off by
          # default fleet-wide, metis opts in. `action` strings are NOT
          # schema-validated (a typo silently becomes command mode) — keep
          # these exact.
          suspend = {
            enabled = hostContext.idleSuspend;
            timeout = 1800;
            action = "command";
            command = lib.getExe idleGuard;
          };
        };
      };
    };
  };

  # Lock before ANY suspend path (idle-fired, `systemctl suspend`, future
  # power-key) — the user-level half of the systemd-lock-handler bridge
  # (modules/nixos/lock-before-sleep.nix). Restores the guarantee the v4
  # gap relaxed, proven by probe S5's journal ordering.
  systemd.user.services.noctalia-lock-on-sleep = {
    Unit = {
      Description = "Engage the Noctalia lock before suspend";
      Before = [ "sleep.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe lockOnSleep;
    };
    Install.WantedBy = [ "sleep.target" ];
  };

  # notify-send (libnotify) — the CLI for emitting test notifications to
  # Noctalia, which owns org.freedesktop.Notifications (v5 default; it
  # throws if another daemon holds the name — fnott was decommissioned in
  # #385, so the name is free).
  #
  # wl-clipboard (wl-copy/wl-paste) — CLI clipboard access on the session
  # PATH. v5's clipboard is a native wlr-data-control implementation (no
  # cliphist, no wl-clipboard in its tree), so this exists purely for
  # non-OSC-52 CLI consumers that shell out to wl-copy (gh-dash's `y`,
  # scripts). See docs/desktop/clipboard.md (#360).
  home.packages = [
    pkgs.libnotify
    pkgs.wl-clipboard
  ];
}
