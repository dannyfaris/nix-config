# set-font — remap a fontconfig generic (sans / mono / serif) at runtime, with
# no rebuild. Writes a small per-generic override under
# ~/.config/fontconfig/conf.d (the user-space seam the font conductor reads —
# docs/desktop/fonts.md §Runtime UX). The selection persists across rebuilds
# (Nix doesn't manage that path); open foot is signalled on a mono change.
#
# Most surfaces follow live (foot via USR1; GTK/web on next window). Noctalia is
# the exception — Qt caches fonts at process start, so its bar/launcher only
# re-resolve on a restart. `--reload-shell` does that restart on demand (opt-in,
# because bouncing the whole shell is disruptive); otherwise a one-line hint is
# printed when a Noctalia is actually running. The friendly front-end to the
# fontconfig conductor on desktop hosts (#390).
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "set-font";
      runtimeInputs = [
        pkgs.fontconfig # fc-match
        pkgs.procps # pkill, pgrep
        pkgs.util-linux # setsid (detached shell relaunch)
      ];
      text = ''
        confd="''${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d"

        usage() {
          printf '%s\n' \
            'set-font — remap a fontconfig generic at runtime (no rebuild).' \
            ''' \
            '  set-font sans  <Family>    remap sans-serif' \
            '  set-font mono  <Family>    remap monospace' \
            '  set-font serif <Family>    remap serif' \
            '  set-font --show            fc-match the generics' \
            '  set-font --reset           remove all set-font overrides' \
            ''' \
            '  --reload-shell             also restart Noctalia so its bar/' \
            '                             launcher re-resolve (opt-in; combines' \
            '                             with a set or --reset)' \
            ''' \
            'Persists in ~/.config/fontconfig/conf.d; survives rebuilds.' \
            'foot follows live; GTK/web on next window; Noctalia on restart.'
        }

        # Restart Noctalia so its Qt-cached surfaces re-resolve fonts. v4-
        # specific — the ONE place that knows how to bounce the shell; update
        # this at the v5 migration (ADR-036).
        restart_shell() {
          if ! command -v noctalia-shell >/dev/null 2>&1; then
            echo "set-font: noctalia-shell not on PATH; restart the shell yourself" >&2
            return 0
          fi
          pkill -f "/bin/quickshell" 2>/dev/null || true
          sleep 1
          setsid -f noctalia-shell >/dev/null 2>&1 || true
          echo "set-font: Noctalia restarted"
        }

        # Nudge only when a Noctalia is actually running — silent otherwise, so
        # it is not noise on headless/non-Noctalia use.
        hint_shell() {
          if pgrep -f "/bin/quickshell" >/dev/null 2>&1; then
            echo "set-font: Noctalia caches fonts — re-run with --reload-shell to apply to its bar/launcher"
          fi
        }

        # Pull --reload-shell out of the args wherever it sits.
        reload=0
        new_args=()
        for a in "$@"; do
          if [ "$a" = "--reload-shell" ]; then
            reload=1
          else
            new_args+=("$a")
          fi
        done
        set -- "''${new_args[@]}"

        case "''${1:-}" in
          "" | -h | --help) usage; exit 0 ;;
          --show)
            for g in monospace sans-serif serif; do
              printf '%-11s -> ' "$g"
              fc-match "$g"
            done
            exit 0
            ;;
          --reset)
            rm -f "$confd"/99-setfont-*.conf
            echo "set-font: cleared overrides"
            pkill -USR1 foot 2>/dev/null || true
            if [ "$reload" = 1 ]; then restart_shell; else hint_shell; fi
            exit 0
            ;;
        esac

        case "$1" in
          sans | sans-serif) generic=sans-serif ;;
          mono | monospace) generic=monospace ;;
          serif) generic=serif ;;
          *)
            echo "set-font: unknown slot '$1' (use sans|mono|serif, or --show/--reset)" >&2
            exit 2
            ;;
        esac

        family="''${2:-}"
        if [ -z "$family" ]; then
          echo "set-font: missing family — e.g. set-font $1 \"Inter\"" >&2
          exit 2
        fi

        mkdir -p "$confd"
        printf '%s\n' \
          '<?xml version="1.0"?>' \
          '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">' \
          '<fontconfig>' \
          '  <alias binding="same">' \
          "    <family>$generic</family>" \
          "    <prefer><family>$family</family></prefer>" \
          '  </alias>' \
          '</fontconfig>' \
          > "$confd/99-setfont-$generic.conf"

        echo "set-font: $generic -> $family"
        fc-match "$generic"
        if [ "$generic" = monospace ]; then
          pkill -USR1 foot 2>/dev/null || true
        fi
        if [ "$reload" = 1 ]; then restart_shell; else hint_shell; fi
      '';
    })
  ];
}
