# theme-menu — the runtime named-theme menu on Linux (#609; Route 1 of
# docs/design/colour-conductor.md, Adjudicated 2026-07-14). Renders one
# entry dir per declared family (lib/theme-families.nix, resolved via
# lib/scheme-pair.nix's `menu`) into the HM generation, owns the active-
# theme pointer convention, and ships the `theme` switcher CLI.
#
# Entry-dir contract (per family, consumed by the `theme` CLI via the
# per-target resolved symlinks):
#   foot-{dark,light}.ini  — foot palette include (BOTH use [colors-dark]
#                            header — foot's active mode never flips; the
#                            conductor swaps content; see R4 guard comment
#                            in foot.nix — never emit initial-color-theme)
#   niri-{dark,light}.kdl  — niri layout colours (13 values across
#                            focus-ring/border/shadow/tab-indicator/
#                            insert-hint + recent-windows/highlight)
#   gtk3-{dark,light}.css  — 34 @define-color keys for GTK3 theming
#   gtk4-{dark,light}.css  — same 34 keys + :root { --*-color } libadwaita
#                            custom-property block for GTK4
#   colors-{dark,light}.json — 16 M3-role keys for Noctalia's colors.json
#
# Per-target resolved symlinks in $stateDir (stable paths consumers read;
# colors.json is instead the SOURCE for an atomic copy into
# ~/.config/noctalia/ — Noctalia's inode-resolving watchers can't see
# symlink swaps, #609):
#   foot.ini   → current/foot-<polarity>.ini
#   niri.kdl   → current/niri-<polarity>.kdl
#   gtk3.css   → current/gtk3-<polarity>.css
#   gtk4.css   → current/gtk4-<polarity>.css
#   colors.json → current/colors-<polarity>.json
#
# The pointer is $XDG_STATE_HOME/theme-menu/current → one entry's
# stable $XDG_DATA_HOME/theme-menu/<family> path. HM seeds the pointer
# at first activation (absent/dangling/stale); the `theme` CLI repoints
# it at runtime. The polarity axis is the dconf
# org/gnome/desktop/interface/color-scheme key — the Linux portal signal.
#
# Noctalia is demoted from colour authority to themed-by-Nix shell: its
# activeTemplates are all disabled by the operator at rollout and
# useWallpaperColors false, so it reads colors.json as its palette source
# and writes nothing to foot/gtk/niri/helix/starship/yazi (ADR-044). The
# scheme/polarity picker in Noctalia's control centre becomes inert-by-
# convention — the conductor owns the selection. See docs/desktop/noctalia.md.
{
  config,
  lib,
  pkgs,
  inputs,
  hostContext,
  ...
}:
let
  schemePair = import ../../lib/scheme-pair.nix {
    inherit
      inputs
      pkgs
      lib
      hostContext
      ;
  };

  dataDir = "${config.xdg.dataHome}/theme-menu";
  stateDir = "${config.xdg.stateHome}/theme-menu";

  # ---------------------------------------------------------------------------
  # Render helpers — pure Nix string interpolation from a resolved base16
  # attrset (slot names base00–base0F available as plain string attrs).
  # Every mapping is slot-commented so role deviations are visible at a glance.

  # foot palette include — [colors-dark] header used for BOTH polarities
  # (foot never flips its active section; the conductor swaps the file content).
  # Base16 → terminal ANSI mapping per Stylix's canonical foot module:
  #   regular0 = base00 (black / background)
  #   regular1 = base08 (red / error)
  #   regular2 = base0B (green / success)
  #   regular3 = base0A (yellow / warning)
  #   regular4 = base0D (blue / focus / accent)
  #   regular5 = base0E (magenta)
  #   regular6 = base0C (cyan)
  #   regular7 = base05 (white / foreground)
  #   bright0  = base03 (bright-black / muted)
  #   bright1  = base08 (bright-red — same as regular1; no split in base16)
  #   bright2  = base0B (bright-green)
  #   bright3  = base0A (bright-yellow)
  #   bright4  = base0D (bright-blue)
  #   bright5  = base0E (bright-magenta)
  #   bright6  = base0C (bright-cyan)
  #   bright7  = base07 (bright-white)
  renderFoot = c: ''
    [colors-dark]
    background        = ${c.base00}
    foreground        = ${c.base05}

    selection-background = ${c.base02}
    selection-foreground = ${c.base05}

    regular0 = ${c.base00}
    regular1 = ${c.base08}
    regular2 = ${c.base0B}
    regular3 = ${c.base0A}
    regular4 = ${c.base0D}
    regular5 = ${c.base0E}
    regular6 = ${c.base0C}
    regular7 = ${c.base05}

    bright0  = ${c.base03}
    bright1  = ${c.base08}
    bright2  = ${c.base0B}
    bright3  = ${c.base0A}
    bright4  = ${c.base0D}
    bright5  = ${c.base0E}
    bright6  = ${c.base0C}
    bright7  = ${c.base07}
  '';

  # niri layout colours — 13 values across the 6 node groups.
  # Role → slot assignments:
  #   active border/focus-ring  = base0D (focus role, accent-blue)
  #   inactive border/focus-ring = base00 (background — invisible border)
  #   urgent                    = base08 (critical role, red)
  #   shadow                    = 000000 with alpha (black, fixed per live file)
  #   tab-indicator inactive    = base01 (slightly raised background)
  #   insert-hint               = base0D with 80 alpha (focus, semi-transparent)
  #   recent-windows urgent     = base08 (critical, consistent with border urgent)
  renderNiri = c: ''
    layout {

        focus-ring {
            active-color   "#${c.base0D}"
            inactive-color "#${c.base00}"
            urgent-color   "#${c.base08}"
        }

        border {
            active-color   "#${c.base0D}"
            inactive-color "#${c.base00}"
            urgent-color   "#${c.base08}"
        }

        shadow {
            color "#00000070"
        }

        tab-indicator {
            active-color   "#${c.base0D}"
            inactive-color "#${c.base01}"
            urgent-color   "#${c.base08}"
        }

        insert-hint {
            color "#${c.base0D}80"
        }
    }

    recent-windows {
        highlight {
            active-color "#${c.base0D}"
            urgent-color "#${c.base08}"
        }
    }
  '';

  # GTK3 — 34 @define-color keys replicating the live file's key set.
  # Slot assignments (accent = base0D discipline throughout):
  #   accent*           = base0D (focus/accent, blue family)
  #   accent_fg         = base00 (background, i.e. text-on-accent)
  #   destructive_bg*   = base08 (critical/error, red)
  #   destructive_fg*   = base00 (text on destructive bg → background)
  #   error_bg*         = base08 (same as destructive)
  #   error_fg*         = base00 (text on error bg)
  #   window_bg*        = base00 (primary background)
  #   window_fg*        = base05 (primary foreground)
  #   view_bg*          = base00 (content area, same as window)
  #   view_fg*          = base05
  #   headerbar_bg*     = base00 (chrome, same level as window)
  #   headerbar_fg*     = base05
  #   headerbar_backdrop = @window_bg_color (CSS alias)
  #   popover_bg*       = base01 (slightly raised surface)
  #   popover_fg*       = base05
  #   card_bg*          = base01 (raised card surface)
  #   card_fg*          = base05
  #   dialog_bg*        = base00 (dialog is window-level)
  #   dialog_fg*        = base05
  #   overview_bg*      = base01 (raised overview surface)
  #   overview_fg*      = base05
  #   sidebar_bg*       = base01 (raised sidebar surface)
  #   sidebar_fg*       = base05
  #   sidebar_backdrop  = @window_bg_color (CSS alias)
  #   sidebar_border    = @window_bg_color (CSS alias)
  #   secondary_sidebar_bg = base00 (deeper nested sidebar)
  #   secondary_sidebar_fg = base05
  #   theme_unfocused_* = CSS aliases (@window_*/view_*/accent_*)
  renderGtk3 = c: ''
    /* stylelint-disable at-rule-no-unknown */

    @define-color accent_color #${c.base0D};
    @define-color accent_bg_color #${c.base0D};
    @define-color accent_fg_color #${c.base00};

    @define-color destructive_bg_color #${c.base08};
    @define-color destructive_fg_color #${c.base00};

    @define-color error_bg_color #${c.base08};
    @define-color error_fg_color #${c.base00};

    @define-color window_bg_color #${c.base00};
    @define-color window_fg_color #${c.base05};

    @define-color view_bg_color #${c.base00};
    @define-color view_fg_color #${c.base05};

    @define-color headerbar_bg_color #${c.base00};
    @define-color headerbar_fg_color #${c.base05};
    @define-color headerbar_backdrop_color @window_bg_color;

    @define-color popover_bg_color #${c.base01};
    @define-color popover_fg_color #${c.base05};

    @define-color card_bg_color #${c.base01};
    @define-color card_fg_color #${c.base05};

    @define-color dialog_bg_color #${c.base00};
    @define-color dialog_fg_color #${c.base05};

    @define-color overview_bg_color #${c.base01};
    @define-color overview_fg_color #${c.base05};

    @define-color sidebar_bg_color #${c.base01};
    @define-color sidebar_fg_color #${c.base05};
    @define-color sidebar_backdrop_color @window_bg_color;
    @define-color sidebar_border_color @window_bg_color;

    @define-color secondary_sidebar_bg_color #${c.base00};
    @define-color secondary_sidebar_fg_color #${c.base05};

    /* Backdrop/unfocused states */
    @define-color theme_unfocused_fg_color @window_fg_color;
    @define-color theme_unfocused_text_color @view_fg_color;
    @define-color theme_unfocused_bg_color @window_bg_color;
    @define-color theme_unfocused_base_color @window_bg_color;
    @define-color theme_unfocused_selected_bg_color @accent_bg_color;
    @define-color theme_unfocused_selected_fg_color @accent_fg_color;
  '';

  # GTK4 — same 34 @define-color keys + the :root {} libadwaita custom-
  # property block. Slot mapping same as GTK3; :root mirrors the @define-color
  # values as CSS custom properties.
  # Additional :root-only keys (from live file):
  #   --warning-bg   = base0E (magenta family as warning accent)
  #   --warning-fg   = base07 (bright-white, readable on magenta bg)
  #   --warning      = base0E
  #   --success      = base0B (green)
  #   --success-bg   = base02 (dark green-tinted surface)
  #   --success-fg   = base07
  #   --shade-color  = rgba fixed (semi-transparent black)
  renderGtk4 =
    c:
    renderGtk3 c
    + ''

      :root {
          --accent-color: #${c.base0D};
          --accent-bg-color: #${c.base0D};
          --accent-fg-color: #${c.base00};

          --destructive-bg-color: #${c.base08};
          --destructive-fg-color: #${c.base00};

          --error-bg-color: #${c.base08};
          --error-fg-color: #${c.base00};
          --error-color: #${c.base08};

          --window-bg-color: #${c.base00};
          --window-fg-color: #${c.base05};

          --view-bg-color: #${c.base00};
          --view-fg-color: #${c.base05};

          --headerbar-bg-color: #${c.base00};
          --headerbar-fg-color: #${c.base05};
          --headerbar-backdrop-color: @window_bg_color;

          --popover-bg-color: #${c.base01};
          --popover-fg-color: #${c.base05};

          --card-bg-color: #${c.base01};
          --card-fg-color: #${c.base05};

          --dialog-bg-color: #${c.base00};
          --dialog-fg-color: #${c.base05};

          --overview-bg-color: #${c.base01};
          --overview-fg-color: #${c.base05};

          --sidebar-bg-color: #${c.base01};
          --sidebar-fg-color: #${c.base05};
          --sidebar-backdrop-color: @window_bg_color;
          --sidebar-border-color: @window_bg_color;

          --warning-bg-color: #${c.base0E};
          --warning-fg-color: #${c.base07};
          --warning-color: #${c.base0E};

          --success-color: #${c.base0B};
          --success-bg-color: #${c.base02};
          --success-fg-color: #${c.base07};

          --shade-color: rgba(0, 0, 0, 0.36);
      }
    '';

  # colors.json — 16 M3-role keys for Noctalia's palette source.
  # Slot assignments:
  #   mPrimary         = base0D (accent/focus, blue family)
  #   mOnPrimary       = base00 (text on primary — background)
  #   mSecondary       = base0C (cyan, secondary accent)
  #   mOnSecondary     = base00 (text on secondary)
  #   mTertiary        = base0E (magenta, tertiary accent)
  #   mOnTertiary      = base00 (text on tertiary)
  #   mError           = base08 (red, critical/error)
  #   mOnError         = base00 (text on error)
  #   mSurface         = base00 (primary surface = background)
  #   mOnSurface       = base05 (text on surface = foreground)
  #   mSurfaceVariant  = base01 (raised surface variant)
  #   mOnSurfaceVariant = base04 (muted text on surface variant)
  #   mOutline         = base03 (muted/outline, bright-black)
  #   mShadow          = 000000 (black, fixed)
  #   mHover           = base0E (magenta-family hover, from live file)
  #   mOnHover         = base00 (text on hover)
  renderColors = c: ''
    {
      "mPrimary": "#${c.base0D}",
      "mOnPrimary": "#${c.base00}",

      "mSecondary": "#${c.base0C}",
      "mOnSecondary": "#${c.base00}",

      "mTertiary": "#${c.base0E}",
      "mOnTertiary": "#${c.base00}",

      "mError": "#${c.base08}",
      "mOnError": "#${c.base00}",

      "mSurface": "#${c.base00}",
      "mOnSurface": "#${c.base05}",

      "mSurfaceVariant": "#${c.base01}",
      "mOnSurfaceVariant": "#${c.base04}",

      "mOutline": "#${c.base03}",
      "mShadow": "#000000",

      "mHover": "#${c.base0E}",
      "mOnHover": "#${c.base00}"
    }
  '';

  # One runCommand per family: each builds a directory of 10 rendered artefacts
  # (foot-dark.ini, foot-light.ini, niri-dark.kdl, niri-light.kdl,
  # gtk3-dark.css, gtk3-light.css, gtk4-dark.css, gtk4-light.css,
  # colors-dark.json, colors-light.json). Pure Nix string interpolation — no
  # runtime templating engine. Mirrors darwin/theme-menu.nix's entryFor idiom.
  entryFor =
    name: couplet:
    pkgs.runCommand "theme-menu-${name}" { } ''
      mkdir $out
      cp ${pkgs.writeText "foot-dark-${name}" (renderFoot couplet.dark)} $out/foot-dark.ini
      cp ${pkgs.writeText "foot-light-${name}" (renderFoot couplet.light)} $out/foot-light.ini
      cp ${pkgs.writeText "niri-dark-${name}" (renderNiri couplet.dark)} $out/niri-dark.kdl
      cp ${pkgs.writeText "niri-light-${name}" (renderNiri couplet.light)} $out/niri-light.kdl
      cp ${pkgs.writeText "gtk3-dark-${name}" (renderGtk3 couplet.dark)} $out/gtk3-dark.css
      cp ${pkgs.writeText "gtk3-light-${name}" (renderGtk3 couplet.light)} $out/gtk3-light.css
      cp ${pkgs.writeText "gtk4-dark-${name}" (renderGtk4 couplet.dark)} $out/gtk4-dark.css
      cp ${pkgs.writeText "gtk4-light-${name}" (renderGtk4 couplet.light)} $out/gtk4-light.css
      cp ${pkgs.writeText "colors-dark-${name}" (renderColors couplet.dark)} $out/colors-dark.json
      cp ${pkgs.writeText "colors-light-${name}" (renderColors couplet.light)} $out/colors-light.json
    '';

  families = lib.attrNames schemePair.menu;

  # The `theme` CLI: validate against baked entry dirs, atomically repoint the
  # state symlink, and fan-out reload signals to running instances. GNU mv -fT
  # is load-bearing: without it mv onto an existing symlink dereferences it and
  # tries to move the temp into the read-only store dir (darwin precedent: see
  # the coreutils comment in home/darwin/theme-menu.nix).
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dconf
      pkgs.procps # pgrep, ps
      config.programs.niri.package # niri msg action load-config-file
    ];
    text = ''
      data=${lib.escapeShellArg dataDir}
      state=${lib.escapeShellArg stateDir}
      boot_default=${lib.escapeShellArg schemePair.family}

      # ---------- dangling-pointer repair ----------
      # If current doesn't resolve into the baked family set, re-seed to the
      # boot default before proceeding with any command.
      if current_target=$(readlink "$state/current" 2>/dev/null); then
        current_name="''${current_target##*/}"
        if [ ! -d "$data/$current_name" ]; then
          echo "theme: repairing stale pointer (was $current_name → not in baked set); resetting to $boot_default" >&2
          rm -f "$state/current"
          ln -s "$data/$boot_default" "$state/current"
          current_name="$boot_default"
        fi
      fi

      # ---------- polarity helper ----------
      # Read the current polarity from dconf (portal axis).
      current_polarity() {
        val=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
        if [ "$val" = "'prefer-dark'" ]; then echo "dark"; else echo "light"; fi
      }

      # ---------- list ----------
      # Advertise polarity state and forms so bare `theme` is self-documenting
      # (#609 operator-requested discoverability).
      if [ $# -eq 0 ]; then
        current=$(readlink "$state/current" 2>/dev/null || true)
        current=''${current##*/}
        for f in ${lib.concatStringsSep " " families}; do
          if [ "$f" = "$current" ]; then echo "* $f"; else echo "  $f"; fi
        done
        echo ""
        echo "polarity: $(current_polarity)   (theme dark | theme light)"
        echo "usage: theme [<family>] [dark|light]"
        exit 0
      fi

      # ---------- parse arguments ----------
      arg1="$1"
      arg2="''${2:-}"

      # Detect polarity-only invocation: theme dark | theme light
      if [ "$arg1" = "dark" ] || [ "$arg1" = "light" ]; then
        new_polarity="$arg1"
        new_family=$(readlink "$state/current" 2>/dev/null || echo "$data/$boot_default")
        new_family="''${new_family##*/}"
      else
        # Family (+ optional polarity): theme <family> [dark|light]
        new_family="$arg1"
        if [ ! -d "$data/$new_family" ]; then
          echo "theme: unknown family '$new_family' (menu: ${lib.concatStringsSep ", " families})" >&2
          exit 1
        fi
        if [ -n "$arg2" ]; then
          if [ "$arg2" != "dark" ] && [ "$arg2" != "light" ]; then
            echo "theme: polarity must be 'dark' or 'light', got '$arg2'" >&2
            exit 1
          fi
          new_polarity="$arg2"
        else
          new_polarity=$(current_polarity)
        fi
      fi

      mkdir -p "$state"

      # ---------- atomic family repoint ----------
      tmp=$(mktemp -u "$state/.current.XXXXXX")
      ln -s "$data/$new_family" "$tmp"
      mv -fT "$tmp" "$state/current"

      # ---------- (re)create per-target resolved symlinks ----------
      ln -sf "$state/current/foot-''${new_polarity}.ini" "$state/foot.ini"
      ln -sf "$state/current/niri-''${new_polarity}.kdl" "$state/niri.kdl"
      ln -sf "$state/current/gtk3-''${new_polarity}.css" "$state/gtk3.css"
      ln -sf "$state/current/gtk4-''${new_polarity}.css" "$state/gtk4.css"
      ln -sf "$state/current/colors-''${new_polarity}.json" "$state/colors.json"

      # ---------- Noctalia palette delivery: atomic copy-into-place ----------
      # Noctalia's FileView watchers resolve inodes at watch-establishment
      # time; a state-level symlink swap ($state/colors.json → different store
      # artefact) never touches the watched inode or ~/.config/noctalia/, so
      # no reload fires. Atomic replace inside the watched dir (tmp + mv -fT)
      # is the pattern the upstream source comment anticipates — caught by
      # #609 runtime verification.
      mkdir -p "$HOME/.config/noctalia"
      colors_tmp=$(mktemp "$HOME/.config/noctalia/.colors.XXXXXX")
      cp "$state/colors.json" "$colors_tmp"
      mv -fT "$colors_tmp" "$HOME/.config/noctalia/colors.json"

      # ---------- polarity fan-out: dconf ----------
      # Always write (idempotent) so a fresh machine whose seed ran bus-less
      # self-heals on the next interactive switch.
      if [ "$new_polarity" = "dark" ]; then
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" || \
          echo "theme: dconf write failed (non-fatal outside session)" >&2
      else
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'default'" || \
          echo "theme: dconf write failed (non-fatal outside session)" >&2
      fi

      # ---------- foot OSC repaint ----------
      # Emit OSC 4 (16 ANSI slots) + OSC 10/11 (fg/bg) to each foot pty.
      # foot is standalone (one process per window); we find child ttys via
      # ps --ppid. Scoping to foot children avoids spraying SSH'd terminals.
      # Writing to the pty slave is display-side — foot parses OSC directly;
      # zellij is not in this path. Zero ptys is fine (no error).
      #
      # parse_foot_ini strips the [colors-dark] section into key=value lines
      # with all whitespace removed (the rendered .ini has padded spacing:
      # `background        = hexval`; bare grep '^background=' would miss it).
      parse_foot_ini() {
        ini="$1"
        sed -n '/^\[colors-dark\]/,/^\[/p' "$ini" \
          | grep -E '^\s*(background|foreground|regular[0-9]|bright[0-9])' \
          | sed 's/[[:space:]]//g'
      }

      emit_osc_to_pty() {
        pty="$1"
        ini="$2"
        # Get stripped key=value pairs from the [colors-dark] section once.
        stripped=$(parse_foot_ini "$ini")
        {
          # OSC 11 background, OSC 10 foreground
          bg=$(printf '%s\n' "$stripped" | grep '^background=' | cut -d= -f2)
          fg=$(printf '%s\n' "$stripped" | grep '^foreground=' | cut -d= -f2)
          printf '\033]11;#%s\007' "$bg"
          printf '\033]10;#%s\007' "$fg"
          # OSC 4 — 16 ANSI slots
          for slot_idx in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            if [ "$slot_idx" -lt 8 ]; then
              key="regular''${slot_idx}"
            else
              key="bright''$((slot_idx - 8))"
            fi
            colour=$(printf '%s\n' "$stripped" | grep "^''${key}=" | cut -d= -f2)
            [ -n "$colour" ] && printf '\033]4;%d;#%s\007' "$slot_idx" "$colour"
          done
        } > "/dev/pts/$pty" 2>/dev/null || true
      }

      # Discover foot ptys: for each foot pid, find child tty via ps --ppid.
      # (The grep below filters tty output, not a process list — SC2009 is a
      # false positive here; pgrep already handles the process lookup above.)
      pgrep -x foot 2>/dev/null | while read -r foot_pid; do
        # shellcheck disable=SC2009
        tty_path=$(ps --ppid "$foot_pid" -o tty= 2>/dev/null | grep -v '?' | head -1 || true)
        if [ -n "$tty_path" ]; then
          pty_num="''${tty_path##pts/}"
          emit_osc_to_pty "$pty_num" "$state/foot.ini"
        fi
      done

      # ---------- niri reload ----------
      # niri's inotify watch misses symlink swaps (niri#2658), so we signal
      # explicitly. Non-fatal outside a niri session.
      niri msg action load-config-file 2>/dev/null || \
        echo "theme: niri reload skipped (non-fatal outside session)" >&2

      # colors.json — already delivered by the atomic copy-into-place above;
      # the in-dir replace is what fires Noctalia's watcher.

      echo "theme: switched to ''${new_family}/''${new_polarity}"
    '';
  };
in
{
  # One stable data path per family; HM owns the symlink, the store owns
  # the content — GC-rooted via the generation, stable across rebuilds.
  xdg.dataFile = lib.mapAttrs' (
    name: couplet: lib.nameValuePair "theme-menu/${name}" { source = entryFor name couplet; }
  ) schemePair.menu;

  home.packages = [ theme ];

  # Seed-if-absent activation — guarantees every consumer path resolves before
  # any app can launch (foot hard-errors exit 230 on a missing include). Runs
  # after writeBoundary so the data files are in place when we link to them.
  #
  # Two branches:
  #   A. Pointer absent, dangling, or stale → seed to boot default + write dconf
  #      (first-login path — dconf write is gated here so a rebuild never resets
  #      a runtime polarity selection, per R3; both axes seeded once from Nix).
  #   B. Pointer valid → only (re)create any missing per-target symlinks (never
  #      change their polarity/family — the user's runtime selection is sacred).
  #
  # Consumer-side wiring:
  #   ~/.config/noctalia/colors.json  ← atomic copy of $stateDir/colors.json
  #                                     (copy, not symlink — see #609 comment)
  #   ~/.config/gtk-3.0/theme-menu.css → $stateDir/gtk3.css (symlink)
  #   ~/.config/gtk-4.0/theme-menu.css → $stateDir/gtk4.css (symlink)
  home.activation.themeMenuSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    data=${lib.escapeShellArg dataDir}
    state=${lib.escapeShellArg stateDir}
    boot_default=${lib.escapeShellArg schemePair.family}
    boot_polarity=${lib.escapeShellArg (import ../../lib/palette-for.nix hostContext.hostName).polarity}

    $DRY_RUN_CMD mkdir -p "$state"

    # Determine if current pointer is valid
    _pointer_valid=0
    if current_target=$(readlink "$state/current" 2>/dev/null); then
      current_name="''${current_target##*/}"
      if [ -d "$data/$current_name" ]; then
        _pointer_valid=1
      fi
    fi

    if [ "$_pointer_valid" -eq 0 ]; then
      # Branch A: seed from boot default
      $DRY_RUN_CMD ln -sfn "$data/$boot_default" "$state/current"
      _polarity="$boot_polarity"
      # Write dconf polarity (only on seed — never on rebuild with valid pointer).
      # Absolute path: HM activation PATH lacks dconf; bare calls failed silently
      # — caught by runtime verification, #609.
      if [ "$_polarity" = "dark" ]; then
        $DRY_RUN_CMD ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" \
          || echo "theme-menu: warning: dconf polarity write failed" >&2
      else
        $DRY_RUN_CMD ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'default'" \
          || echo "theme-menu: warning: dconf polarity write failed" >&2
      fi
    else
      # Branch B: read current polarity from dconf (don't change it).
      # Absolute path: HM activation PATH lacks dconf (#609).
      _dconf_val=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)
      if [ "$_dconf_val" = "'prefer-dark'" ]; then
        _polarity="dark"
      else
        _polarity="light"
      fi
    fi

    # (Re)create per-target symlinks (always — ensures they exist even if
    # partially created or cleaned by a GC; polarity follows _polarity above)
    $DRY_RUN_CMD ln -sf "$state/current/foot-$_polarity.ini" "$state/foot.ini"
    $DRY_RUN_CMD ln -sf "$state/current/niri-$_polarity.kdl" "$state/niri.kdl"
    $DRY_RUN_CMD ln -sf "$state/current/gtk3-$_polarity.css" "$state/gtk3.css"
    $DRY_RUN_CMD ln -sf "$state/current/gtk4-$_polarity.css" "$state/gtk4.css"
    $DRY_RUN_CMD ln -sf "$state/current/colors-$_polarity.json" "$state/colors.json"

    # Seed consumer-side files:

    # ~/.config/noctalia/colors.json — atomic copy-into-place, not a symlink:
    # Noctalia's FileView watchers resolve inodes at watch time, so a
    # state-level symlink swap is invisible to them; in-dir replace (tmp +
    # mv -fT) is the pattern its watcher anticipates (#609).
    # Back up a pre-existing foreign file once (only if .pre-609 doesn't
    # already exist — our own copies must never clobber the original backup).
    $DRY_RUN_CMD mkdir -p "$HOME/.config/noctalia"
    if [ ! -e "$HOME/.config/noctalia/colors.json.pre-609" ] \
        && [ -f "$HOME/.config/noctalia/colors.json" ] \
        && [ ! -L "$HOME/.config/noctalia/colors.json" ]; then
      $DRY_RUN_CMD mv "$HOME/.config/noctalia/colors.json" "$HOME/.config/noctalia/colors.json.pre-609"
    fi
    # mktemp -u: a created-but-unused tmp would be left behind on --dry-run
    # (the guarded cp/mv below don't run); -u is race-safe enough in $HOME.
    _colors_tmp=$(mktemp -u "$HOME/.config/noctalia/.colors.XXXXXX")
    $DRY_RUN_CMD cp "$state/colors.json" "$_colors_tmp"
    $DRY_RUN_CMD mv -fT "$_colors_tmp" "$HOME/.config/noctalia/colors.json"

    # ~/.config/gtk-3.0/theme-menu.css → $stateDir/gtk3.css
    $DRY_RUN_CMD mkdir -p "$HOME/.config/gtk-3.0"
    $DRY_RUN_CMD ln -sf "$state/gtk3.css" "$HOME/.config/gtk-3.0/theme-menu.css"

    # ~/.config/gtk-4.0/theme-menu.css → $stateDir/gtk4.css
    $DRY_RUN_CMD mkdir -p "$HOME/.config/gtk-4.0"
    $DRY_RUN_CMD ln -sf "$state/gtk4.css" "$HOME/.config/gtk-4.0/theme-menu.css"
  '';

}
