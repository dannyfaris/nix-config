# set-font — remap a fontconfig generic (sans / mono / serif) at runtime, with
# no rebuild. Writes a small per-generic override under
# ~/.config/fontconfig/conf.d (the user-space seam the font conductor reads —
# docs/desktop/fonts.md §Runtime UX). The selection persists across rebuilds
# (Nix doesn't manage that path); open foot is signalled on a mono change.
# The friendly front-end to the fontconfig conductor on desktop hosts (#390).
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "set-font";
      runtimeInputs = [
        pkgs.fontconfig # fc-match
        pkgs.procps # pkill
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
            'Persists in ~/.config/fontconfig/conf.d; survives rebuilds.' \
            'Open apps pick it up on next launch (open foot is signalled).'
        }

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
      '';
    })
  ];
}
